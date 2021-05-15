---
title: "Learn how to build your OpenFaaS Functions with Tekton"
description: "Learn how to trigger builds of your functions from GitHub using Tekton. Then connect them to Argo CD so that you can deploy as new versions are created."
date: 2021-05-14
image: /images/2021-06-tekton/tekton_argocd_power.png
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

Learn how to trigger builds of your functions from GitHub using Tekton. Then connect them to Argo CD so that you can deploy as new versions are created.

## Introduction

We talked about _How we can bring GitOps principles to management of OpenFaaS functions_ in the previous blog post. If you haven't read it yet, you can follow this [link](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/), because it might help you to understand the all of the pieces of CI/CD pipeline we want to build here. In this guide, we'll add CI (Continious Integration) part to our pipeline by using _Tekton_. After that, to be able to trigger this pipeline based on _GitHub_ events, we'll use an another component of [Tekton](https://tekton.dev) called [Tekton Trigger](https://tekton.dev/docs/triggers/). We will do this demo using KinD on a kubernetes running locally. Because of we are in a private network, we have to listen events that send by GitHub to trigger our Tekton Pipeline. So we need to find a way to susbcribe those events, and this is where Tekton Triggers comes into the picture. So, we said that everyhing is in local, so, we should open our local services to the internet, GitHub in this case, to be able GitHub send events to our event listener, and this is where Inlets, a Cloud Native Tunnel, comes in to the picture. At the end of this tutorial, we'll have a pipeline like the following:

![tekton_argocd_arch](/images/2021-06-tekton/argo_cd_tekton.jpg)

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

Before getting started to install _Tekton_  and _Tekton Trigger_, we have to install _Argo CD_ and _OpenFaaS Operator_ through the Argo CD, so we can follow the steps below to install them before move on to the next step.

1. Provision a local Kubernetes Cluster with KinD
2. Deploy ArgoCD
3. Deploy OpenFaaS Operator and OpenFaaS functions through ArgoCD

### 4. Deploy Tekton and Tekton Trigger

There are various ways to install _Tekton_ and _Tekton Trigger_ Trigger, one of them is _Tekton Operator_, and the other one is just with plain YAML manifest. We are going to deploy Tekton and Tekton Trigger with plain YAML manifest in this section.

To get more detail about _Tekton Operator_, please refer to this [link](https://github.com/tektoncd/operator).

Let's install _Tekton_.

```bash
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
```

Let's install _Tekton Trigger_.

```bash
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
```

We need to apply one more thing is _Interceptors_. An Interceptor is a "catch-all" event processor for a specific platform that runs before the TriggerBinding. It allows you to perform payload filtering, verification (using a secret), transformation, define and test trigger conditions, and implement other useful processing.

To get more detail about _Interceptors_, please refer to this [link](https://tekton.dev/docs/triggers/eventlisteners/#interceptors).

```bash
$ kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
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

### 5. Install Tasks, Pipelines and Triggers

Tekton provides as some kind of building blocks as _Custom Resources_ in order to build Cloud Native CI/CD pipelines, and these are the basic ones _Tasks_ and _Pipelines_.  Task defines steps that needs to be executed. A Task is effectively a Pod, while each step is a container within that Pod. Pipeline takes the name(s) and order of execution of TaskRun object(s). A Trigger specifies what happens when the EventListener detects an event. A Trigger specifies a TriggerTemplate, a TriggerBinding, and optionally an Interceptor.

To get more detail about them, please refer to this [link](https://tekton.dev/docs/pipelines/) for Tekton Primitives and this [link](https://tekton.dev/docs/triggers/) for Tekton Triggers.

Let's install them but we need to first clone the repository that involves manifest files for them.

```bash
$ git clone https://github.com/developer-guy/manage-your-functions-based-on-cloud-native-ci-cd-using-tekton.git
```

Before installing them we do some kind of initial set up for the pipelines such as granting necessary permissions by creating RBAC, creating ssh-key to be able commit and push to the repository, creating git source as PersistentVolumeClaim, creating a secrets which contains Docker Hub credentials, and ssh-key information etc.

```bash
$ cd manage-your-functions-based-on-cloud-native-ci-cd-using-tekton
$ ssh-keygen -t rsa -b 4096 -C "tekton@tekton.dev"
# save as tekton / tekton.pub
# add tekton.pub contents to GitHub

$ kubectl apply -f tekton-git-ssh-secret.yaml

$ kubectl apply -f serviceaccount.yaml
$ kubectl create secret docker-registry regcred
  --docker-username=$DOCKER_USERNAME \
  --docker-password=$DOCKER_PASSWORD \
  --docker-email=$DOCKER_EMAIL --docker-server https://index.docker.io/v1/

$ kubectl apply -f git-source-pvc.yaml
```

Next step, deploying Tasks, Pipelines and Triggers

```bash
$ kubectl apply -f tasks/

$ kubectl apply -f pipeline/build-and-deploy-pipeline.yaml

$ kubectl apply -f triggers/
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

Our event Listener needs to receive HTTP messages from X. Therefore create an inlets tunnel so that Y.

```bash
$ kubectl port-forward svc/el-github-listener-interceptor 8080 &

$ inlets-pro http client --token=$TOKEN --url=$WSS --upstream http://127.0.0.1:8080 --license-file $HOME/.inlets/LICENSE --auto-tls=false
2021/05/15 15:07:38 Starting HTTP client. Version 0.8.0-dirty - $TOKEN
2021/05/15 15:07:38 Licensed to: Batuhan Apaydın <xxx@gmail.com>, expires: 51 day(s)
2021/05/15 15:07:38 Upstream:  => http://127.0.0.1:8080
2021/05/15 15:07:38 Token: "$TOKEN"
INFO[2021/05/15 15:07:38] Connecting to proxy url="wss://$WSS"
```

With your _$WSS_ and the _$TEKTON_TUTORIAL_SECRET_TOKEN_, create webhook from _Webhook_ page under the _Settings_ tab of your repository like the following:

![webhook](/images/2021-06-tekton/setup_webhook.png)

Now everything is ready to trigger the pipeline, once we update our function code, it'll trigger the pipeline.

To see everything what's happening in your cluster is opening UI's for both Argo CD and Tekton.
You can visit _localhost:8443_ in order to connect Argo CD UI's screen but for Tekton, you need to install _Tekton Dashboard_.

### 6. Install Tekton Dashboard

Tekton has another great project called [Tekton Dashboard](https://github.com/tektoncd/dashboard). Tekton Dashboard is a general purpose, web-based UI for Tekton Pipelines and Tekton triggers resources. We can easily install this to our cluster and see what's goin' on our cluster. Run the following command to install Tekton Dashboard and its dependencies:

```bash
$ kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/tekton-dashboard-release.yaml
```

You can simple access to your dashboard with running the following command:

```bash
$ kubectl --namespace tekton-pipelines port-forward svc/tekton-dashboard 9097:9097
Forwarding from 127.0.0.1:9097 -> 9097
Forwarding from [::1]:9097 -> 9097

$ open http://localhost:9097
```

I recommend you to divide screen into two part, one for Argo CD UI and one for Tekton UI to follow the process before making any changes on your repository.

![follow_process](/images/2021-06-tekton/follow_process.png)

### 7. Test

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
