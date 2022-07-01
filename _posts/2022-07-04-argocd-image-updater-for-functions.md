---
title: "Automatically update OpenFaaS functions with the ArgoCD Image Updater"
description: "We show you how to keep your functions up to date with the Argo CD Image Updater"
date: 2022-07-04
categories:
- gitops
- argocd
- functions
- kubernetes
image: /images/2022-07-argocd-image-updater/background.png
author_staff_member: han
---

We show you how to keep your functions up to date with the Argo CD Image Updater

## Tutorial
In this tutorial we are going to use [Argo CD](https://argoproj.github.io/cd/) to bootstrap a new cluster. We will demonstrate how you can use the [app-of-apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/) to declaratively manage both OpenFaaS and a set of OpenFaaS functions. We will then deploy and configure the [Argo CD Image Updater](https://argocd-image-updater.readthedocs.io/en/stable/) to automatically update the function images to their latest allowed version.

### How it works

![Conceptual diagram of deploying and updating OpenFaaS functions with Argo CD and Argo CD Image Updater](/images/2022-07-argocd-image-updater/argocd-image-updater-diagram.png)
> Conceptual diagram: deploy OpenFaaS functions with Argo CD and keep them up to date with the Argo CD Image Updater.

Argo CD is a declarative, GitOps continuous delivery tool for Kubernetes. It allows you to use Git repositories as the source of truth for defining the desired application state.

Argo CD automates the deployment of the desired application states in the specified target environments. It will continuously monitor the running applications and compare the current live state against the desired state. It reports any deviations and depending on your configuration automatically updates the application to the desired state.

The **app of apps pattern** is commonly used to install multiple applications in a cluster. Its concept is to declaratively specify one Argo CD app that only consists of other apps. In our case we want to create and deploy two Argo CD apps, one for the OpenFaaS Operator and one for our functions. We will need to create an app called applications that consists of both the openfaas-operator and openfaas-functions app.

The Argo CD Image updater is used to automatically update functions when a new version is published. It polls the image registry to check if a new version of an image is found. If a new version is available and the version constraint is met, the Image Updater instructs Argo CD to update the application with the new image.

![app-of-apps](/images/2022-07-argocd-image-updater/app-of-apps.png)
> Pictured: The Argo CD UI showing the `applications` app containing both the `openfaas-operator` and `openfaas-functions` app.

### Prerequisites

[arkade](https://github.com/alexellis/arkade) enables developers to install the latest versions of their favourite tools and Kubernetes apps. We will use it in this tutorial to install Argo CD and get some other required tools.

Get arkade with:
```bash
# Note: you can also run without `sudo` and move the binary yourself
curl -sLS https://get.arkade.dev | sudo sh
```

One of the limitations of the Argo CD Image Updater is that you can only update images for applications whose manifest is rendered using either *Kustomize* or *Helm*. The template also needs to support specifying the image name using a parameter. This means that you will need to create a Helm Chart for your functions and make the image names of your functions configurable. We show you how to do this in one of our previous blog post:

- [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)

### Install ArgoCD
Create a cluster with KinD if you don't have one already.
```bash
kind create cluster
```

There are various ways to [install ArgoCD](https://argo-cd.readthedocs.io/en/stable/getting_started/#1-install-argo-cd). We are going to use `arkade`
```
arkade install argocd
```

Arkade will print out instructions for port forwarding the Argo CD API and logging in using the ArgoCD CLI. If you need to, you can always retrieve these instructions later by running `arkade info argocd`

We will be using the ArgoCD CLI to manage ArgoCD.
```bash
arkade get argocd
```

Start by port-forwarding the ArgoCD API server to make it accessible on our local host:
```bash
kubectl port-forward svc/argocd-server -n argocd 8443:443
```

Next we will retrieve the password and use it to login with the ArgoCD CLI
```bash
# Get the password
PASS=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d)

# Log in:
argocd login --name local 127.0.0.1:8443 --insecure \
  --username admin \
  --password $PASS
```

Verify that you were logged in successfully before moving on to the next steps:
```bash
argocd account list

NAME   ENABLED  CAPABILITIES
admin  true     login

argocd app list

NAME  CLUSTER  NAMESPACE  PROJECT  STATUS  HEALTH  SYNCPOLICY  CONDITIONS  REPO  PATH  TARGET
```

### Create the applications
Argo CD applications, projects and settings can be defined declaratively using Kubernetes manifests. We are going to create a Helm Chart for our applications.

> Checkout the Argo CD documentation for more info on a [declarative application setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)

The layout of our Git repository:
```
chart
├── applications
│   ├── Chart.yaml
│   ├── templates
│   │   ├── namespaces.yaml
│   │   ├── openfaas-functions-app.yaml
│   │   └── openfaas-operator-app.yaml
│   └── values.yaml
└── functions
    ├── Chart.yaml
    ├── templates
    │   ├── email-notify-func.yaml
    │   └── marketing-list-func.yaml
    └── values.yaml
```

The applications Chart has templates for two Argo CD applications. The openfaas-operator-app for the deployment of OpenFaaS and the openfaas-functions-app for the deployment of our functions.

The functions Chart is also pictured here, it is used by the openfaas-functions app. As mentioned in the prerequisites, you can checkout our [tutorial on how to package functions with helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/) to create this Chart.

The template for the openfaas-operator application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openfaas-operator
  namespace: argocd
spec:
  destination:
    namespace: openfaas
    server: {{ .Values.spec.destination.server }}
  project: default
  source:
    helm:
      parameters:
      - name: operator.create
        value: "true"
      - name: generateBasicAuth
        value: "true"
      - name: functionNamespace
        value: openfaas-fn
    path: chart/openfaas
    repoURL: https://github.com/openfaas/faas-netes.git
  syncPolicy:
    automated:
      selfHeal: true
```

The template for the openfaas-functions application:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openfaas-functions
  namespace: argocd
spec:
  destination:
    server: {{ .Values.spec.destination.server }}
  project: default
  source:
    path: chart/functions
    repoURL: https://github.com/welteki/openfaas-argocd-example.git
  syncPolicy:
    automated:
      selfHeal: true
```

The full example is [available on GitHub](https://github.com/welteki/openfaas-argocd-example)

The parent app can be created and synced via the CLI:
```bash
argocd app create applications \
    --dest-namespace argocd \
    --dest-server https://kubernetes.default.svc \
    --repo https://github.com/welteki/openfaas-argocd-example.git \
    --path chart/applications

argocd app sync applications
```

You can check the Argo CD UI to see if the apps were synced successfully or use `kubectl` to verify if OpenFaaS and the functions are running.

```bash
kubectl get pods -n openfaas

NAME                              READY   STATUS    RESTARTS          AGE
alertmanager-c4df79ff7-2fxcs      1/1     Running   2 (4h42m ago)     39h
basic-auth-plugin-588f588-rkgmz   1/1     Running   2 (4h42m ago)     39h
gateway-55fd54cb76-xf4n7          2/2     Running   3 (4h42m ago)     39h
nats-67d8f684f8-x46zj             1/1     Running   2 (4h42m ago)     39h
prometheus-cd4844fc7-c6j2b        1/1     Running   2 (4h42m ago)     39h
queue-worker-5795ff9bb5-tkwpv     1/1     Running   3 (4h42m ago)     39h
```

```bash
kubectl get functions -n openfaas-fn

NAME             IMAGE
email-notify     welteki/email-notify:0.1.0
marketing-list   welteki/marketing-list:0.1.0
```

### Install and configure the ArgoCD Image Updater
The [installation documentation ](https://argocd-image-updater.readthedocs.io/en/stable/install/installation/) for the Argo CD Image Updater describes multiple installation options. We are going to install it in the same namespace where Argo CD is running using its Kubernetes manifest.
```bash
kubectl apply -n argocd  \
  -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

The Kubernetes resource of our openfaas-functions applications must be annotated correctly in order for the Argo CD Image Updater to know it should inspect and update the container images.

We need to update the openfaas-functions application template and add the following annotations:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    argocd-image-updater.argoproj.io/image-list: marketingList=welteki/marketing-list:~0.1
    argocd-image-updater.argoproj.io/marketingList.helm.image-spec: marketingList.image
  name: openfaas-functions
  namespace: argocd
spec:
  destination:
    server: {{ .Values.spec.destination.server }}
  project: default
  source:
    path: chart/functions
    repoURL: https://github.com/welteki/openfaas-argocd-example.git
  syncPolicy:
    automated:
      selfHeal: true
```

The annotation `argocd-image-updater.argoproj.io/image-list` is used to specify a list of images that should be considered for updates. It should be a comma separated list of image specifications.

An image specification could be formally described as:
```
[<alias_name>=]<image_path>[:<version_constraint>]
```

In our example we configure the Image Updater to watch for updates of the `welteki/marketing-list` image. The version constraint `~0.1` will tell it to update to any patch version within the `0.1` minor release only. The image is assigned an alias name of `marketingList`. This is required because our functions Helm Chart contains multiple functions each with their own parameter to set the image name.

The second annotation is used to set the `helm.image-spec` for the `marketingList` alias to the appropriate Helm value:
```
argocd-image-updater.argoproj.io/marketingList.helm.image-spec: marketingList.image
```

> For a detailed explanation of the configuration options see: [Argo CD Image Updater - Configuration](https://argocd-image-updater.readthedocs.io/en/stable/configuration/applications/)

### Watch how functions get updated

We use [`envsubst`-style templates](https://docs.openfaas.com/reference/yaml/#yaml-environment-variable-substitution) in the YAML stack to make the image tag configurable.
```yaml
  marketing-list:
    lang: node17
    handler: ./marketing-list
    image: ${REGISTRY:-docker.io}/${REPO:-welteki}/marketing-list:${TAG:-dev}
```

To build and push a new version of the images run
```bash
TAG=0.1.4 faas-cli publish -f stack.yml
```

The logs for the Argo Image Updater show that it is considering 1 annotated application for update. Once it queries the registry for updated images it will detect the new version of our function image and update the openfaas-functions application to use the new version of the marketing-list function.
```
time="2022-06-14T20:33:41Z" level=info msg="Starting image update cycle, considering 1 annotated application(s) for update"
time="2022-06-14T20:33:43Z" level=info msg="Setting new image to welteki/marketing-list:0.1.4" alias=marketingList application=openfaas-functions image_name=welteki/marketing-list image_tag=0.1.3 registry=
time="2022-06-14T20:33:43Z" level=info msg="Successfully updated image 'welteki/marketing-list:0.1.3' to 'welteki/marketing-list:0.1.4', but pending spec update (dry run=false)" alias=marketingList application=openfaas-functions image_name=welteki/marketing-list image_tag=0.1.3 registry=
time="2022-06-14T20:33:43Z" level=info msg="Committing 1 parameter update(s) for application openfaas-functions" application=openfaas-functions
time="2022-06-14T20:33:43Z" level=info msg="Successfully updated the live application spec" application=openfaas-functions
```

## Conclusion
We used [the app-of-apps pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#app-of-apps) to declaratively define Argo CD applications for OpenFaaS and a set of OpenFaaS functions.

If you want Argo CD to deploy the latest version of your functions you have to update the openfaas-functions application to set the correct reference for each function image. We used the [Argo CD Image Updater](https://github.com/argoproj-labs/argocd-image-updater) to automate this. By adding some annotations to the openfaas-functions app we configured it to watch for updates to our function images. When a new version is published it will automatically update that function to use the new image.

This setup requires you to create a Helm Chart for your OpenFaaS functions. We have an article that show you how to do this:
- [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)

For more info about the Argo CD Image Updater checkout the official GitHub repo: https://github.com/argoproj-labs/argocd-image-updater

Take a look at these posts on our blog if you want to read some more about how to apply GitOps to OpenFaaS:
- [Bring GitOps to your OpenFaaS functions with ArgoCD](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/)
- [Applying GitOps to OpenFaaS with Flux Helm Operator](https://www.openfaas.com/blog/openfaas-flux/)