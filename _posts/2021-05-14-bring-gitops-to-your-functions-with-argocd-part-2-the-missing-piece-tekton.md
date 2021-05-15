---
title: "Bring GitOps to your OpenFaaS functions with Argo CD - The missing piece of the pipeline: Tekton"
description: "In this post you'll learn how to combine these two technologies ArgoCD and Tekton to build fully automated CI/CD pipeline which can be triggerred by Github to manage OpenFaaS functions based on GitOps principles in your local environment using a Cloud Native Tunnel called Inlets"
date: 2021-05-14
image: /images/bring-gitops-to-your-functions-with-argocd-part-2-the-missing-piece-tekton/tekton_argocd_power.png
categories:
- arkade
- kubectl
- argocd
- tekton
- gitops
- openfaas-operator
- helm
author_staff_member: developer-guy
dark_background: true

---

In this post you'll learn how to combine these two technologies ArgoCD and Tekton to build fully automated CI/CD pipeline which can be triggerred by Github to manage OpenFaaS functions based on GitOps principles in your local environment using a Cloud Native Tunnel called Inlets

## Introduction

We talked about _How we can bring GitOps principles to management of OpenFaaS functions_ in the previous blog post. If you haven't read it yet, you can follow this [link](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/), because it might help you to understand the all of the pieces of CI/CD pipeline we want to build here. In this guide, we'll add CI (Continious Integration) part to our pipeline by using _Tekton_. After that, to be able to trigger this pipeline based on _Github_ events, we'll use an another component of [Tekton](https://tekton.dev) called [Tekton Trigger](https://tekton.dev/docs/triggers/). We will do this demo using KinD on a kubernetes running locally. Because of we are in a private network, we have to listen events that send by Github to trigger our Tekton Pipeline. So we need to find a way to susbcribe those events, and this is where Tekton Triggers comes into the picture. So, we said that everyhing is in local, so, we should open our local services to the internet, Github in this case, to be able Github send events to our event listener, and this is where Inlets, a Cloud Native Tunnel, comes in to the picture. At the end of this tutorial, we'll have a pipeline like the following:

![tekton_argocd_arch](/images/bring-gitops-to-your-functions-with-argocd-part-2-the-missing-piece-tekton/argo_cd_tekton.png)

## Prerequisites

We have to install the following tools to be able to achieve this demo, luckily we have [arkade](https://github.com/alexellis/arkade) which is an open-source Kubernetes marketplace, so we can install of the following tools by using arkade:

 * [arkade](https://get-arkade.dev) (v0.7.15) Kubernetes marketplace

  ```bash
  # Run with or without sudo
  $ curl -sLS https://dl.get-arkade.dev | sudo sh
  ```

* KinD (Kubernetes in Docker) v0.10.0

  Kubernetes is our recommendation for teams running at scale, but in this demo we will be
    using [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/) for the sake of simplicity.

  ```bash
  $ arkade get kind --version=v0.10.0
  ```

* kubectl v1.21.0

  You can control your cluster using [kubectl](https://github.com/kubernetes/kubectl) CLI.

  ```bash
  $ arkade get kubectl --version=v1.21.0
  ```

* tkn v0.18.0

  You can use  [tkn](https://github.com/tektoncd/cli) CLI for interacting with Tekton resources.

  ```bash
  $ arkade get tkn --version=v0.18.0
  ```

* ArgoCD CLI v2.0.0

  ArgoCD CLI controls an Argo CD server. More detailed installation instructions can be found via
    the [CLI installation documentation](https://argoproj.github.io/argo-cd/cli_installation/). Fortunately, we can
    install it via arkade too.

  ```bash
  $ arkade get argocd --version=v2.0.0
  ```

### Setup

### 1. Provision a local Kubernetes Cluster with KinD

You can start a Kubernetes cluster with KinD if you don't have one already.

```bash
$ kind create cluster --name tekton --config kind-config.yaml
Creating cluster "tekton" ...
 ✓ Ensuring node image (kindest/node:v1.20.2) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-tekton"
You can now use your cluster with:

kubectl cluster-info --context kind-tekton

Thanks for using kind! 😊
```

Verify if your cluster working properly before moving onto the next step.

```bash
$ kubectl cluster-info
Kubernetes control plane is running at https://127.0.0.1:49809
KubeDNS is running at https://127.0.0.1:49809/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

### 2. Deploy ArgoCD

There are various ways to install ArgoCD, one of them is _ArgoCD Operator_, and the other one is just with plain YAML
manifest. We are going to deploy ArgoCD with plain YAML manifest in this section.

arkade is not only for the CLI tooling, it also helps you to get started to install applications using helm under the hood, 
hopefully arkade also supports installing ArgoCD.

```bash
$ kubectl create namespace argocd
$ arkade install argocd
Using Kubeconfig: /Users/batuhan.apaydin/.kube/config
Node architecture: "amd64"
=======================================================================
= ArgoCD has been installed                                           =
=======================================================================

# Get the ArgoCD CLI
arkade install argocd

# Port-forward the ArgoCD API server
kubectl port-forward svc/argocd-server -n argocd 8443:443 &

# Get the password
PASS=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d)
echo $PASS

# Or log in:
argocd login --name local 127.0.0.1:8443 --insecure \
 --username admin \
 --password $PASS

# Open the UI:
https://127.0.0.1:8443

# Get started with ArgoCD at
# https://argoproj.github.io/argo-cd/#quick-start

Thanks for using arkade!
```

Verify if everything is working properly in _argocd_ namespace before moving onto the next step.

```bash
$ kubectl get pods --namespace argocd
NAME                                  READY   STATUS    RESTARTS   AGE
argocd-application-controller-0       1/1     Running   0          2m55s
argocd-dex-server-5dd657bd9-8tqf9     1/1     Running   0          2m55s
argocd-redis-759b6bc7f4-m8gbp         1/1     Running   0          2m55s
argocd-repo-server-6c495f858f-mb9jn   1/1     Running   0          2m55s
argocd-server-859b4b5578-29df8        1/1     Running   0          2m55s
```

### 3. Deploy OpenFaaS Operator and OpenFaaS functions through ArgoCD

We have a repository which we store all the necessarry manifest files for both _Argo CD_ and _OpenFaaS operator_. Because we are going to apply _**apps-of-apps**_ pattern in here, which means we can create an app that creates other apps,

To get more detail about _**apps-of-apps**_ pattern, please refer to
this [link](https://argoproj.github.io/argo-cd/operator-manual/declarative-setup/#app-of-apps).

Let's clone this repository, have a look at the manifest files.

```bash
$ mkdir -p demo-workspace
$ cd demo-workspace
$ git clone https://github.com/developer-guy/hello-function.git
Cloning into 'hello-function'...
remote: Enumerating objects: 133, done.
remote: Counting objects: 100% (133/133), done.
remote: Compressing objects: 100% (70/70), done.
remote: Total 133 (delta 38), reused 133 (delta 38), pack-reused 0
Receiving objects: 100% (133/133), 31.67 KiB | 953.00 KiB/s, done.
Resolving deltas: 100% (38/38), done.
```

After you cloned it, you'll notice that there is a special file called _app-of-apps.yaml_ which we used to use for referencing to other apps.
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  destination:
    namespace: openfaas
    server: https://kubernetes.default.svc
  project: default
  source:
    directory:
      recurse: true
    path: apps # notice here, we are referencing another folder which includes manifest files for other apps
    repoURL: https://github.com/developer-guy/hello-function.git
    targetRevision: master
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Let's apply that manifest, and see what will happen in our cluster.

```bash
$ kubectl create namespace openfaas-fn # we should create this namespace first.
$ kubectl apply -f app-of-apps.yaml
application.argoproj.io/app-of-apps created
```

Now, we are going to use _argocd CLI_ to see what Argo CD creates for us.

First, we need to authenticate to ArgoCD server.Argo CD v1.9. Later the initial password for the admin account is
auto-generated and stored as clear text in the field password in a secret named argocd-initial-admin-secret in your Argo
CD installation namespace:

```bash
# Port-forward the ArgoCD API server
$ kubectl port-forward svc/argocd-server -n argocd 8443:443
Forwarding from 127.0.0.1:8443 -> 443
Forwarding from [::1]:8443 -> 443

# Get the password
$ PASS=$(kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d)
$ echo $PASS

# Or log in:
$ argocd login --name local 127.0.0.1:8443 --insecure \
 --username admin \
 --password $PASS
WARNING: server certificate had error: x509: certificate signed by unknown authority. Proceed insecurely (y/n)? y
Username: admin
Password:
'admin:login' logged in successfully
Context 'local' updated
 ```

To get more detail about login process, please refer to
this [link](https://argoproj.github.io/argo-cd/getting_started/#4-login-using-the-cli).

Verify if you log into ArgoCD properly before moving on the next step.

```bash
$ argocd account list
NAME   ENABLED  CAPABILITIES
admin  true     login

$ argocd app list
NAME               CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH   SYNCPOLICY  CONDITIONS  REPO                                                 PATH       TARGET
app-of-apps        https://kubernetes.default.svc  openfaas   default  Synced  Healthy  Auto-Prune  <none>      https://github.com/developer-guy/hello-function.git  apps       master
hello-function     https://kubernetes.default.svc  default    default  Synced  Healthy  Auto-Prune  <none>      https://github.com/developer-guy/hello-function.git  manifests  master
openfaas-operator  https://kubernetes.default.svc  openfaas   default  Synced  Healthy  Auto-Prune  <none>      https://openfaas.github.io/faas-netes                           7.2.8                       7.2.8
```

Verify if everything is working before moving onto the next step.

```bash
$ kubectl get pods --namespace default
NAME                             READY   STATUS             RESTARTS   AGE
hellofunction-7849c4cf8d-zdgm4   0/1     InvalidImageName   0          9m30s
# this is totally fine becuase we are using a placeholder as image name.

$ kubectl get pods --namespace openfaas
NAME                                 READY   STATUS    RESTARTS   AGE
alertmanager-795797ffd4-8wq54        1/1     Running   0          12m
basic-auth-plugin-85d885557c-422lz   1/1     Running   0          12m
gateway-548fcb58-wcs4h               2/2     Running   1          12m
nats-5fdf6476f-l6fz8                 1/1     Running   0          12m
prometheus-7f48755f4f-5cslr          1/1     Running   0          12m
queue-worker-5cfd6689f5-qtghb        1/1     Running   1          12m
```

### 3. Deploy Tekton and Tekton Trigger

There are various ways to install _Tekton_ and _Tekton Trigger_ Trigger, one of them is _Tekton Operator_, and the other one is just with plain YAML manifest. We are going to deploy Tekton and Tekton Trigger with plain YAML manifest in this section.

To get more detail about _Tekton Operator_, pleae refer to this [link](https://github.com/tektoncd/operator).

Let's install _Tekton_.

```bash
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
namespace/tekton-pipelines created
podsecuritypolicy.policy/tekton-pipelines created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-controller-cluster-access created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-controller-tenant-access created
clusterrole.rbac.authorization.k8s.io/tekton-pipelines-webhook-cluster-access created
role.rbac.authorization.k8s.io/tekton-pipelines-controller created
role.rbac.authorization.k8s.io/tekton-pipelines-webhook created
role.rbac.authorization.k8s.io/tekton-pipelines-leader-election created
serviceaccount/tekton-pipelines-controller created
serviceaccount/tekton-pipelines-webhook created
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-cluster-access created
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-tenant-access created
clusterrolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook-cluster-access created
Warning: rbac.authorization.k8s.io/v1beta1 RoleBinding is deprecated in v1.17+, unavailable in v1.22+; use rbac.authorization.k8s.io/v1 RoleBinding
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-controller-leaderelection created
rolebinding.rbac.authorization.k8s.io/tekton-pipelines-webhook-leaderelection created
customresourcedefinition.apiextensions.k8s.io/clustertasks.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/conditions.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/pipelines.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/pipelineruns.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/pipelineresources.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/runs.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/tasks.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/taskruns.tekton.dev created
secret/webhook-certs created
validatingwebhookconfiguration.admissionregistration.k8s.io/validation.webhook.pipeline.tekton.dev created
mutatingwebhookconfiguration.admissionregistration.k8s.io/webhook.pipeline.tekton.dev created
validatingwebhookconfiguration.admissionregistration.k8s.io/config.webhook.pipeline.tekton.dev created
clusterrole.rbac.authorization.k8s.io/tekton-aggregate-edit created
clusterrole.rbac.authorization.k8s.io/tekton-aggregate-view created
configmap/config-artifact-bucket created
configmap/config-artifact-pvc created
configmap/config-defaults created
configmap/feature-flags created
configmap/config-leader-election created
configmap/config-logging created
configmap/config-observability created
configmap/config-registry-cert created
deployment.apps/tekton-pipelines-controller created
service/tekton-pipelines-controller created
horizontalpodautoscaler.autoscaling/tekton-pipelines-webhook created
deployment.apps/tekton-pipelines-webhook created
service/tekton-pipelines-webhook created
```

Let's install _Tekton Trigger_.

```bash
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
podsecuritypolicy.policy/tekton-triggers created
clusterrole.rbac.authorization.k8s.io/tekton-triggers-admin created
clusterrole.rbac.authorization.k8s.io/tekton-triggers-core-interceptors created
role.rbac.authorization.k8s.io/tekton-triggers-admin created
role.rbac.authorization.k8s.io/tekton-triggers-admin-webhook created
role.rbac.authorization.k8s.io/tekton-triggers-core-interceptors created
serviceaccount/tekton-triggers-controller created
serviceaccount/tekton-triggers-webhook created
serviceaccount/tekton-triggers-core-interceptors created
clusterrolebinding.rbac.authorization.k8s.io/tekton-triggers-controller-admin created
clusterrolebinding.rbac.authorization.k8s.io/tekton-triggers-webhook-admin created
clusterrolebinding.rbac.authorization.k8s.io/tekton-triggers-core-interceptors created
rolebinding.rbac.authorization.k8s.io/tekton-triggers-controller-admin created
rolebinding.rbac.authorization.k8s.io/tekton-triggers-webhook-admin created
rolebinding.rbac.authorization.k8s.io/tekton-triggers-core-interceptors created
customresourcedefinition.apiextensions.k8s.io/clusterinterceptors.triggers.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/clustertriggerbindings.triggers.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/eventlisteners.triggers.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/triggers.triggers.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/triggerbindings.triggers.tekton.dev created
customresourcedefinition.apiextensions.k8s.io/triggertemplates.triggers.tekton.dev created
secret/triggers-webhook-certs created
validatingwebhookconfiguration.admissionregistration.k8s.io/validation.webhook.triggers.tekton.dev created
mutatingwebhookconfiguration.admissionregistration.k8s.io/webhook.triggers.tekton.dev created
validatingwebhookconfiguration.admissionregistration.k8s.io/config.webhook.triggers.tekton.dev created
clusterrole.rbac.authorization.k8s.io/tekton-triggers-aggregate-edit created
clusterrole.rbac.authorization.k8s.io/tekton-triggers-aggregate-view created
configmap/config-logging-triggers created
configmap/config-observability-triggers created
service/tekton-triggers-controller created
deployment.apps/tekton-triggers-controller created
service/tekton-triggers-webhook created
deployment.apps/tekton-triggers-webhook created
```

We need to apply one more thing is _Interceptors_. An Interceptor is a "catch-all" event processor for a specific platform that runs before the TriggerBinding. It allows you to perform payload filtering, verification (using a secret), transformation, define and test trigger conditions, and implement other useful processing.

To get more detail about _Interceptors_, please refer to this [link](https://tekton.dev/docs/triggers/eventlisteners/#interceptors).

```bash
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
deployment.apps/tekton-triggers-core-interceptors created
service/tekton-triggers-core-interceptors created
clusterinterceptor.triggers.tekton.dev/cel created
clusterinterceptor.triggers.tekton.dev/bitbucket created
clusterinterceptor.triggers.tekton.dev/github created
clusterinterceptor.triggers.tekton.dev/gitlab created
```

Verify if everything is working before moving onto the next step.

```bash
$ kubectl get pods --namespace tekton-pipelines
NAME                                                 READY   STATUS    RESTARTS   AGE
tekton-pipelines-controller-5cf4d4867f-s6tqv         1/1     Running   0          5m21s
tekton-pipelines-webhook-57bfb4b4d7-7jp8c            1/1     Running   0          5m20s
tekton-triggers-controller-7cbd49fbb8-d2bgj          1/1     Running   0          4m40s
tekton-triggers-core-interceptors-5d7f674ccc-d4fq7   1/1     Running   0          2m5s
tekton-triggers-webhook-748fb7778c-mpg94             1/1     Running   0          4m40s
```

### 4. Install Tasks, Pipelines and Triggers

Tekton provides as some kind of building blocks as _Custom Resources_ in order to build Cloud Native CI/CD pipelines, and these are the basic ones _Tasks_ and _Pipelines_.  Task defines steps that needs to be executed. A Task is effectively a Pod, while each step is a container within that Pod. Pipeline takes the name(s) and order of execution of TaskRun object(s). A Trigger specifies what happens when the EventListener detects an event. A Trigger specifies a TriggerTemplate, a TriggerBinding, and optionally an Interceptor.

To get more detail about them, please refer to this [link](https://tekton.dev/docs/pipelines/) for Tekton Primitives and this [link](https://tekton.dev/docs/triggers/) for Tekton Triggers.

Let's install them but we need to first clone the repository that involves manifest files for them.

```bash
$ git clone https://github.com/developer-guy/manage-your-functions-based-on-cloud-native-ci-cd-using-tekton.git
Cloning into 'manage-your-functions-based-on-cloud-native-ci-cd-using-tekton'...
remote: Enumerating objects: 102, done.
remote: Counting objects: 100% (102/102), done.
remote: Compressing objects: 100% (75/75), done.
remote: Total 102 (delta 47), reused 69 (delta 25), pack-reused 0
Receiving objects: 100% (102/102), 2.49 MiB | 5.02 MiB/s, done.
Resolving deltas: 100% (47/47), done.
```

Before installing them we do some kind of initial set up for the pipelines such as granting necessary permissions by creating RBAC, creating ssh-key to be able commit&push to the repository, creating git source as PersistentVolumeClaim, creating a secrets which contains dockerhub credentials, and ssh-key information etc.

```bash
$ cd manage-your-functions-based-on-cloud-native-ci-cd-using-tekton
$ ssh-keygen -t rsa -b 4096 -C "tekton@tekton.dev"
# save as tekton / tekton.pub
# add tekton.pub contents to GitHub

$ kubectl apply -f tekton-git-ssh-secret.yaml
secret/git-ssh-key created

$ kubectl apply -f serviceaccount.yaml
serviceaccount/pipeline-account created
secret/kube-api-secret created
role.rbac.authorization.k8s.io/pipeline-role created
rolebinding.rbac.authorization.k8s.io/pipeline-role-binding created

$ kubectl create secret docker-registry regcred
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL --docker-server https://index.docker.io/v1/
secret/regcred created

$ kubectl apply -f git-source-pvc.yaml
persistentvolumeclaim/myclaim created
```

Next step, deploying Tasks, Pipelines and Triggers

```bash
$ kubectl apply -f tasks/
task.tekton.dev/faas-cli-build created
task.tekton.dev/git-clone created
task.tekton.dev/kaniko created
task.tekton.dev/deploy-using-kubectl created

$ tkn tasks list
NAME              DESCRIPTION              AGE
faas-cli-build    This task create a ...   53 seconds ago
git-clone         These Tasks are Git...   53 seconds ago
kaniko            This Task builds so...   53 seconds ago
update-manifest                            53 seconds ago

$ kubectl apply -f pipeline/build-and-deploy-pipeline.yaml
pipeline.tekton.dev/build-and-deploy created

$ tkn pipeline list
NAME               AGE              LAST RUN   STARTED   DURATION   STATUS
build-and-deploy   17 seconds ago   ---        ---       ---        ---

$ kubectl apply -f triggers/
eventlistener.triggers.tekton.dev/github-listener-interceptor created
triggerbinding.triggers.tekton.dev/github-pr-binding created
triggertemplate.triggers.tekton.dev/github-template created
serviceaccount/tekton-triggers-example-sa created
role.rbac.authorization.k8s.io/tekton-triggers-example-minimal created
rolebinding.rbac.authorization.k8s.io/tekton-triggers-example-binding created
clusterrole.rbac.authorization.k8s.io/tekton-triggers-example-clusterrole created
clusterrolebinding.rbac.authorization.k8s.io/tekton-triggers-example-clusterbinding created

$ tkn triggertemplate list
NAME              AGE
github-template   31 seconds ago

$ tkn triggerbinding list
NAME                AGE
github-pr-binding   34 seconds ago
```

Verify if everything is working before moving onto the next step.

```bash
$ kubectl get pods
NAME                                              READY   STATUS             RESTARTS   AGE
el-github-listener-interceptor-7bc945b898-jlst8   1/1     Running            0          68s
hellofunction-7849c4cf8d-zdgm4                    0/1     InvalidImageName   0          52m
```

_el-github-listener-interceptor-7bc945b898-jlst8_ this Pod is our _EventListener_, we should open it to the internet to be able to get events from the Github, now we'll do port-forwarding to make it reachable from localhost, then we'll run _inlets-pro_ to make it reachable from the internet.

But before doing that we need create some sort of secret for Github Webhook. Save this secret because we'll use that when we set up Webhook in Github for our repository.

```bash
$ export TEKTON_TUTORIAL_SECRET_TOKEN=${TEKTON_TUTORIAL_SECRET_TOKEN-$(head -c 24 /dev/random | base64)}
$ kubectl create secret generic github-secret --from-literal=secretToken=$TEKTON_TUTORIAL_SECRET_TOKEN
$ echo "TEKTON_TUTORIAL_SECRET_TOKEN: $TEKTON_TUTORIAL_SECRET_TOKEN"
xxxxx
```

Let's make it reachable our EventListener.

```bash
$ kubectl port-forward svc/el-github-listener-interceptor 8080
Forwarding from 127.0.0.1:8080 -> 8000
Forwarding from [::1]:8080 -> 8000

$ inlets-pro http client --token=$TOKEN --url=$WSS --upstream http://127.0.0.1:8080 --license-file $HOME/.inlets/LICENSE --auto-tls=false
2021/05/15 15:07:38 Starting HTTP client. Version 0.8.0-dirty - $TOKEN
2021/05/15 15:07:38 Licensed to: Batuhan Apaydın <xxx@gmail.com>, expires: 51 day(s)
2021/05/15 15:07:38 Upstream:  => http://127.0.0.1:8080
2021/05/15 15:07:38 Token: "$TOKEN"
INFO[2021/05/15 15:07:38] Connecting to proxy url="wss://$WSS"
```

With your _$WSS_ and the _$TEKTON_TUTORIAL_SECRET_TOKEN_, create webhook from _Webhook_ page under the _Settings_ tab of your repository like the following:

![webhook](/images/bring-gitops-to-your-functions-with-argocd-part-2-the-missing-piece-tekton/setup_webhook.png)

Now everything is ready to trigger the pipeline, once we update our function code, it'll trigger the pipeline.

To see everything what's happening in your cluster is opening UI's for both Argo CD and Tekton.
You can visit _localhost:8443_ in order to connect Argo CD UI's screen but for Tekton, you need to install _Tekton Dashboard_.

### 5. Install Tekton Dashboard

Tekton has another great project called [Tekton Dashboard](https://github.com/tektoncd/dashboard). Tekton Dashboard is a general purpose, web-based UI for Tekton Pipelines and Tekton triggers resources. We can easily install this to our cluster and see what's goin' on our cluster. Run the following command to install Tekton Dashboard and its dependencies:

```bash
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml
customresourcedefinition.apiextensions.k8s.io/extensions.dashboard.tekton.dev created
serviceaccount/tekton-dashboard created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-backend created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-dashboard created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-extensions created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-pipelines created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-tenant created
clusterrole.rbac.authorization.k8s.io/tekton-dashboard-triggers created
clusterrolebinding.rbac.authorization.k8s.io/tekton-dashboard-backend created
service/tekton-dashboard created
deployment.apps/tekton-dashboard created
rolebinding.rbac.authorization.k8s.io/tekton-dashboard-pipelines created
rolebinding.rbac.authorization.k8s.io/tekton-dashboard-dashboard created
rolebinding.rbac.authorization.k8s.io/tekton-dashboard-triggers created
clusterrolebinding.rbac.authorization.k8s.io/tekton-dashboard-tenant created
clusterrolebinding.rbac.authorization.k8s.io/tekton-dashboard-extensions created
```

You can simple access to your dashboard with running the following command:

```bash
$ kubectl --namespace tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
Forwarding from 127.0.0.1:9097 -> 9097
Forwarding from [::1]:9097 -> 9097

$ open http://localhost:9097
```

I recommend you to divide screen into two part, one for Argo CD UI and one for Tekton UI to follow the process before making any changes on your repository.

![follow_process](/images/bring-gitops-to-your-functions-with-argocd-part-2-the-missing-piece-tekton/follow_process.png)

### 6. Test

Finally, let's test our function, to do so, we should access the OpenFaaS Gateway component.

```bash
$ kubectl port-forward svc/gateway -n openfaas 8081:8080
Forwarding from 127.0.0.1:8081 -> 8080
Forwarding from [::1]:8081 -> 8080

$ httpie POST http://localhost:8081/function/hellofunction.default message="Hello World"
HTTP/1.1 200 OK
Content-Length: 35
Content-Type: text/plain; charset=utf-8
Date: Fri, 07 May 2021 08:35:44 GMT
X-Call-Id: 0ee19dd7-2c09-4093-9b6e-0755836afb9c
X-Duration-Seconds: 0.004628
X-Start-Time: 1620376544209429100

Body v6: {"message": "Hello World"}
```

Tadaaaa 🎉😋✅

### Join the community

Have you got questions, comments, or suggestions? Join the community on [Slack](https://slack.openfaas.io).

Would you like help to set up your OpenFaaS installation, or someone to call when things don't quite go to
plan? [Our OpenFaaS PRO Subscription plan](https://www.openfaas.com/support/) gives you a say in the project roadmap, a
support contact, and access to Enterprise-grade authentication with OIDC.

### Acknowledgements

* [Alex Ellis](https://twitter.com/alexellisuk) for guidance, editing and providing the diagrams.

### References

* [Argo CD - Declarative GitOps CD for Kubernetes](https://argoproj.github.io/argo-cd/getting_started)
* [Getting Started with the OpenFaaS Kubernetes Operator](https://dzone.com/articles/getting-started-with-the-openfaas-kubernetes-opera)
* [Cloud Native CI/CD with Tekton - Laying The Foundation](https://martinheinz.dev/blog/45)
* [Exploring Tekton's cloud native CI/CD primitives](https://www.jetstack.io/blog/exploring-tekton/)
