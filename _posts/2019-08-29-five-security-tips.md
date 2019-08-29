---
title: "Five security tips for OpenFaaS on Kubernetes"
description: Project founder Alex Ellis will walk you through 5 different security features and configurations for OpenFaaS on Kubernetes
date: 2019-08-29
image: /images/2019-serverless-static-sites/background.jpg
categories:
  - community
  - ingress
  - kubernetes
author_staff_member: alex
dark_background: true
---

Project founder Alex Ellis will walk you through 5 different security features and configurations for OpenFaaS on Kubernetes

I started [OpenFaaS](https://github.com/openfaas/faas) in late 2016 as a side-project with an aim to bring the Serverless experience to developers anywhere, whatever platform they were using. The corner-stone for this initial work was the container image and Docker to help orchestrate and build fault-tolerant, highly-available and secure clusters. Fast forward to 2019 and the community now has over 240 contributors and we've built a solid story for Serverless on Kubernetes.

I'll walk you through some concepts and features that can make OpenFaaS even more robust.

## 1. Authentication

OpenFaaS comes with authentication turned on by default. You will be issued with, or will create a password for the admin user as part of the deployment process, whether you use Kubernetes or Swarm.

There are three modes of authentication available for the administrative endpoints of the OpenFaaS Gateway:

- Basic authentication (using a community plugin)
- OAuth2 with OIDC (using a plugin by OpenFaaS Ltd)
- Write your own plugin

Authentication plugins can be built by anyone. The project has provided two, which cover the needs of the current users. If you have additional needs or requirements, please do get in touch, or write your own.

![OAuth2 with OIDC in OpenFaaS](https://user-images.githubusercontent.com/6358735/57385738-e319ab00-71aa-11e9-8aa2-9cbb9e250cde.png)
*Diagram by OpenFaaS Ltd*

Whatever plugin you decide to use, it's highly recommended, if not essential that you also enable TLS when accepting requests from external, untrusted networks. Some users may even want to use TLS within an air-gapped environment.

> Note: OpenFaaS is designed to be a modular component, that can run anywhere easily. [OpenFaaS Cloud](https://https://docs.openfaas.com/openfaas-cloud/intro/) is a complete platform that ships with both TLS and OAuth2 out of the box.

Compare: [OpenFaaS vs OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/)

See also: [Authentication in OpenFaaS](https://docs.openfaas.com/reference/authentication/)

Forgot your password? [Find it here](https://docs.openfaas.com/deployment/troubleshooting/)

## 2. Transport Layer Security (TLS)

Transport Layer Security or TLS as it's commonly known is a protocol which was introduced to encrypt traffic between services over networks. According to Wikipedia it can help mitigate eavesdropping and man-in-the-middle attacks. Today we're talking about the TLS commonly found on web-servers, mobile apps and in software for instant messaging.

TLS relies on certificates issued by a certificate authority (CA) and if you've tried to create your own TLS certificates, you may be aware with how complicated this can be.

For development and testing a self-signed certificate can be used which is signed by a fictitious certificate authority (CA). When using this kind of certificate developers will need to "trust" that CA on their local computer, or configure an "insecure TLS" or "don't verify TLS" setting in their software. It is not ideal and can be cumbersome.

The second experience of TLS that many of you may be aware of is to obtain a certificate from a CA which is already trusted by your computer. Trusted CAs typically form part of a bundle that is long-lasting and distributed with your computer. On Alpine Linux this is the `ca-certificates` package that can be installed. In the recent past, obtaining such a certificate could be costly, but a project call LetsEncrypt has started to give away free certificates that last for 3 months.

Rather than force developers to set up or configure TLS, we give them the option and heavily encourage it.

![TLS](https://raw.githubusercontent.com/stefanprodan/openfaas-flux/master/docs/screens/openfaas-operator.png)
*Diagram by Stefan Prodan, showing OpenFaaS with TLS provided by cert-manager*

* [Set up TLS for OpenFaaS on Kubernetes](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/)
* [Production readiness guide](https://docs.openfaas.com/architecture/production/)

Once configured for your OpenFaaS Gateway, all traffic is encrypted with TLS between the client and the gateway.

> Note: OpenFaaS is designed to be a modular component, that can run anywhere easily. [OpenFaaS Cloud](https://https://docs.openfaas.com/openfaas-cloud/intro/) is a complete platform that ships with both TLS and OAuth2 out of the box.

Compare: [OpenFaaS vs OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/)

### 2.1 Mutual TLS (mTLS)

Traditionally applications used TLS to encrypt traffic between the client and the edge of their network. This is called TLS edge-termination and means that traffic within the cluster may be vulnerable to eavesdropping from insiders.

Mutual TLS can be enabled through a service mesh tool like Linkerd or Istio to provide encryption end to end, right from the client all the way to the block of code that executes on a particular server and back again. The encryption is achieved by attaching a proxy to every Pod in the Kubernetes network, this means that the existing unencrypted traffic must pass through the proxy to access any other service. The proxy implements the mTLS functionality.

![](https://github.com/stefanprodan/istio-gke/raw/master/docs/screens/openfaas-istio-diagram.png)

*mTLS with Istio by Stefan Prodan*

mTLS is not free and comes at a cost. The project community currently prefers Linkerd for its ease of use and relatively low resource requirements, but both Linkerd and Istio are supported.

See also: [Linkerd2 & OpenFaaS Hands-on Lab](https://github.com/openfaas-incubator/openfaas-linkerd2)
See also: [Istio on GKE with OpenFaaS](https://github.com/stefanprodan/istio-gke/blob/master/docs/openfaas/00-index.md)

### 3. Kubernetes authentication and CRDs vs. OpenFaaS REST API

OpenFaaS can also rely on Kubernetes features such as role-based authentication control and the existing Kubernetes authentication strategy. This means that you can give developers very granular access to the `Function` CRD, just like any other Kubernetes object.

When you swap the OpenFaaS REST API for CRDs and `kubectl`:

Pros:

- Granular access and RBAC
- No additional TLS needed, relies on Kubernetes for this
- No additional auth, handled by Kubernetes

Cons:

- Harder to use / set up

The OpenFaaS CRD is available with the OpenFaaS Operator and is an option during installation from the [helm chart](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md).

Traditionally you would managed functions using the OpenFaaS CLI and REST API, but if we move away from the REST API and use CRDS, then you can use the `faas-cli` and `kubectl` together instead.

See also, the `faas-cli generate` command:

* A minimal `Function` for `openfaas.com/v1alpha2` CRD

```yaml
apiVersion: openfaas.com/v1alpha2
kind: Function
metadata:
  name: nodeinfo
  namespace: openfaas-fn
spec:
  name: nodeinfo
  image: functions/nodeinfo:latest
```

* How to generate a CRD entry from a `stack.yml` file:

```bash
# create a go function for Docker Hub user `alexellis2`
faas-cli new --lang go --prefix alexellis2 crd-example

# build and push an image
faas-cli build -f crd-example.yaml
faas-cli push -f crd-example.yaml

# generate the CRD entry from the "stack.yml" file and apply in the cluster
faas-cli generate -f crd-example.yaml | kubectl apply -f -
```

* Generate a CRD from the Function Store

```bash

# find a function in the store
faas-cli store list
...

# generate to a file
faas-cli generate --from-store="figlet" > figlet-crd.yaml
kubectl apply -f figlet-crd.yaml
```

### 4. Least privilege access for OpenFaaS Core Components

The OpenFaaS Core Components have well-defined RBAC rules and access control. At this time a `Role` exists which is scoped to only operate in namespace containing your functions such as `openfaas-fn`.

Some projects ship with a `ClusterRole` which can give broad, unmetered access to resources in your whole cluster.

Find out how to install and manage OpenFaaS for several different teams or environments for CI/CD:

![](https://www.openfaas.com/images/gke-multi-stage/overview.png)
*Diagram by Stefan Prodan*

See also: [Multi-stage Serverless on Kubernetes with OpenFaaS and GKE](https://www.openfaas.com/blog/gke-multi-stage/)

### 5. Best practices for Pods

OpenFaaS implements a number of best practices for Kubernetes Pods, the Pod is where your function or microservice will execute.

* Privileged mode is not allowed

Any containers deployed with "privileged mode" on Kubernetes, if compromised could do significant damage. This flag is not available in OpenFaaS.

* Non-root users

The OpenFaaS core components run as non-root users to reduce attack surface.

Templates contain a Dockerfile and an entrypoint, which is usually a HTTP server. These allow developers to avoid repeating themselves with hundreds of lines of Kubernetes YAML, instead they get 3-4 lines in a CRD or OpenFaaS `stack.yml` file. The official OpenFaaS templates use a non-root user so that functions are running as normal users. 

See an example: [openfaas-incubator/node10-express-service](https://github.com/openfaas-incubator/node10-express-service/blob/master/template/node10-express-service/Dockerfile)

An additional flag `setNonRootUser` for the OpenFaaS components on Kubernetes can be set to force all workloads to run as a non-root user, which is a useful catch-all if using third-party templates.

See also: [Helm chart options](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md)

* Secure secrets

OpenFaaS Pods can make use of Kubernetes secrets. To create a secret use `faas-cli secret create` or `kubectl`, both work the same.

```
echo SECRET | faas-cli secret create api-key
```

You can then attach the secret to a function by editing its stack.yml file, or by using the `--secret` flag with `faas-cli up`.

See also: [OpenFaaS workshop: Lab 10 - Secrets](https://github.com/openfaas/workshop/blob/master/lab10.md)

* Image pull secrets

Private Docker registries can be used by attaching an image pull secret to the individual function, or to the service account of the namespace.

See also: [Private registries](https://docs.openfaas.com/deployment/kubernetes/)

* Access the Kubernetes API from within a function

By default, functions cannot access the Kubernetes API from a function, this is due to the RBAC rules configured in the helm chart.

It is possible to create a custom RBAC rule and then to attach a new service account to a function, just like you can with any other Kubernetes workload.

For an example, see the import-secrets function from OpenFaaS Cloud: [handler.go](https://github.com/openfaas/openfaas-cloud/blob/master/import-secrets/handler.go) and the [YAML for RBAC](https://github.com/openfaas/openfaas-cloud/blob/master/yaml/core/rbac-import-secrets.yml)

* Read-only functions and microservices

OpenFaaS supports deploying functions and microservices with a read-only file-system.

![](https://www.openfaas.com/images/read-only/conceptual.png)
*Diagram by Alex Ellis, showing a writeable and read-only Node.js function deployment*

A read-only filesystem protects against the following:

* the function or microservice code cannot be overwritten
* the system libraries cannot be compromised

A small writable temporary area is provided at `/tmp/`.

Read more: [Serverless security, read-only images](https://www.openfaas.com/images/read-only/conceptual.png)

## Wrapping up

The OpenFaaS values are: developers-first, operationally-simple and community-centric. For this reason we decided to make OpenFaaS modular and easy to install for developers. At present TLS is not included by default, but authentication is as a catch-all for unprotected servers on the internet.

We have provided guides, free online training workshops, and tutorials to help developers get a basic level of security, and then a production-readiness guide for administrators and SREs to start building a solid production environment.

The core value of being community-centrics means that suggestions, feedback and feature requests are welcomed. The more context about your use-case that you can provide, the better.

Now there are already several dozen OpenFaaS users in our end-user community, but many more who couldn't share their logo, or who can't talk publicly about what software they use.

![](https://pbs.twimg.com/media/EDHxjoFW4AAwIjF?format=jpg&name=small)
*OpenFaaS end-user community*

If you'd like to hear from the end-user community directly, then please join Slack, or watch one of their videos from KubeCon.

* [LivePerson case-study](https://www.youtube.com/watch?v=bt06Z28uzPA&t=10s)
* [Vision Banco case-study](https://www.youtube.com/watch?v=mPjI34qj5vU&t=1404s)
* [BT case-study](https://youtu.be/y77HlN2Fa-w)

### Connect with us

Connect with us to discuss this blog post, or to share what you're building with OpenFaaS.

* Join OpenFaaS [Slack community](https://docs.openfaas.com/community)
* Follow @OpenFaaS on [Twitter](https://twitter.com/openfaas)

### You may also like

* [How to build a Serverless Single Page App](https://www.openfaas.com/blog/serverless-single-page-app/)
* [OpenFaaS Insiders](https://github.com/openfaas/faas/blob/master/BACKERS.md) - become an OpenFaaS Insider to get regular updates on new features, early access, tips and hints directly from the OpenFaaS Founder
* [k3sup ("ketchup")](https://github.com/alexellis/k3sup) - the fastest way to create local, remote, or edge clusters with Kubernetes.
