---
title: "Kubernetes Webhooks made easy with OpenFaaS"
description: "Extending the Kubernetes with Admission webhook using OpenFaaS Serverless Functions"
date: 2020-10-23
image: /images/2020-10-github-actions/lego.jpg
categories:
  - arkade
  - kubectl
  - faas-cli
  - kind
  - k8s
  - admissionwebhooks
  - validatingadmissionwebhooks
  - k8s-extensibility
author_staff_member: developer-guy
dark_background: true
---

Extending the Kubernetes with AdmissionWebhook using OpenFaaS Serverless Functions

![kubernetes](/images/openfaas/kubernetes.png)
## Introduction: Kubernetes Admission webhooks
Admission webhooks are HTTP callbacks that receive admission requests and do something with them. You can define two types of admission webhooks, validating admission webhook and mutating admission webhook. Mutating admission webhooks are invoked first, and can modify objects sent to the API server to enforce custom defaults. After all object modifications are complete, and after the incoming object is validate by the API server, validating admission webhooks are invoked and can reject requests to enforce custom policies.

## Problem
Let's assume, in our company, we have some requirements that we must meet while deploying applications onto the Kubernetes cluster. We need to set some required labels to our Kubernetes manifest. Unless we specify the required labels our request will reject. 

So, in order to apply those requirements to the Kubernetes cluster to ensure the best practices, we can use Kubernetes [ValidatingAdmissionWebhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#validatingadmissionwebhook) and [OpenFaaS](https://www.openfaas.com) together. Since ValidatingAdmissionWebhooks intercepts requests to the apiserver, OpenFaaS functions includes a little code to check required labels and determines the request either allowed or not.

Webhook Admission Server is just plain http server that adhere to Kubernetes API. For each Pod create request to the apiserver(I said Pod because we specify which kind of resources that we consider while registering our webhook to the apiserver using [ValidatingWebhookConfiguration](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.19/#validatingwebhookconfiguration-v1-admissionregistration-k8s-io) resource) the ValidatingAdmissionWebhook sends an admissionReview([API](https://github.com/kubernetes/kubernetes/blob/v1.9.0/pkg/apis/admission/types.go) for reference) to the relevant webhook admission server. The webhook admission server gathers information like object, oldobject, and userInfo from admissionReview's AdmissionRequest and sends AdmissionRequest to the serverless function through the OpenFaaS Gateway. The function checks the required labels exist on Pod and determines the request either valid or not and then sends back the AdmissionResponse whose Allowed and Result fields are filled with the admission decision to the webhook admission server then the webhook admission servers sends back a admissionReview to the apiserver.

* Kubernetes API -> Webhook w/TLS -> OpenFaaS Gateway (w HTTP)

Supporting TLS for external webhook server is also required because admission is a high security operation. As part of the process, we need to create a TLS certificate signed by the Kubernetes CA to secure the communication between the webhook server and apiserver.
### Prerequisites
* Arkade

##### [arkade](https://get-arkade.dev) is The OpenFaaS community built tool for Kubernetes developers, with arkade you can easily install all necessary cli tools to your host and deploy apps to the cluster.

```sh
$ curl -sLS https://dl.get-arkade.dev | sudo sh
```

* KinD (Kubernetes in Docker)

##### Kubernetes is our recommendation for teams running at scale, but in this demo we will be using [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/) for the sake of simplicity.

```sh
$ arkade get kind
```

* kubectl

###### You can control your cluster using [kubectl](https://github.com/kubernetes/kubectl) CLI.

```sh
$ arkade get kubectl
```

* faas-cli

##### [faas-cli](https://github.com/openfaas/faas-cli) is an official CLI for OpenFaaS , with "faas-cli" you can build and deploy functions easily.

```sh
$ arkade get faas-cli
```

### Setup


### 1. Set Up a Kubernetes Cluster with Kind (Optional)

With Kind, you can run a local Kubernetes cluster using Docker containers as nodes. The steps in this section are optional. Follow them only if you don't have a running Kubernetes cluster.

* Create a file named openfaas-cluster.yaml, and copy in the following spec:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
```

* Create a KinD cluster using above config

```bash
$ kind create cluster --config kind-specs/kind-cluster.yaml
```

### 2. Deploy OpenFaaS to our local Kubernetes Cluster with arkade:

* Install a OpenFaaS

```sh
$ arkade install openfaas
```

* Verify that the deployments were created

```sh
$ kubectl get deployments -n openfaas -l "release=openfaas, app=openfaas"
```

### 3. Deploy Validating Admission Webhook
* Generating TLS certificate by using [Kubernetes TLS Certificates Management](https://kubernetes.io/docs/tasks/tls/managing-tls-in-a-cluster/)

```sh
$ cd deployment
$ sh webhook-create-signed-cert.sh
```

* Getting Certificate Authority from local cluster

```sh
$ export CA_BUNDLE=$(kubectl config view --minify --flatten -o json | jq -r '.clusters[] | select(.name == "'$(kubectl config current-context)'") | .cluster."certificate-authority-data"')
$ sed -e "s|\${CA_BUNDLE}|${CA_BUNDLE}|g" validatingwebhook.yaml | kubectl apply -f -
$ cd ..
```

* Let's Build the project

```sh
$ DOCKER_USER=<username> ./build
```

* Let's Deploy the project

```sh
$ cd deployment
$ kubectl apply -f rbac.yaml
$ kubectl apply -f service.yaml
$ kubectl apply -f deployment.yaml # make sure you are using same 'DOCKER_USER' in deployment.yaml. i.e: devopps
```

### 4. Building and Deploying OpenFaaS Function (Optional)

* Pull the [golang-middleware](https://github.com/openfaas-incubator/golang-http-template) template from [OpenFaaS Official Template Store](https://github.com/openfaas/store)

```sh
$ faas-cli template store list # check available templates in store
$ faas-cli template store describe golang-middleware # describe the specific template
$ faas-cli template store pull golang-middleware
```

* Create the function

```sh
$ faas-cli new requiredlabel --lang go-middleware
$ cd requiredlabel
$ go mod init requiredlabel
$ # fill the handler.go with the corresponding code
$ go get
```

* Let's build, push and deploy our function
```sh
$ cd functions
$ faas-cli up -f requiredlabel.yml --build-arg GO111MODULE=on # (build-push-deploy) make sure you are using your docker hub username. i.e: devopps
```

* Verify the functions that are working in `openfaas-fn` namespace

```sh
$ kubectl get pods --namespace openfaas-fn
```

## 5. Testing the whole workflow

* The purpose of this PoC is that to validate that pods has required `labels`. Which means you must have that labels:

```yaml
app.kubernetes.io/name: sleep
app.kubernetes.io/instance: sleep
app.kubernetes.io/version: "0.1"
app.kubernetes.io/component: dummy
app.kubernetes.io/part-of: admission-webhook-example
app.kubernetes.io/managed-by: kubernetes
```

* Any Pod who have above labels is valid for us.
```sh
`deployment/sleep.yaml` -> Incorrect, not-valid (We should deny this creation request.)
`deployment/sleep-no-validation.yaml` -> Skip-validation (Based on `admission-webhook-example.qikqiak.com/validate: "false"` annotation, we skipped validation.)
`deployment/sleep-with-labels.yaml` -> Correct, valid (We should accept this creation request.)
```

You can find all the code in this Github [repo](https://github.com/developer-guy/admission-webhook-example-with-openfaas).

### Join the community

Have you got questions, comments, or suggestions? Join the community on [Slack](https://slack.openfaas.io).

Would you like help to set up your OpenFaaS installation, or someone to call when things don't quite go to plan? [Our Premium Subscription plan](https://www.openfaas.com/support/) gives you a say in the project roadmap, a support contact, and access to Enterprise-grade authentication with OIDC.

### Acknowledgements

Special Thanks to  [Alex Ellis](https://twitter.com/alexellisuk) for all guidance and for merging changes into OpenFaaS to better support this workflow.

### References

* https://medium.com/ibm-cloud/diving-into-kubernetes-mutatingadmissionwebhook-6ef3c5695f74
* https://blog.alexellis.io/get-started-with-openfaas-and-kind/
* https://github.com/morvencao/kube-mutating-webhook-tutorial
* https://github.com/developer-guy/admission-webhook-example-with-openfaas