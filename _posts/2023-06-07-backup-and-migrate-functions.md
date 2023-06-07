---
title: "Backup and migrate functions with OpenFaaS"
description: "Backup and migrate functions between clusters with a new export command for the OpenFaaS CLI."
date: 2023-06-07
categories:
- sre
- devops
- productivity
- backup
author_staff_member: alex
---

Backup and migrate functions between clusters with a new `export` command for the OpenFaaS CLI.

## Introduction

In an ideal world, we would all have Infrastructure as Code (IaC) or GitOps-style tooling. Tooling which means that at a click of a button, we could redeploy the entire state of a Kubernetes cluster. But we don't live in an ideal world, and sometimes these things are part of a journey that takes time and resources to implement.

The Community Edition of OpenFaaS is free and available under an open-source license, and comes with a REST API. The REST API can be used to deploy and manage functions, and is used whenever you run the `faas-cli` command. If you want to back up your functions, you'll need to write some code to query the REST API and then save the functions to a file, to be restored by other code later on.

OpenFaaS Standard and OpenFaaS for Enterprises (sometimes known as "Pro") also includes a Kubernetes Custom Resource Definition (CRD) which makes it trivial to back up and restore functions. Whenever the `faas-cli` or REST API is accessed, a Custom Resource is created or updated in Kubernetes. This means that you can use `kubectl` to back up and restore functions.

Here's an example of how that works:

```bash
faas-cli store deploy nodeinfo

Deployed. 202 Accepted.
URL: http://127.0.0.1:8080/function/nodeinfo
```

```bash
kubectl get function -n openfaas-fn
NAME                  AGE
nodeinfo              3s
```

Now you can simply get, edit or delete the Function just like any other Kubernetes resource.

Here's how to export the CR for the function:

```bash
kubectl get function -n openfaas-fn -o yaml
```

```yaml
apiVersion: openfaas.com/v1
kind: Function
metadata:
  creationTimestamp: "2023-06-07T11:40:48Z"
  generation: 1
  name: nodeinfo
  namespace: openfaas-fn
  resourceVersion: "70611366"
  uid: 39f05318-52bb-445b-abd0-c78b4eedf8df
spec:
  annotations: {}
  image: ghcr.io/openfaas/nodeinfo:latest
  labels: {}
  name: nodeinfo
  readOnlyRootFilesystem: false
```

If you're making a backup, I'd suggest removing the `creationTimestamp`, `generation`, `resourceVersion` and `uid` fields as these are specific to the cluster and object.

So the Function CRD is great, but who is this new `export` command for?

* All of your functions are created via the REST API using the Function Builder - as part of a larger platform - I'm thinking of customers like Patchworks, Waylay, and Kubiya.

    You want to be able to back up the state of the cluster just in case something goes wrong. You'll be able to get all of the customer functions back without asking them to input them into your own product again, or without having to ask them to trigger a build.

* You want to migrate an OpenFaaS CE cluster to a Pro cluster

    A number of our customers have done pre-existing work or PoCs with CE and want to keep their work

* You may already be using Pro, but only have REST API access, not kubectl access

    This may be the case if you're part of a larger team and work on a locked-down cluster, or the cluster is using OpenFaaS IAM

* You like backing up the Function CRD with the command I shared above, but you don't like having to delete all the unnecessary fields

    In this case, your functions are probably not created via GitOps tooling such as ArgoCD or Flux, you know you can back up the CRs with `kubectl`, but there's too much noise in the output. The export command provides clean output.

Now in addition to all of the above, if you have an additional need - you can let us know and we may be able to tweak the tool to suit your needs. You can't do that so easily with `kubectl get function -o yaml`.

## Introducing `faas-cli pro export`

We created a new command for `faas-cli` earlier this year for Klar.mx, who wanted to be able to use build secrets securely for AWS Code Artifact and Npm.js without leaking them into a Dockerfile via a build-arg or ENV variable. You can read up more about that here: [Introducing our new Python template for production](https://www.openfaas.com/blog/openfaas-pro-python-template/)

Since OpenFaaS Pro customers can already export functions using `kubectl get function -o yaml`, we decided this command was best suited to the Community Edition of OpenFaaS who were looking to migrate or upgrade their clusters.

The `pro` command is a separate CLI which needs to be downloaded and activated:

Download the latest version of the plugin, or update it:

```bash
faas-cli plugin get pro
```

Then activate it with the following:

```bash
faas-cli pro enable
```

From there, you can run `faas-cli pro --help` to see what kinds of extra commands and parameters are available to you.

```
Available Commands:
  auth        Obtain a token for your OpenFaaS gateway
  build       Builds OpenFaaS function containers
  completion  Generate the autocompletion script for the specified shell
  enable      Enable OpenFaaS Pro
  export      Export functions from the OpenFaaS REST API as CRs for the Operator
  help        Help about any command
  publish     Builds and pushes multi-arch OpenFaaS container images
  push        Push OpenFaaS functions to remote registry (Docker Hub)
  validate    Validate OpenFaaS Pro
  version     Display the plugin version information
```

For instance, the commands for Single Sign-On and OpenFaaS IAM are available under `faas-cli pro auth`, and the new command we want is `faas-cli pro export`.

Run the command to see what parameters are available:

```bash
faas-cli pro export --help

Export functions from the OpenFaaS REST API as CRs for the Operator
to convert from OpenFaaS CE to a commercial license.

Usage:
  pro export --gateway http://user:password@domain:port [flags]

Examples:
  faas-cli export --gateway http://user:password@domain:port


Flags:
  -g, --gateway string     Gateway URL starting with http(s):// (default "http://127.0.0.1:8080")
  -h, --help               help for export
  -n, --namespace string   Namespace for OpenFaaS CE functions (default "openfaas-fn")

Global Flags:
      --filter string       Wildcard to match with function names in YAML file
      --regex string        Regex to match with function names in YAML file
      --token-file string   A file with your GitHub token (default "$HOME/.openfaas/token.yml")
  -f, --yaml string         Path to YAML file describing function(s)
```

As you can see, the main parameter is the gateway URL of the source cluster. The output of the command will be instances of the Function Custom Resource, separated out and printed to the console.

```bash
PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode; echo)

faas-cli pro export --gateway http://admin:$PASSWORD@127.0.0.1:8080
```

Here's the output:

```yaml
# OpenFaaS Pro plugin cluster export:

# - kubernetes/openfaas-operator
# - version: 0.2.1
# - commit: 8ed351fad59799a8c8531af661a2aaacf465d1ed
---
# Function: nodeinfo.openfaas-fn
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  creationTimestamp: null
  name: nodeinfo
  namespace: openfaas-fn
spec:
  image: ghcr.io/openfaas/nodeinfo:latest
  name: nodeinfo
  readOnlyRootFilesystem: false

---
# Exported: 1 function
```

If you want to pipe this to a file for safe-keeping, or later use, then add `> functions.yaml` to the end of the command:

```bash
faas-cli pro export \
    --gateway http://admin:$PASSWORD@localhost:8080 > functions.yaml
```

## Importing the functions

Make sure that you've run `kubectl config get-context` to ensure that you're pointing to the right cluster. I prefer to use the `kubectx` tool for this, which is also available via `arkade get kubectx`

Then simply apply the resulting YAML file:

```bash
kubectl apply -f functions.yaml
```

The source destination for OpenFaaS CE will always be `openfaas-fn`, so the destination is also set to `openfaas-fn`, but if you want to change it, you can just edit your YAML file before applying it.

## Wrapping it up

Just like when we created the `faas-cli pro build` command for a customer who wanted to use build secrets, we've now created a new command for customers who want to migrate between clusters.

Did you know that after upgrading to OpenFaaS Pro, you can use GitOps tools like ArgoCD and Flux? Rather than carrying out manual backups, these tools encourage your team to only ever deploy functions by publishing instances of the Function Custom Resource to a Git repository.

Find out what's included in [OpenFaaS Standard and OpenFaaS for Enterprises here](https://www.openfaas.com/pricing/)

* [How to package OpenFaaS functions with Helm](http://localhost:4000/blog/howto-package-functions-with-helm/)
* [How to update your OpenFaaS functions automatically with the Argo CD Image Updater](http://localhost:4000/blog/argocd-image-updater-for-functions/)

Let us know what comments, questions or suggestions you have via email, our [weekly community call](https://docs.openfaas.com/community/) or the [Customer Community](https://github.com/openfaas/customers).
