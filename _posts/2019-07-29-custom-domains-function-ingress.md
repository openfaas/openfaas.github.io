---
title: "Grab Custom Domains for your Functions with FunctionIngress"
description: With OpenFaaS, you get a URL for every function by convention which is great and suits many people. This guide shows you have to get a Custom Domain for your functions using the new FunctionIngress concept.
date: 2019-07-29
image: /images/2019-custom-domains-function-ingress/1.jpg
categories:
  - community
  - end-user
  - ingress
  - production
  - kubernetes
author_staff_member: alex
dark_background: true
---

Find out how you can expand beyond the default URL given to each function with FunctionIngress.

In this tutorial I'll show you how to use the new FunctionIngress CRD along with a new Kubernetes Operator to get Custom Domains for any OpenFaaS function deployed on Kubernetes.

## Tutorial

### How it works

First of all, we install the new Kubernetes Operator called "IngressOperator". This Operator is responsible for translating CRD entries called FunctionIngress into two separate resources in the cluster: an `Ingress` definition and a TLS Certficate. The TLS certificate is optional, but highly recommended.

### Pre-reqs

* Kubernetes

You need to have a Kubernetes cluster. I recommend using [DigitalOcean Kubernetes](https://www.digitalocean.com/) for an easy and cost-efficient set-up.

* helm

You'll need helm for most of the components we are using. If you are allergic to helm's server-side component called "tiller", then don't worry. You can simply use the "helm template" command to generate plain YAML files.

[Install helm](https://github.com/openfaas/faas-netes/blob/master/HELM.md)

* OpenFaaS via helm

[Install OpenFaaS via helm](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md#install)

You should also install the OpenFaaS CLI using the instructions at [docs.openfaas.com](https://docs.openfaas.com/)

* Nginx IngressController

Traefik and Skipper are also supported, but we'll use Nginx for this tutorial. Install Nginx with the following:

```
helm install stable/nginx-ingress --name nginxingress --set rbac.create=true
```

* cert-manager (optional)

Using TLS is optional, but highly recommended, so I will show you how to set it up.

Use the [1.0 SSL for Kubernetes](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#10-ssl-for-the-gateway) documentation to set up cert-manager and an issuer. You can skip the steps for creating a `Certificate` and `Ingress` entry for the gateway.

### Deploy `IngressOperator`

We'll now deploy the IngressOperator. I'll be [following instructions from the OpenFaaS documentation](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#20-ssl-and-custom-domains-for-functions).

```sh
git clone https://github.com/openfaas-incubator/ingress-operator
cd ingress-operator

kubectl apply -f ./artifacts/operator-crd.yaml
kubectl apply -f ./artifacts/operator-rbac.yaml
kubectl apply -f ./artifacts/operator-amd64.yaml
```

The above creates the CRD definition, RBAC roles and then deploys the Operator itself.

### Create a static website

We can use the Nginx static website template to create a function or microservice. Once deployed, we'll move on to creating its custom domain name entry and then a CRD entry for it.

```sh
export OPENFAAS_PREFIX=alexellis2

faas template pull https://github.com/alexellis/static-site-template
faas new --lang static-site-nginx my-homepage --prefix ${OPENFAAS_PREFIX}
```

Set `OPENFAAS_PREFIX` with your own Docker Hub username, or private registry address and repo.

Create the homepage:

```sh
echo "<html>Hello world</html>" > ./my-homepage/index.html
```

The following will build a container image, push it to the remote registry and then deploy it to OpenFaaS, resulting in a static-website.

```sh
faas-cli up -f my-homepage.yml
```

Your traditional URL will appear on:

```sh
faas-cli describe -f my-homepage.yml my-homepage

Name:                my-homepage
Status:              Ready
Replicas:            1
Available replicas:  0
Invocations:         0
Image:               alexellis2/my-homepage:latest
Function process:    
URL:                 http://206.189.242.89:8080/function/my-homepage
Async URL:           http://206.189.242.89:8080/async-function/my-homepage
Labels:              faas_function : my-homepage
```

We'll now create a DNS entry and then the custom hostname mapping and TLS certificate along with that.

### Create a DNS A record for your sub-domain

My testing domain is `myfaas.club` and it cost me a very minimal amount of money from [namecheap.com](https://namecheap.com/). I can create sub-domains for each function, or for any testing that I do. If you are familiar with DNS-management, then create an A record for the IP address the LoadBalancer created by Nginx.

```
kubectl get svc -n default

kubectl get svc
NAME                                         TYPE           CLUSTER-IP      EXTERNAL-IP       PORT(S)                      AGE
nginxingress-nginx-ingress-controller        LoadBalancer   10.245.169.18   178.128.137.209   80:32126/TCP,443:30028/TCP   32d
```

You can see my external IP listed as `178.128.137.209`.

As a DigitalOcean customer, I can now use the DigitalOcean UI or CLI to create a DNS A record for `178.128.137.209`. Here is an example using the `doctl` CLI:

```sh
doctl compute domain create my-homepage.myfaas.club --ip-address 178.128.137.209

Domain                     TTL
my-homepage.myfaas.club    0
```

### Map the Custom Domain with a `FunctionIngress`

Now we will map the Custom Domain to the function using a `FunctionIngress` definition.

Save the following in a YAML file and then apply with `kubectl apply -f my-homepage-fni.yaml`

```yaml
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: my-homepage-tls
  namespace: openfaas
spec:
  domain: "my-homepage.myfaas.club"
  function: "my-homepage"
  ingressType: "nginx"
  tls:
    enabled: true
    issuerRef:
      name: "letsencrypt-prod"
      kind: "Issuer"
```

I've called my FunctionIngress record `my-homepage-tls`.

Edit the `domain` to point as your own DNS A record or sub-domain

For the `issuerRef`, you can use the `-staging` or `-prod` issuer which you set up earlier using the OpenFaaS docs.

### Check what happened

We already have a URL to access our static website, but after having created the `FunctionIngress`, we'll get a HTTPS URL too.

This is what happens:

* The CRD is detected and an Ingress record is created
* The Ingress record is decorated with information about TLS
* CertManager detects the TLS information using something called IngressShim
* CertManager creates the TLS certificate

Check the ingress:

```sh
kubectl get ingress -n openfaas

NAME              HOSTS                      ADDRESS        PORTS     AGE
my-homepage-tls   my-homepage.myfaas.club    167.71.8.102   80, 443   46s
```

Now check the certificate:

```sh
kubectl get cert -n openfaas

NAME                          READY   SECRET                               AGE
my-homepage-tls-certificate   true    my-homepage-tls-certificate-secret   2m37s
```

Note, if it appears as "Not Ready" for a long time, you can debug it with: `kubectl describe cert/my-homepage-tls-certificate -n openfaas`

The objects above were created automatically, so they will be deleted or edited if you delete or edit the `FunctionIngress` custom resource.

You can find out what happened inside the Operator by checking its logs:

```sh
kubectl logs -n openfaas deploy/ingress-operator
```

### Try out your brand new Custom Domain

Congratulations! You can now create Custom Domains for any of your functions or microservices deployed with OpenFaaS, and add TLS too.

![](/images/2019-custom-domains-function-ingress/preview.png)

You can also drill-down into your certificate to check that it's valid and when it will expire. Fortunately cert-manager will automatically renew the certificate for you on a regular basis.

![](/images/2019-custom-domains-function-ingress/view-cert.png)

## Connect & Learn

I hope you enjoyed the tutorial. If you have any comments, questions or suggestions, then please connect with me and the OpenFaaS community on Slack:

* [OpenFaaS Slack](https://slack.openfaas.io)

You can follow [@alexellisuk](https://twitter.com/alexellis) on Twitter for more blogs, videos, tips and tutorials

If you'd like a more automated experience than offered through the blog today, then why not check out [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud)?

OpenFaaS Cloud offers:

* hosting for your functions and microservices
* free sub-domains and TLS certificates
* deep integration with public and private repos on GitHub.com and GitLab
* a personalized dashboard and login with OAuth2 to view your metrics and functions

You can [self-host in 100 seconds](https://www.youtube.com/watch?v=Sa1VBSfVpK0) or apply for access to the [Community Cluster](https://github.com/openfaas/community-cluster).
