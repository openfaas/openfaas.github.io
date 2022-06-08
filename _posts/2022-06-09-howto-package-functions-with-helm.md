---
title: "How to package OpenFaaS functions with Helm"
description: "Learn how to package and deploy your OpenFaaS functions with Helm."
date: 2022-06-09
image: /images/2022-06-howto-package-functions-with-helm/background.png
categories:
- helm
- functions
- kubernetes
- enterprise
- gitops
author_staff_member: han
---

Learn how to package and deploy your OpenFaaS functions with Helm.

## Introduction
We got some questions from our users who asked us how they can provide configuration options when they deploy functions. This can be useful if you want to update the image tag for a new version of a function. Or, if you want to set common configuration values like limits or environment variables across functions without having to maintain multiple versions of your function stack files.

In this post we'll explore how to package functions with Helm, and a simpler alternative too.

## The OpenFaaS Operator
The easiest way to deploy functions right now is by using the `faas-cli` commands. The CLI uses the OpenFaaS REST API to deploy functions. In modern production environments you might want to use a GitOps approach to deploy build artefacts from your Continuous Integration pipeline to your cluster.

At this time, two of the most popular open-source projects for GitOps are [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) and [Flux](https://fluxcd.io/). Both of these projects are designed to apply Kubernetes YAML files and can not directly interact with the OpenFaaS REST API.

As an alternative to deploying functions through the REST API, OpenFaaS can be configured to support deployments using a Kubernetes [Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/).

![Using the CRD to deploy functions](/images/2021-06-kubectl-functions/operator-crd.png)
> Using the CRD to deploy functions

## Deploy functions using the Function CRD
We will look into two different approaches to deploy functions when using OpenFaaS with the Function Custom Resource Definition and Operator mode.

The first method will use the `faas-cli` to convert the OpenFaaS stack.yaml file into a Kubernetes CRD YAML file. The resulting files can be deployed using `kubectl` or committed to a repo where GitOps tools like [ArgoCD](https://argo-cd.readthedocs.io/en/stable/) or [Flux](https://fluxcd.io/) could use them to deploy the functions.

In the second approach the functions are packaged as a Helm Chart. Helm can then be used to deploy the functions and provide configuration values to the deployment. Both are valid options and they come with their own benefits and drawbacks.

CRD files:
- CRDs can be generated from a stack.yaml file using `faas-cli generate`
- Basic templating support using [YAML environment variable substitution](https://docs.openfaas.com/reference/yaml/#yaml-environment-variable-substitution)

Helm Chart:
- Once templates are generated you can not just run `faas-cli generate` again to reflect changes in your stack.yaml file.
- Because Helm uses the [Go template language](https://pkg.go.dev/text/template) it supports advanced templating (logic, functions).
- Values are centralised in the values.yaml file.
- Charts can be versioned and Helm provides mechanisms to easily upgrade, rollback and uninstall said Charts.
- Helm provides you the option to group various Kubernetes components together with your functions into a single deployable unit.

Using Helm to package functions does not mean you wont need the YAML environment variable substitution anymore. While the Helm templates contain the deployment information, the stack.yaml file still contains the build configuration for functions. Environment variable substitution can be used to provide different configurations for building functions locally vs building and pushing functions in a CI environment.

Most fields that are available to configure function deployments in the stack.yaml file can be used in a Function CRD. Any configuration about building the function is left out, such as the template name and build args.
```yaml
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

## Generate CRD files
Create a new function using the `faas-cli`
```bash
faas-cli new --lang node14 marketing-list
```

We can convert the OpenFaaS stack.yaml file into a function CRD by running `faas-cli generate`.

```bash
faas-cli generate \
  -f marketing-list.yml > marketing-list-func.yaml
```
This gives you:
```yaml
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: marketing-list
  namespace: openfaas-fn
spec:
  name: marketing-list
  image: marketing-list:latest

```
Using `kubectl apply` we can now deploy our function.

For more examples that show you how to generate a CRD from your stack.yaml file and how to deploy them with `kubectl` take a look at the article that Alex wrote on [How you to manage your function with kubectl](https://www.openfaas.com/blog/manage-functions-with-kubectl/).

### Inject configuration options during deployment
What if we just want to update the version tag of a function or set common configuration values like limits or environment variables across functions? Instead of manually editing each value in the stack.yaml file we can make use of environment variable substitution. The YAML stack format supports the use of `envsubst`-style templates. These can be used to set individual values through environment variables.

> The reference documentation for the [OpenFaaS yaml file](https://docs.openfaas.com/reference/yaml/) contains info on all the configuration options, including the [YAML environment variable substitution](https://docs.openfaas.com/reference/yaml/#yaml-environment-variable-substitution).

We will edit the stack file for the marketing-list function so that the image tag can be configured by setting the `VERSION` environment variable. Optionally you can do the same for the container registry and repository.
```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  marketing-list:
    lang: node14
    handler: ./marketing-list
    image: ${REGISTRY:-docker.io}/${OWNER:-functions}/marketing-list:${VERSION:-dev}
```
We provide a default value for each variable. For the image tag the default version is `dev`.

To build and push the function we run `faas-cli publish`
```bash
VERSION=0.1.0 faas-cli publish -f  marketing-list.yml
```
This will build and push an image with the name: `docker.io/functions/marketing-list:0.1.0`

The environment variables are also respected when running `faas-cli generate`. Each time a function is updated the CRD can be regenerated. The updated version tag or any other variables you specified in your stack.yaml file will be injected in the new CRD. You can re-apply the new CRD with `kubectl` or commit the changes to a git repository where they are picked up and deployed by your GitOps pipeline.
```bash
export VERSION=0.1.0
faas-cli generate \
  -f marketing-list.yml > marketing-list-func.yaml
```

The resulting `marketing-list-func.yaml`:
```yaml
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: marketing-list
  namespace: openfaas-fn
spec:
  name: marketing-list
  image: docker.io/functions/marketing-list:0.1.0
```

## Walk-through with Helm and the Function CRD

### Create a Helm Chart
We can create a Helm Chart using `helm create`.
```
mkdir chart
cd chart
helm create functions
```

Running `helm create` will create a Chart directory along with common files and directories used in a Chart.
```
.
└── functions
    ├── charts
    ├── Chart.yaml
    ├── templates
    │   ├── deployment.yaml
    │   ├── _helpers.tpl
    │   ├── hpa.yaml
    │   ├── ingress.yaml
    │   ├── NOTES.txt
    │   ├── serviceaccount.yaml
    │   ├── service.yaml
    │   └── tests
    │       └── test-connection.yaml
    └── values.yaml
```

Not all files generated by `helm create` are required to create a deployable Chart. At a minimum Helm expects the following files:
- Chart.yaml: This file contains metadata about the chart (e.g. version, author, etc)
- values.yaml: The `values.yaml` file contains default values for the templated parts of the Chart. These values can be set while deploying the Chart using the `--values` or `--set` flags.
- template files: The templates folder contains all the Kubernetes manifest templates that define your application. This is where we will place our function CRDs.

The optional `NOTES.txt` file is a plain text file that can be used to define a message or some usage notes. This message will be printed to the console when the chart is deployed. The templates folder will also contain some examples of different Kubernetes manifest files. They can be safely removed since we will replace them with our own function templates.

### Template functions
We will use the `faas-cli generate` command to create the function custom resource for the functions defined in the `stack.yaml` file. The output of the generate command will be written to a file in the templates directory.
```bash
faas-cli generate -f marketing-list-func.yaml > chart/functions/templates/marketing-list-func.yaml
```

Once the function CRDs are generated you can start editing them.
We will modify the `marketing-list-func.yaml` template to make the image configurable.

{% raw %}
```yaml
---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: marketing-list
  namespace: openfaas-fn
spec:
  name: marketing-list
  image: {{ .Values.marketingList.image }}
```
{% endraw %}

Edit the `values.yaml` file to set the default value for the image:
```yaml
marketingList:
  image: docker.io/functions/marketing-list:0.1.0
``` 

### Install the chart
We can deploy our functions by running `helm install`. Make sure your function images are available before deploying them. The Helm Chart contains the deployment configuration for the functions but no build instructions. Building functions still has to be done using the faas-cli or another build method.

```bash
helm install functions chart/functions
```

When the installation is successful, helm will print out some information about the deployment along with the messages from the `NOTES.txt` file if it was included in the Chart.
```
NAME: functions
LAST DEPLOYED: Wed May 18 10:55:53 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

### Deploy a new version of a function
After making some changes to the marketing-list function we want to rebuild and push the updated function image.
You can manually edit the `stack.yaml` file and update the tag or use environment variable substitution like we demonstrated in the first section.
```bash
VERSION=0.1.1 faas-cli publish -f marketing-list.yml
```

We can now upgrade the deployment to use the new image. The new value for the image can be set in the `values.yaml` file or we can pass it using the `--set` flag.
```bash
helm upgrade functions  chart/functions \
  --set marketingList.image=docker.io/functions/marketing-list:0.1.1
```

```
Release "functions" has been upgraded. Happy Helming!
NAME: functions
LAST DEPLOYED: Wed May 18 11:17:28 2022
NAMESPACE: default
STATUS: deployed
REVISION: 2
TEST SUITE: None
```

We can verify that our function is now using the updated image by running `kubectl describe`
```bash
kubectl describe function/marketing-list -n openfaas-fn | grep "Image"
Image:  docker.io/functions/marketing-list:0.1.1
```

## Wrapping up
We discussed two different methods to deploy functions when using OpenFaaS with the operator. In the first method we used the `faas-cli` command to turn the stack.yaml file into function CRDs. In the second method we took it one step further and we used the generated files to create a Helm Chart for functions.

With `faas-cli generate`, we can use environment variable substitution to set dynamic values like the version of the image or the commit SHA.

With Helm, we set similar values through the values.yaml file.

Both approaches will work with a GitOps tool like ArgoCD, but have their own pros and cons.

Now that you now how to package your functions with Helm you can go ahead and setup a GitOps pipeline to deploy your functions:
- [Bring GitOps to your OpenFaaS functions with ArgoCD](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/)
- [Applying GitOps to OpenFaaS with Flux Helm Operator](https://www.openfaas.com/blog/openfaas-flux/) 

