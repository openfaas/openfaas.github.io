---
title: A new status for the OpenFaaS Function Custom Resource Definition (CRD)
description: 
date: 2024-04-30
categories:
- kubernetes
- faas
- functions
dark_background: true
image: "/images/images/2024-04-crd-status/background.png"
author_staff_member: alex
hide_header_image: true
---

One of the goals of OpenFaaS is to make the developer experience simple for FaaS-style workloads simple and portable with Kubernetes.

Most of the time that has meant making Kubernetes something you don't need to think about (at least as much). But in this post, we are going to talk about how we've made it easier to integrate functions to Kubernetes tooling.

First we'll take a quick look at why we might want a Function CRD, even if it means "more Kubernetes", what's changed, how it looks, and where to go next to try it out.

## What's the Function CRD good for?

The experience most users will have with OpenFaaS with be using its UI or CLI tool (`faas-cli`), and not working directly with Kubernetes resources. So why are we talking about Custom Resource Definitions (CRDs) in this post?

The Function Custom Resource Definition (CRD) was added to OpenFaaS in 2017 and made it easier for Kubernetes administrators to view functions as native resources, just like Pods, Services, or Ingresses. And that meant that Functions could be managed with kubectl, Helm, and GitOps style tooling like [FluxCD](https://fluxcd.io) and [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) from the [CNCF](https://cncf.io).

Why would you want to use Helm if there's a native CLI for OpenFaaS?

Helm is a very popular choice for bundling and versioning applications on Kubernetes, so it makes sense that teams who use Helm heavily, may also want to deploy their functions in the same way.

What about GitOps?

Using the faas-cli, you can deploy from a GitHub Action, or GitLab job, and even use IAM for OpenFaaS to create fine-grained permissions for your team. However, some teams who have already adopted a GitOps style to deploy their applications also want to deploy their functions in the same way.

## What's new about it?

The Function CRD is not new, and is widely used already, it's even used when deploying functions via `faas-cli` or the REST API behind the scenes.

Here's how you can deploy a function from a pre-built image from the OpenFaaS store. In this case, the function executes the "env" built-in bash command which is useful for inspecting HTTP headers and environment variables.

```bash
cat << EOF | kubectl apply -f -
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: env
  namespace: openfaas-fn
spec:
  name: env
  image: ghcr.io/openfaas/alpine:latest
  environment:
    fprocess: "env"
EOF
```

Today we're releasing support for a status field, with a readiness or health status that can be understood by both ArgoCD and FluxCD.

In the past, we deferred this work because there was no standard or support in kubectl or Helm to detect when a Custom Resource was "ready", and that's still the case today. However, after had the request come from customers for a health status for use with ArgoCD, we decided to implement once, and support FluxCD at the same time.

### How does it look?

There are two parts to this change:

The first part is the column printer for `kubectl get function`:

```bash
$ kubectl get function --watch --output wide --namespace openfaas-fn

NAME   IMAGE                            READY   HEALTHY   REPLICAS   AVAILABLE
env    ghcr.io/openfaas/alpine:latest                                
env    ghcr.io/openfaas/alpine:latest                                
env    ghcr.io/openfaas/alpine:latest   True    False                
env    ghcr.io/openfaas/alpine:latest   True    False     1          
env    ghcr.io/openfaas/alpine:latest   True    False     1          
env    ghcr.io/openfaas/alpine:latest   True    True      1          1
```

When a function is scaled to zero, with zero replicas requested, the Healthy column will print False, but the Ready column will print True. When scaling up or down, and there is at least one remaining replica, the Ready column will continue to print True.

The second part is the conditions within the status field of the Function CRD.

If you run `kubectl get function/env -n openfaas-fn -o json`, you'll see a new `.status` field, which contains three new fields

* `conditions` - a Kubernetes convention for showing various conditions about a resource
* `replicas` - the desired amount of replicas for the function
* `availableReplicas` - the number of replicas that are ready to serve a request

Within the conditions, we've added four types:

* `Reconciling` - this condition is added when the operator detects the resource for the first time, or when it detects a change
* `Stalled` - this condition is set along with a reason when the operator cannot progress, perhaps there is a clashing preexisting resource, missing RBAC permissions, or a missing secret
* `Read` - this condition means that the operator has performed its tasks and created the objects it needs to
* `Healthy` - this condition means that the resources created for the function are ready to serve requests, in this case, there is at least one available replica

### Getting started

There's a lot more to say about the Function CRD, like how to generate it from the existing OpenFaaS stack.yml file, how to inject variables via environment substitution, and how to use it with Helm.

Head over to the [OpenFaaS docs for the Function CRD](https://docs.openfaas.com/openfaas-pro/function-crd/) for more detailed information and examples of how to get started with ArgoCD.

If you're not using the Function CRD yet, then you can find out more about how and why to use it in: [How and why you should upgrade to the Function Custom Resource Definition (CRD)](https://www.openfaas.com/blog/upgrade-to-the-function-crd/).

You may also like: [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)

