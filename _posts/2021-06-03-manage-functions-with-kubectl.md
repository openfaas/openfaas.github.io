---
title: "Learn how to manage your functions with kubectl"
description: "Learn an alternative to the OpenFaaS API for managing your serverless functions"
date: 2021-06-03
image: /images/2021-06-kubectl-functions/background.jpg
categories:
 - enterprise
 - rbac
 - functions
 - kubernetes
author_staff_member: alex
dark_background: true

---

Learn an alternative to the OpenFaaS API for managing your serverless functions

## Introduction

In the 5 years that we've been building OpenFaaS, knowing who is using the project and for what has been one of the greatest challenges. This isn't unique to our space, but a problem with Open Source in general.

If you are an end-user, please send your use-case into our [ADOPTERS.md](https://github.com/openfaas/faas/blob/master/ADOPTERS.md) file and consider [becoming a GitHub Sponsor](https://github.com/sponsors/openfaas) so that we can continue our work.

### Two ways to operate

As we understand it, most of you are deploying your functions using our [faas-cli](http://github.com/openfaas/faas-cli) command, but there is an alternative available for Kubernetes users using a [Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). It may not be for everyone, and there are pros and cons that I'll mention below, before showing you how to use this option, should you decide to change.

![Using the CRD to deploy functions with kubectl](/images/2021-06-kubectl-functions/operator-crd.png)
> Pictured: Using the CRD to deploy functions with kubectl

The Custom Resource only contains information on how to deploy the function once it's already been built, where as the stack.yml file contains this along with how to build the function itself.

You can use `kubectl apply` instead of the OpenFaaS CLI and API which has several implications:

Pros:
* You can use `kubectl apply/create/delete/edit` to deploy and manage functions
* You can create a helm chart of functions, and edit values like image tags using a `values.yaml` file
* You can use GitOps tools like Flux and ArgoCD to continuously deploy functions

Cons:
* Still requires a separate OpenFaaS stack.yaml for the build configuration such as the template name and `build_args`
* Harder to use with simple REST calls than the OpenFaaS API
* Requires access to the Kubernetes API server
* Requires an account with correct RBAC permissions to be created and managed
* Requires `kubectl` to be installed

### The Custom Resource Definition (CRD) and Operator mode

This approach requires OpenFaaS to have been installed with its Function Custom Resource Definition (CRD) and the [faas-netes controller](https://github.com/openfaas/faas-netes) will need the `--operator` flag too.

Here is a minimal example of the Function Custom Resource:

```yaml
# nodeinfo.yaml
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: nodeinfo
  namespace: openfaas-fn
spec:
  name: nodeinfo
  image: functions/nodeinfo:latest
```

The equivalent in an OpenFaaS stack.yml file would be:

```yaml
# stack.yml
functions:
  nodeinfo:
    image: functions/nodeinfo:latest
```

See also: [OpenFaaS YAML reference](https://docs.openfaas.com/reference/yaml/)

And for a CLI deployment without any YAML files would be:

```bash
faas-cli deploy nodeinfo \
  --image functions/nodeinfo:latest
```

All fields available within the OpenFaaS stack YAML file are available in the Custom Resource, apart from fields which describe how to build the function such as the template name or the code path.

Here is a more complete example:

```yaml
# complete-example.yaml
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: nodeinfo
  namespace: openfaas-fn
spec:
  name: nodeinfo
  handler: node main.js
  image: functions/nodeinfo:latest
  labels:
    com.openfaas.scale.min: "2"
    com.openfaas.scale.max: "15"
  annotations:
    current-time: Mon 6 Aug 23:42:00 BST 2018
    next-time: Mon 6 Aug 23:42:00 BST 2019
  environment:
    write_debug: "true"
  limits:
    cpu: "200m"
    memory: "256Mi"
  requests:
    cpu: "10m"
    memory: "128Mi"
  constraints:
    - "cloud.google.com/gke-nodepool=default-pool"
  secrets:
    - nodeinfo-secret1
```

### Generating the Function Custom Resource

Remember that earlier I said that Custom Resource only contains information on how to deploy the function once it's already been built? Well that means that you still need your `stack.yml` file for the build information.

So instead of maintaining two files, we added a command to generate the Kubernetes YAML. This way your workflow is to update and maintain just the existing file and generate a Kubernetes manifest whenever you need it, even at deployment time if you like.

Generate a YAML from a store function:

```bash
faas-cli generate \
  --from-store nodeinfo \
  > nodeinfo-store.yaml
```

Gives:

```yaml
# nodeinfo-store.yaml
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
```

Generate YAML from all the functions within a single stack.yml file:

```bash
faas-cli new --lang go fn1
faas-cli new --lang go fn2 --append fn1.yml
mv fn1.yml stack.yml

faas-cli generate \
  > functions.yaml
```

Gives:

```yaml
# functions.yaml
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: fn1
  namespace: openfaas-fn
spec:
  name: fn1
  image: fn1:latest
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: fn2
  namespace: openfaas-fn
spec:
  name: fn2
  image: fn2:latest
```

If you only want one of the functions then you can use the `--filter` flag as follows:

```bash
faas-cli generate --filter fn2
```

The generate command can also generate a spec for Knative serving, so that if you happen to be a Knative user, or have both OpenFaaS and Knative within your organisation, you can deploy functions you've built with `faas-cli`.

See `faas-cli generate --help` for more.

A handy trick for deploying functions quickly is to bypass saving the generate command's output to a file, and applying it directly to your cluster.

```bash
faas-cli generate \
  --from-store figlet \
  | kubectl apply -f -
```

### Exploring functions

Once your functions have been created, you can go ahead and use all the `kubectl` commands you would expect to manage them.

```bash
# List them
kubectl get functions \
  -n openfaas-fn

# Output their data as YAML
kubectl get functions \
  -n openfaas-fn -o yaml

# Edit one and save a change
kubectl edit function/figlet \
  -n openfaas-fn

# Delete a function
kubectl delete function/figlet \
  -n openfaas-fn
```

## Summing up

I hope that you've enjoyed learning about the alternative to the OpenFaaS API and CLI for deploying and managing functions on Kubernetes. For some of you this may be the first time you've heard of it and for others, you may still be wondering if you should be moving over to it.

### Upgrade path

If you are finding that the OpenFaaS CLI, REST API and everything else is suiting your needs, then there's no reason to change at this time. If you are a Kubernetes advocate and want to use tools like Argo or Flux, then you should consider deploying the operator and getting familiar with it.

If you do go ahead and upgrade, just bear in mind that you will need to delete any functions that you have deployed in the cluster beforehand. The operator can only manage functions that it has created, so bear this in mind.

We can offer [help and support](https://openfaas.com/support) if you would like to migrate or start taking advantage of GitOps to manage your functions.

### You may also like

You may also like our recent post on deploying functions [Argo CD](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/) or [Flux v1](https://www.openfaas.com/blog/openfaas-flux/). Stay tuned for a post on Flux v2 which we have in the works, keep in touch by [following us on Twitter](https://twitter.com/openfaas).

Of course deploying functions is only part of the story, you'll also need to build them, so checkout my examples in my latest eBook on OpenFaaS: [Serverless For Everyone Else](https://gumroad.com/l/serverless-for-everyone-else). You'll find an example with GitHub Actions that works on regular cloud, ARM servers and Raspberry Pi

Do you have questions, comments or suggestions?

* Browse the [OpenFaaS documentation](https://docs.openfaas.com)
* Follow [OpenFaaS on Twitter](https://twitter.com/openfaas)
* Join [OpenFaaS Slack](https://slack.openfaas.io/)
