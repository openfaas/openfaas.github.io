---
title: Introducing the OpenFaaS Operator for Serverless on Kubernetes
date: 2018-07-14
image: /images/kubernetes-operator-crd/pexels-asphalt-blue-sky-clouds-490411.jpg
categories:
  - kubernetes
author_staff_member: alex
canonical_url: https://blog.alexellis.io/introducing-the-openfaas-operator/
---

This blog post introduces OpenFaaS Operator which is a CRD and Controller for OpenFaaS on Kubernetes. We started working on this in the community in October last year to enable a tighter integration with Kubernetes. The most visible way you'll see this is by being able to type in `kubectl get functions`.

## Brief history of Kubernetes support

OpenFaaS has worked natively with Kubernetes for well over a year. Each function you build creates a Docker image which when deployed through the OpenFaaS API creates a `Deployment` and `Service` API object and that in turn creates a number of `Pods`.

The original controller called `faas-netes` was created by the community and much of its code has been re-purposed in the new Operator created by [Stefan Prodan from Weaveworks](http://github.com/stefanprodan/). Since the Operator was created in October there have already been several pull requests, fixes and releases.

Here is a conceptual diagram from the [documentation site](https://docs.openfaas.com/architecture/gateway/). The Operator does not change this architecture, but changes the way it is created through listening to events.

![](https://raw.githubusercontent.com/openfaas/faas/master/docs/of-overview.png)

The use of Kubernetes primitives from the beginning has meant users can use `kubectl` to check logs, debug and monitor OpenFaaS functions in the same way they would any other Kubernetes resources. OpenFaaS runs on all Kubernetes services such as GKE, AKS, EKS, with OpenShift or with `kubeadm`.

Example: Using [Weave Cloud](https://www.weave.works/product/cloud/) to monitor network traffic, CPU and memory usage of OpenFaaS function Pods on GKE

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">I&#39;m comparing Weave Cloud&#39;s integrated functions dashboard (CPU, memory, network, RED) for OpenFaaS with Grafana (light theme) and the community dashboard - Find out more about auto-scaling here 📈✅😀n- <a href="https://t.co/rddgNWGPkh">https://t.co/rddgNWGPkh</a> <a href="https://twitter.com/weaveworks?ref_src=twsrc%5Etfw">@weaveworks</a> <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> <a href="https://t.co/j49k9slDC2">pic.twitter.com/j49k9slDC2</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/991314189036720129?ref_src=twsrc%5Etfw">May 1, 2018</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

## The OpenFaaS Operator

This section covers the technical and conceptual details of the OpenFaaS Operator.

### What is a CRD?

One of the newer extension points in Kubernetes is the [Custom Resource Definition (CRD)](https://kubernetes.io/docs/tasks/access-kubernetes-api/custom-resources/custom-resource-definitions/) which allows developers to create their own native abstractions and extensions within the Kubernetes API. Why is that important? On its own the CRD is useful for storing objects and state which plays nicely with other Kubernetes objects, but it comes into its own with controllers.

A controller (sometimes called an operator) exists to create objects which the CRDs represent. It can run in a loop or react to events as they happen to reconcile a desired state with the actual state of the system.

```
$ kubectl get crd
NAME                        AGE
functions.openfaas.com      41d
sealedsecrets.bitnami.com   41d
```

In this example I can see the new functions definition created with the Operator's helm-chart and the [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets) definition from Bitnami.

```
$ kubectl get -n openfaas-fn functions
NAME       AGE
figlet     55m
nodeinfo   55m
```

*Example showing the functions deployed*

![OpenFaaS UI with CRDs](https://blog.alexellis.io/content/images/2018/07/of-k8s-crd.png)

At this point I could type in `kubectl delete -n openfaas-fn functions/figlet` and in a few moments we would see the `figlet` function, Pod and Service disappear from the OpenFaaS UI.

### YAML definition

This is what a Kubernetes CRD entry for `functions.openfaas.com` (version `v1alpha2`) looks like:

```
apiVersion: openfaas.com/v1alpha2
kind: Function
metadata:
  name: nodeinfo
  namespace: openfaas-fn
spec:
  name: nodeinfo
  image: functions/nodeinfo:latest
  labels:
    com.openfaas.scale.min: "2"
    com.openfaas.scale.max: "15"
  environment:
    write_debug: "true"
  limits:
    cpu: "200m"
    memory: "1Gi"
  requests:
    cpu: "10m"
    memory: "128Mi"
```

You may have noticed a few differences between the YAML used by the `faas-cli` and the YAML used by Kubernetes. You can still use your existing YAML with the `faas-cli`, the CRD format is only needed if you will use `kubectl` to create your functions.

> Functions created by the `faas-cli` or OpenFaaS Cloud can still be managed through `kubectl`.

### Q&A

* Does this replace `faas-netes`? Will you continue to support `faas-netes`?

The `faas-netes` project has the most active use and we will continue to support it within the community. All fixes and enhancements are being applied to both through Pull Requests.

* Who should use the new Operator?

Please try the new Operator in your development environment. The community would like your feedback on GitHub, Slack or Twitter.

Use the Operator if using CRDs is an important use-case for your project.

* Should I use the CRD YAML or the `faas-cli` YAML definition?

Please continue to use the `faas-cli` YAML unless you have a use-case which needs to create functions via `kubectl`.

* Anything else I need to know?

The way you get the logs for the operator and gateway has changed slightly. See the [troubleshooting guide](https://docs.openfaas.com/deployment/troubleshooting/#get-logs-using-openfaas-operator) in the docs.

> Note from Stefan: If you migrate to the Operator you should first delete all your functions, then deploy them again after the update.

## So what next?

If we can now use `kubectl` to create functions then what does that mean for the OpenFaaS UI, CLI and the GitOps workflow with OpenFaaS Cloud?

> At KubeCon in Austin Kelsey Hightower urged us not to go near `kubectl` as developers. His point was that we should not be operating our clusters manually with access to potentially dangerous tooling.

{% include youtube.html id="kOa_llowQ1c" %}

Access to `kubectl` and the `function` CRD gives more power to those who need it and opens new extension points for future work and ideas. All the existing tooling is compatible, but it really becomes powerful when coupled with a "git push" GitOps CI/CD pipeline like [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud).

### Try it out!

* Please try out the OpenFaaS Operator and let us know what you think

The helm chart has been re-published so follow the brief README here to get installed and upgraded today: https://github.com/openfaas/faas-netes/tree/master/chart/openfaas

## Join the community

Within the OpenFaaS Slack community there are several key channels that are great for working with Kubernetes such as `#kubernetes`.

Here are some of the channels you could join after [signing-up](https://docs.openfaas.com/community/):

In OpenFaaS any programming language or binary is supported, but templates make them easy to consume via `faas cli new`, so join `#templates` and help us build the next set of templates for JVM-based languages.

`#arm-and-pi`

Building a cool Raspberry Pi Cluster or just struggling? Join this channel for help from the community and to share ideas and photos of your inventions.

Join `#contributors` to start giving back to Open Source and to become a part of the project. [Get started here](https://docs.openfaas.com/contributing/get-started/)
