---
title: "How and why you should upgrade to the Function Custom Resource Definition (CRD)"
description: "Whether you're just starting as a customer or have been for a while, you may be missing out with the Function CRD."
date: 2023-08-17
categories:
- openfaas-standard
- production
dark_background: true
image: "/images/2023-08-17-crd-migration/background.png"
author_staff_member: alex
hide_header_image: true
---

Whether you're just starting as a customer or have been for a while, you may be missing out with the Function CRD.

## A quick history of OpenFaaS Kubernetes support

Around 2017 Kubernetes adopted a new pattern called the Custom Resource Definition (CRD), this was a graduation of a prior work called Third Party Resources. Prior to either of these efforts, any vendor wanting to integrate with Kubernetes had to work with all the standard APIs and somehow decorate them with metadata to show that they belonged to a certain integration.

With the CRD, came the Operator pattern. You create a Custom Resource (an instance of a CRD) and get to have a descriptive name like "Function" or "Tunnel" (in the case of inlets). You can then build a so-called Operator whose sole purpose is to search out for instances of this Custom Resource, and then to create or update native Kubernetes APIs.

When I saw that Kubernetes was dominating the market, and that Docker Swarm was unfortunately on the way out, I wrote the first version of "faas-netes". faas-netes was the cornerstone of the Kubernetes support, and because everything had been built in such a modular way, it was really the only thing we had to change, that and creating a Helm chart.

The first version of faas-netes had a REST API that would create a Deployment and a Service for every function a user deployed. The list functions HTTP handler would search out Deployment objects with a certain label i.e. `faas_function` and then filter on that. We call this version of of the code "the controller" and it has an imperative API - you tell it what to do, and it has to do it right then and there.

When we built a Function Custom Resource Definition, that meant we had to revisit the code and build an operator that would watch for instance of the Function CRD and then create a Deployment and Service just like the "controller" mode did.

![The Operator mode for faas-netes](https://www.openfaas.com/images/2021-06-kubectl-functions/operator-crd.png)
> Conceptual diagram - the Operator mode for faas-netes with the Function CRD.

Long story short, there are a number of benefits of migrating to the Function CRD:

* If a Deployment can't be created in a REST API call, for whatever reason, the operator will keep on trying to create it until it can, out of band
* The Function CRD can be backed up trivially with `kubectl get function -n openfaas-fn -o yaml > functions.yaml`
* The CRD makes it possible to use Helm to package and version functions, including having a values.yaml file where you can override versions, or have common settings like autoscaling for all functions in the chart
* When you can use a Helm chart, that means you can start using GitOps tools like ArgoCD and Flux - to continually upgrade the container image tag for your functions

Then, the final benefit is that you can take advantage of the `kubectl` CLI to explore functions, in addition to faas-cli, with `kubectl get/edit/describe/delete function`.

## How to enable the Operator

If you're performing a brand new installation, then just set the following in the Helm chart to enable the CRD and the Operator:

```yaml
openfaasPro: true
operator: true
```

That's it. From there onwards, you can deploy functions via the REST API or using kubectl.

For instance:

```yaml
$ faas-cli generate --from-store nodeinfo

---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: nodeinfo
  namespace: openfaas-fn
spec:
  name: nodeinfo
  image: ghcr.io/openfaas/nodeinfo:latest
  labels: {}
  annotations: {}
```

You can save this into a file and apply it with `kubectl apply -f nodeinfo.yaml`.

You can still deploy functions using `faas-cli up` or `faas-cli deploy`, but you'll get the benefits of the Operator that we talked about above on top.

## Migrating from an existing installation

Prior to our latest release, you'd have had to use our migration tool to back up all the deployed functions into the Function CRD format, upgraded the OpenFaaS installation, then deleted the old functions and re-created them using the backup file.

Fortunately with our latest change, a one-time migration is performed automatically if you're running in the Operator mode.

1. It scans all OpenFaaS namespaces for Deployments with the OpenFaaS label
2. It reads them into memory, in the CRD format
3. It create the Custom Resource
4. It deletes the old Deployment and Service

Finally, it writes a ConfigMap into the openfaas namespace to prevent the operation from running again.

So whether you're an existing user coming up from the Community Edition (CE), or have been running OpenFaaS Standard or Enterprise for a while, the only thing you need in your Helm chart is:

```yaml
openfaasPro: true
operator: true
```

Then update the installation just as you always would with `helm upgrade --install`.

## Wrapping up

Where we started off, customers had to delete functions when upgrading to the Operator, and then deploy them again, then we built a backup tool, and now we've gone one step further to improve the developer experience with an automated migration, built-into the faas-netes code. There's nothing for you to do - it just kicks in when you turn on the Operator and does the most obvious thing.

So with this latest improvement, we'd like to see all customers moved onto the Function CRD, for the features and benefits it provides - both for us as maintainers and for you, as users.

* More reliable Deployments with the imperative approach
* Access to kubectl for easy management
* Access to Helm for packaging and templating
* Access to GitOps tools like FluxCD and ArgoCD
* Easy backup and restore to the same cluster, or to enable migrations between clouds or clusters

We'd recommend running the migration on a backup or temporary cluster first, to make sure all your functions convert and come up as expected. This is what dev and staging are for after all, right?

You may also like:

* [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)
* [Learn how to manage your functions with kubectl](https://www.openfaas.com/blog/manage-functions-with-kubectl/)]
* [Backup and migrate functions with OpenFaaS](https://www.openfaas.com/blog/backup-and-migrate-functions/)

* [Bring GitOps to your OpenFaaS functions with ArgoCD](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/)
* [Upgrade to Flux v2 to keep OpenFaaS up to date](https://www.openfaas.com/blog/upgrade-to-fluxv2-openfaas/)
