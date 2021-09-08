---
title: "Gracefully handling Kubernetes API deprecations: The Tale of Two Ingresses."
description: "Learn how OpenFaaS uses the Kubernetes Discovery API to provide backwards compatibility for Ingress on all Kubernetes versions."
date: 2021-09-08
image: /images/2021-09-ingress/annie-spratt-kZO9xqmO_TA-unsplash-1600.jpg
categories:
 - kubernetes
 - controllers
 - operators
author_staff_member: lucas
dark_background: true

---

Anyone that works with Kubernetes knows that it has a large and evolving API. As Kubernetes evolves, APIs are periodically reorganized or upgraded or, as new APIs are added with new features, the [old APIs they replace are deprecated, and [eventually removed](https://kubernetes.io/blog/2021/07/14/upcoming-changes-in-kubernetes-1-22/#kubernetes-api-removals).

Usually this isn't noticable by most users. Most people are using popular stable APIs, but even those grow and need to be pruned every now and then.

In this post I will show you how the the OpenFaaS team is gracefully handling these deprecations and providing backwards compatibility to users.

The first time I remember this happening was in Kubernetes 1.16 with [Deployments in the `extensions/v1beta1`](https://kubernetes.io/blog/2019/07/18/api-deprecations-in-1-16/) API group. Unfortunately, back then, we didn't know the trick we are about to show you and we had to introduce a breaking change and simply drop support for some version of Kubernetes.

This year (in August) Kubernetes 1.22 dropped support for another popular group of APIs that we use heavily, [Ingress in the extensions/v1beta1 and networking.k8s.io/v1beta1 groups](https://kubernetes.io/blog/2021/07/14/upcoming-changes-in-kubernetes-1-22/). However, this time we have a plan to provide backwards compatibility so that users of OpenFaaS projects wont have to think about this.

## Helm charts

The most likely place you will run into Ingress issues is while installing an application, like OpenFaaS. We use Helm charts to distribute the various OpenFaaS projects and we are very lucky because Helm has built the [version and capability information](https://helm.sh/docs/chart_template_guide/builtin_objects/) of the Kubernetes server into the template context. That has allowed use to create a Helm chart that adapts to _your_ cluster, the user doesn't need to worry "is this chart compatible with my cluster", it will "just work".

This means you can create a helper to determine the correct Ingress version to use, like this

{% raw %}
```handlebars
{{- define "openfaas.ingress.apiVersion" -}}
  {{- if and (.Capabilities.APIVersions.Has "networking.k8s.io/v1") (semverCompare ">= 1.19.x" .Capabilities.KubeVersion.Version -}}
      {{- print "networking.k8s.io/v1" -}}
  {{- else if .Capabilities.APIVersions.Has "networking.k8s.io/v1beta1" -}}
    {{- print "networking.k8s.io/v1beta1" -}}
  {{- else -}}
    {{- print "extensions/v1beta1" -}}
  {{- end -}}
{{- end -}}
```
{% endraw %}

Which you can then use like this

{% raw %}
```yaml
apiVersion: {{ include "openfaas.ingress.apiVersion" . }}
```
{% endraw %}

This means that, if your Kubernetes cluster has `networking.k8s.io/v1` and is version 1.19+, it will use `networking.k8s.io/v1`, if not and your cluster supports `networking.k8s.io/v1beta1`, then use that, and finally, fall back to the default `extensions/v1beta1`.

It is as simple as that, almost. There are a few more tweaks specific to Ingress and you can [check those out here](https://github.com/openfaas/faas-netes/pull/817/files). But that little if-block can be applied to any Kubernetes API to make your Helm chart automatically handle any API change. Fun fact, this _includes_ CRDs. So this approach can also be used to check or verify that a required CRD is installed already.

## Controllers

OpenFaaS itself doesn't directly manage any Ingress definitions, _but_ we have written [`ingress-operator`](https://github.com/openfaas/ingress-operator) that help you automatically create Ingresses for your function via the `FunctionIngress` CRD. If you want custom domains and TLS for your OpenFaaS Functions, check out [`ingress-operator`](https://github.com/openfaas/ingress-operator).

As the name suggests `ingress-operator` creates and manages Ingresses. When `networking.k8s.io/v1beta1` and `extensions/v1beta1` were deprecated we have two choices:

1. also drop support for `networking.k8s.io/v1beta1` and `extensions/v1beta1`, which means dropping support for Kubernetes <1.19. We did not like this, there are still plenty of clusters out there running Kubernetes 1.17 and 1.18. Even Google Cloud will continue supporting these [versions through 2022](https://cloud.google.com/kubernetes-engine/docs/release-schedule).
2. Implement a capabilities check like we have in the Helm charts.

Obviously, we went with [option 2](https://github.com/openfaas/ingress-operator/pull/54).

Fortunately, Kubernetes provides a Discovery endpoint to help inspect and understand the cluster. You can see this in action with the two `kubectl` commands:

```sh
$ kubectl api-versions -h
Print the supported API versions on the server, in the form of "group/version"
$ kubectl api-resources -h
Print the supported API resources on the server
```

If it is in `kubectl`, then we can go to GitHub and find exactly [_how_ it is implemented](https://github.com/kubernetes/kubectl/blob/6e3acf365da52074b1be8c99ec644a57e60bfec8/pkg/cmd/apiresources/apiresources.go#L167-L197).


Using `kubectl` for inspiration, we wrote this snippet of Go to help us mimic what we are doing in the Helm charts

```go
type Capabilities map[string]bool
func (c Capabilities) Has(wanted string) bool {
	return c[wanted]
}

func (c Capabilities) String() string {
	keys := make([]string, 0, len(c))
	for k := range c {
		keys = append(keys, k)
	}
	return strings.Join(keys, ", ")
}

// getPreferredAvailableAPIs queries the cluster for the preferred resources information and returns a Capabilities
// instance containing those api groups that support the specified kind.
//
// kind should be the title case singular name of the kind. For example, "Ingress" is the kind for a resource "ingress".
func getPreferredAvailableAPIs(client kubernetes.Interface, kind string) (Capabilities, error) {
	discoveryclient := client.Discovery()
	lists, err := discoveryclient.ServerPreferredResources()
	if err != nil {
		return nil, err
	}

	caps := Capabilities{}
	for _, list := range lists {
		if len(list.APIResources) == 0 {
			continue
		}
		for _, resource := range list.APIResources {
			if len(resource.Verbs) == 0 {
				continue
			}
			if resource.Kind == kind {
				caps[list.GroupVersion] = true
			}
		}
	}

	return caps, nil
}
```

Usage looks like this

```go
capabilities, err := getPreferredAvailableAPIs(kubeClient, "Ingress")
if err != nil {
    klog.Fatalf("Error retrieving Kubernetes cluster capabilities: %s", err.Error())
}

var ctrl controller
// prefer v1, if it is available, this removes any deprecation warnings
if capabilities.Has("networking.k8s.io/v1") {
    ctrl = controllerv1.NewController(
        kubeClient,
        faasClient,
        kubeInformerFactory,
        faasInformerFactory,
    )
} else {
    // use v1beta1 by default
    ctrl = controllerv1beta1.NewController(
        kubeClient,
        faasClient,
        kubeInformerFactory,
        faasInformerFactory,
    )
}
```

Just like the Helm chart, the final result is very simple and can be used to check for _any_ resource kind in the cluster, including CRDs.

### Wrapping up

The change in the Ingress API, and our work to make that backwards compatible for OpenFaaS users goes to show how challenging it can be to maintain Kubernetes integrations. We hope that the technique and approach here could be useful to you today, with your own controllers, or provide a new approach for any future deprecations you need to handle.

### Join the community

OpenFaaS is an open source project, you can support it via GitHub as an individual or corporation:

* Become an individual or corporate [Sponsor on GitHub](https://github.com/sponsors/openfaas)

Chat with the community:

* Browse the [OpenFaaS documentation](https://docs.openfaas.com)
* Follow [OpenFaaS on Twitter](https://twitter.com/openfaas)
* Join [OpenFaaS Slack](https://slack.openfaas.io)
