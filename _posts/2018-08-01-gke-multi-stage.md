---
title: Multi-stage Serverless on Kubernetes with OpenFaaS and GKE
description: Learn how to set up OpenFaaS on Google Kubernetes Engine (GKE) with a cost-effective, auto-scaling, multi-stage deployment.
date: 2018-08-14
image: /images/gke-multi-stage/pexels-architecture-buildings-city-185662.jpg
categories:
  - auto-scaling
  - kubernetes
  - gke
author_staff_member: stefan
dark_background: true
---

This is a guide on how to set up OpenFaaS on Google Kubernetes Engine (GKE) with a cost-effective, auto-scaling, multi-stage deployment.

_Experience level:_

_intermediate OpenFaaS / intermediate Kubernetes & GKE_

At the end of this guide you will be running two OpenFaaS environments on the same GKE cluster with the following characteristics: 
* a dedicated GKE node pool for OpenFaaS core services 
* a dedicated node pool made out of preemptible VMs for OpenFaaS functions 
* autoscaling for functions and their underlying infrastructure
* isolated staging and production environments with network policies
* secure OpenFaaS ingress with Let's Encrypt TLS and authentication

![openfaas-gke](/images/gke-multi-stage/overview.png)

This setup can enable multiple teams to share the same Continuous Delivery (CD) pipeline with staging/production environments 
hosted on GKE and development taking place on a [local environment](https://blog.alexellis.io/docker-for-mac-with-kubernetes/) such as Minikube or Docker for Mac.

## GKE cluster setup 

We will be creating a cluster on Google's Kubernetes Engine (GKE), if you don't have an account you can sign up [here](https://cloud.google.com/free/) for free credit.

Create a cluster with two nodes and network policy enabled:

```bash
zone=europe-west3-a
k8s_version=$(gcloud container get-server-config --zone=${zone} --format=json \
| jq -r '.validNodeVersions[0]')

gcloud container clusters create openfaas \
    --cluster-version=${k8s_version} \
    --zone=${zone} \
    --num-nodes=2 \
    --machine-type=n1-standard-1 \
    --no-enable-cloud-logging \
    --disk-size=30 \
    --enable-autorepair \
    --enable-network-policy \
    --scopes=gke-default,compute-rw,storage-rw
```

The above command will create a node pool named `default-pool` consisting of n1-standard-1 (vCPU: 1, RAM 3.75GB, DISK: 30GB) VMs. 

You will use the default pool to run the following OpenFaaS services:
* API [Gateway](https://github.com/openfaas/faas) and Kubernetes [Operator](https://github.com/openfaas-incubator/openfaas-operator)
* Async services ([NATS streaming](https://github.com/nats-io/nats-streaming-server) and [queue worker](https://github.com/openfaas/queue-worker))  
* Monitoring and Autoscaling services ([Prometheus](https://github.com/prometheus/prometheus) and [Alertmanager](https://github.com/prometheus/alertmanager))

Create a node pool of n1-highcpu-4 (vCPU: 4, RAM 3.60GB, DISK: 30GB) preemptible VMs with autoscaling enabled:

```bash
gcloud container node-pools create fn-pool \
    --cluster=openfaas \
    --preemptible \
    --node-version=${k8s_version} \
    --zone=${zone} \
    --num-nodes=1 \
    --enable-autoscaling --min-nodes=2 --max-nodes=4 \
    --machine-type=n1-highcpu-4 \
    --disk-size=30 \
    --enable-autorepair \
    --scopes=gke-default
```

[Preemptible VMs](https://cloud.google.com/preemptible-vms/) are up to 80% cheaper than regular instances 
and are terminated and replaced after a maximum of 24 hours. 

In order to avoid all nodes being replaced at the same time, wait for 30 minutes and scale up the function pool to two nodes.
Open a new terminal and run the scale up command: 

```bash
sleep 30m && gcloud container clusters resize openfaas \
    --size=2 \
    --node-pool=fn-pool \
    --zone=${zone} 
```
Now let that command run in the background and carry on with the next step.

GKE provides an audit-log of all key events from your cluster. Use the following command to see the logs of when each VM is preempted:

```bash
gcloud compute operations list | grep compute.instances.preempted
```

The cluster above along with a GCP load balancer forwarding rule and a 30GB ingress traffic per month will cost the following::

| Role | Type | Usage | Price per month |
|------|------|-------|-----------------|
| 2 x OpenFaaS Core Services | n1-standard-1 | 1460 total hours per month | $62.55 | 
| 2 x OpenFaaS Functions | n1-highcpu-4 | 1460 total hours per month | $53.44 | 
| Persistent disk | Storage | 120 GB | $5.76 | 
| Container Registry | Cloud Storage | 300 GB | $6.90 | 
| Forwarding rules | Forwarding rules | 1 | $21.90 |
| Load Balancer ingress | Ingress | 30 GB | $0.30 |
| Total |  |  | $150.84 |

The cost estimation for a total of 10 vCPU and 22GB RAM was generated with the [Google Cloud pricing calculator](https://cloud.google.com/products/calculator/) on 31 July 2018 and could change any time. 

## GKE TLS Ingress setup 

When exposing OpenFaaS on the Internet, it is recommended to enable HTTPS so that all traffic to the API gateway is encrypted.
To do that you'll need the following tools:

* [Heptio Contour](https://github.com/heptio/contour) as Kubernetes Ingress controller (or another ingress controller such as Nginx)
* [JetStack cert-manager](https://github.com/jetstack/cert-manager) as Let's Encrypt provider 

Set up credentials for `kubectl`:

```bash
gcloud container clusters get-credentials openfaas -z=${zone}
```

Create a cluster admin role binding:

```bash
kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"
```

Install Helm CLI with Homebrew:

```bash
brew install kubernetes-helm
```

Create a service account and a cluster role binding for Tiller:

```bash
kubectl -n kube-system create sa tiller
kubectl create clusterrolebinding tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller 
```

Deploy Tiller in the kube-system namespace:

```bash
helm init --skip-refresh --upgrade --service-account tiller
```

Heptio Contour is an ingress controller based on [Envoy](https://www.envoyproxy.io) reverse proxy that supports dynamic configuration updates. 
Install Contour with:

```bash
kubectl apply -f https://j.hept.io/contour-deployment-rbac
```

Find the Contour address with:

```bash
kubectl -n heptio-contour describe svc/contour | grep Ingress | awk '{ print $NF }'
```

Go to your DNS provider and create an `A` record for each OpenFaaS instance:

```bash
host openfaas.example.com
openfaas.example.com has address 35.197.248.216

host openfaas-stg.example.com
openfaas-stg.example.com has address 35.197.248.217
```

Install cert-manager with Helm:

```bash
helm install --name cert-manager \
    --namespace kube-system \
    stable/cert-manager
```

Create a cluster issuer definition (replace `email@example.com` with a valid email address):

{% gist fc8d7ef8f4af3d0d81a9f28ff8c6edcb letsencrypt-issuer.yaml %}

Save the above resource as `letsencrypt-issuer.yaml` and then apply it:

```bash
kubectl apply -f ./letsencrypt-issuer.yaml
```

## Network policies setup

![network-policies](/images/gke-multi-stage/network-policy.png)

An OpenFaaS instance is composed out of two namespaces: one for the core services and one for functions. 
Kubernetes namespaces alone offer only a logical separation between workloads. 
To enforce network segregation we need to apply access role labels to the namespaces and to create network policies.

Create the OpenFaaS *staging* and *production* namespaces with the *access role* labels:

{% gist fc8d7ef8f4af3d0d81a9f28ff8c6edcb openfaas-ns.yaml %}

Save the above resource as `openfaas-ns.yaml` and then apply it:

```bash
kubectl apply -f ./openfaas-ns.yaml
```

Allow ingress traffic from the `heptio-contour` namespace to both OpenFaaS environments:

```bash
kubectl label namespace heptio-contour access=openfaas-system
``` 

Create [network policies](https://gist.github.com/stefanprodan/fc8d7ef8f4af3d0d81a9f28ff8c6edcb#file-network-policies-yaml)
to isolate the OpenFaaS core services from the function namespaces:

```bash
kubectl apply -f https://gist.githubusercontent.com/stefanprodan/fc8d7ef8f4af3d0d81a9f28ff8c6edcb/raw/9ad1f60a5b6b5d474ac1551b39779824c32f3251/network-policies.yaml
```

Note that the above configuration will prohibit functions from calling each other or from reaching the
OpenFaaS core services.

## OpenFaaS staging setup

Generate a random password and create an OpenFaaS credentials secret:

```bash
stg_password=$(head -c 12 /dev/urandom | shasum | cut -d' ' -f1)

kubectl -n openfaas-stg create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password=$stg_password
```

Create the staging configuration (replace `example.com` with your own domain):

{% gist fc8d7ef8f4af3d0d81a9f28ff8c6edcb openfaas-stg.yaml %}

The OpenFaaS core services will be running on the default pool
because you've set the affinity constraint to `cloud.google.com/gke-nodepool=default-pool`.

Save the above file as `openfaas-stg.yaml` and install the OpenFaaS staging instance from the project helm repository:

```bash
helm repo add openfaas https://openfaas.github.io/faas-netes/

helm upgrade openfaas-stg --install openfaas/openfaas \
    --namespace openfaas-stg  \
    -f openfaas-stg.yaml
```

In a couple of seconds cert-manager should fetch a certificate from LE:

```bash
kubectl -n kube-system logs deployment/cert-manager
Certificate issued successfully
```

## OpenFaaS production setup

Generate a random password and create the `basic-auth` secret in the openfaas-prod namespace:

```bash
password=$(head -c 12 /dev/urandom | shasum | cut -d' ' -f1)

kubectl -n openfaas-prod create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password=$password
```

Create the production configuration (replace `example.com` with your own domain):

{% gist fc8d7ef8f4af3d0d81a9f28ff8c6edcb openfaas-prod.yaml %}

For the production deployment the OpenFaaS gateway has high-availability through two replicas. 
We make sure those replicas are scheduled on different nodes through the use of a pod anti-affinity rule.
Note that `operator.createCRD` is set to false since the `functions.openfaas.com` custom resource definition is already present on the cluster.

Save the above file as `openfaas-prod.yaml` and install the OpenFaaS production instance with helm:

```bash
helm upgrade openfaas-prod --install openfaas/openfaas \
    --namespace openfaas-prod  \
    -f openfaas-prod.yaml
```

## Manage your functions with kubectl

![openfaas-operator](/images/gke-multi-stage/operator.png)

Using the OpenFaaS CRD you can define functions as Kubernetes custom resources.

Create `certinfo.yaml` with the following content:

{% gist fc8d7ef8f4af3d0d81a9f28ff8c6edcb certinfo.yaml %}

In oder to make use of the preemptible node pool you need to 
set the affinity constraint to `cloud.google.com/gke-preemptible=true` so that certinfo will be deployed on the `fn-pool`.

Use `kubectl` to deploy the function to both environments by changing the namespace parameter:

```bash
kubectl -n openfaas-stg-fn apply -f certinfo.yaml
kubectl -n openfaas-prod-fn apply -f certinfo.yaml
```

The certinfo function will tell you the SSL information for your domain. 
User certinfo to verify both endpoints are live:

```bash
curl -d "openfaas-stg.example.com" https://openfaas-stg.example.com/function/certinfo
Issuer Let's Encrypt Authority X3
....
curl -d "openfaas.example.com" https://openfaas.example.com/function/certinfo
Issuer Let's Encrypt Authority X3
....
```

You can get the list of functions running in a namespace:

```bash
kubectl -n openfaas-stg-fn get functions
```

And you can delete a function from an namespace with:

```bash
kubectl -n openfaas-stg-fn delete function certinfo
```

## Developer workflow

When it comes to the development workflow you will be using OpenfaaS CLI.

Install faas-cli and login to the staging instance with:

```bash
curl -sL https://cli.openfaas.com | sudo sh

echo $stg_password | faas-cli login -u admin --password-stdin \
 -g https://openfaas-stg.example.com
```

Using faas-cli, Git and kubectl a development workflow would look like this:

_1._ Create a function using the Go template 

```bash
faas-cli new myfn --lang go --prefix gcr.io/gcp-project-id
```

_2._ Implement your function logic by editing the `myfn/handler.go` file

_3._ Build the function as a Docker image 

```bash
faas-cli build -f myfn.yml
```

_4._ Test the function on your local cluster (click [here](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md) if you haven’t set up your local environment yet)

```bash
faas-cli deploy -f myfn.yml -g 127.0.0.1:31112
```

_5._ Initialize a Git repository for your function and commit your changes

```bash
git init
git add . && git commit -s -m "Initial function version"
```

_6._ Rebuild the image by tagging it with the Git commit short SHA

```bash
faas-cli build --tag sha -f myfn.yml
```

_7._ Push the image to GCP Container Registry

```bash
faas-cli push --tag sha -f myfn.yml
```

_8._ Generate the function Kubernetes custom resource

```bash
faas-cli generate -n "" --tag sha --yaml myfn.yml > myfn-k8s.yaml
```

_9._ Add the preemptible constraint to `myfn-k8s.yaml`

```yaml
  constraints:
    - "cloud.google.com/gke-preemptible=true"
```

_10._ Deploy it on the staging environment

```bash
kubectl -n openfaas-stg-fn apply -f myfn-k8s.yaml
```

_11._ Test the function on staging, if everything looks good go to next step, if not go back to step 2

```bash
cat test.json | faas-cli invoke myfn -g https://openfaas-stg.exmaple.com
```

_12._ Promote the function to production

```bash
kubectl -n openfaas-prod-fn apply -f myfn-k8s.yaml
```

In a future post I will show how you can monitor your functions with Prometheus and Grafana and how to take that forward with a managed solution like [Weave Cloud](https://www.weave.works).

Do you have questions, comments or suggestions? Tweet to [@openfaas](https://twitter.com/openfaas).

> Want to support our work? You can become a sponsor as an individual or a business via GitHub Sponsors with tiers to suit every budget and benefits for you in return. [Check out our GitHub Sponsors Page](https://github.com/sponsors/openfaas/)
