---
title: "Bringing Serverless to a Web Page Near you with Hugo & Kubernetes"
description: With the extensibility of OpenFaaS's templating system we can create new templates in no time. Today we'll show how to continuously deploy static sites using a new template for Hugo and the FunctionIngress CRD for custom domain names.
date: 2019-08-06
image: /images/2019-serverless-static-sites/background.jpg
categories:
  - community
  - end-user
  - ingress
  - kubernetes
  - Hugo
author_staff_member: matias
dark_background: true
---

Learn how you can continuously deploy static sites with Hugo, OpenFaaS Cloud (or GitLab) and the FunctionIngress CRD.

## Pre-reqs
* Kubernetes

You need to have a Kubernetes cluster up & running. I would recommend [DigitalOcean](https://www.digitalocean.com/), it's cost-efficient and very easy to set-up.

[Get free credits](https://m.do.co/c/2962aa9e56a1).

* [Install Helm](https://github.com/openfaas/faas-netes/blob/master/HELM.md)

You'll need helm to install the components in the cluster. If you can't install `Tiller`, helm's server-side component, in your cluster then you can use `helm template`.

* [Install OpenFaaS using Helm](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md#install)

For this tutorial you will need to install OpenFaaS using an ingress controller instead of exposing the gateway with a LoadBalancer. For this you'll need to set `ingress.enabled=true` and `exposeServices=false` when installing it:
```sh
helm repo update \
 && helm upgrade openfaas --install openfaas/openfaas \
    --namespace openfaas  \
    --set basic_auth=true \
    --set functionNamespace=openfaas-fn \
    --set ingress.enabled=true \
    --set exposeServices=false
```

* Install an Ingress Controller

We will be using the new IngressOperator component which has support for the following IngressControllers: [Nginx](https://github.com/kubernetes/ingress-nginx), [Traefik](https://docs.traefik.io/user-guide/kubernetes/) and Zalando's [Skipper](https://opensource.zalando.com/skipper/kubernetes/ingress-controller/). I will be using Nginx for today's tutorial:
```sh
helm install stable/nginx-ingress --name nginxingress --set rbac.create=true
```

* [Install the cert-manager](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#10-ssl-for-the-gateway) (optional)

Installing the cert-manager to get automatic TLS certificates is optional but I highly recommend it. I will be using it today.

* [Install the Hugo CLI](https://gohugo.io/getting-started/installing)

You'll need the Hugo CLI to create a static site and serve it locally.

* DNS management

You'll need to create an A record to serve your static site. I'm using [DigitalOcean](https://digitalocean.com) that offers this for free, if you'd like to use it then [install their command lite tool](https://github.com/digitalocean/doctl#installing-doctl).

## Install the IngressOperator
The IngressOperator automatically manages the creation of custom ingress rules and TLS certificates for your functions using a new CRD called `FunctionIngress` introduced by Alex in the [previous blog post](https://www.openfaas.com/blog/custom-domains-function-ingress/).  
Lets deploy the operator to our cluster following the instructions at [the documentation](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#20-ssl-and-custom-domains-for-functions):
```sh
git clone https://github.com/openfaas-incubator/ingress-operator
cd ingress-operator

kubectl apply -f ./artifacts/operator-crd.yaml
kubectl apply -f ./artifacts/operator-rbac.yaml
kubectl apply -f ./artifacts/operator-amd64.yaml
```

## Meet the Hugo template
[OpenFaaS's templates](https://www.openfaas.com/blog/template-store/) are no more than Dockerfiles that specify the entire process of building and serving your application. Today I'm showing you a new template for creating [Hugo](https://gohugo.io) static sites called [openfaas-hugo-template](https://github.com/matipan/openfaas-hugo-template).  
This template copies the contents of your Hugo site, builds it into the `public` directory and then uses a [very lightweight static server](https://gitlab.com/matipan/static-server) that serves the content and provides a health check that follows the standards from OpenFaaS.

## Create a new Hugo site
We can use the Hugo template to create Hugo sites and then serve them with custom domain names using OpenFaaS and the IngressOperator. First lets create the site:
```sh
git init
faas template pull https://github.com/matipan/openfaas-hugo-template
faas new --lang hugo -g <openfaas gateway url> --prefix <docker hub username> example-site
```
This will create a folder called `example-site`, `cd` into it and now create the site with this instructions from the [Hugo quick-start guide](https://gohugo.io/getting-started/quick-start/#step-2-create-a-new-site):
```sh
hugo new site .
git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke
echo 'theme = "ananke"' >> config.toml
```
When you are developing new content you'll probably want to see what it looks like before deploying it. To do this, you can use the `hugo server` command inside the function's directory:
```
hugo server
Watching for changes in /home/capitan/src/gitlab.com/matipan/openfaas-hugo-blog/blog/{archetypes,content,static}
Watching for config changes in /home/capitan/src/gitlab.com/matipan/openfaas-hugo-blog/blog/config.toml
Environment: "development"
Serving pages from memory
Running in Fast Render Mode. For full rebuilds on change: hugo server --disableFastRender
Web Server is available at http://localhost:1313/ (bind address 127.0.0.1)
Press Ctrl+C to stop
```
Now go to http://localhost:1313 and check out what your site looks like.

Remember to update the `baseURL` found at `config.toml` to the domain that you will be using. Now deploy your site:
```sh
faas-cli up -f example-site.yml
```

## Create a DNS A record for your sub-domain
I'm using my personal domain `matiaspan.dev` that I got at [namecheap.com](https://namecheap.com). I can create sub-domains for each function. If you are familiar with DNS, then create an A record for the IP address of the LoadBalancer created for the ingress controller (i.e nginx):
```sh
kubectl get svc -n default
NAME                                         TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)                      AGE
nginxingress-nginx-ingress-controller        LoadBalancer   10.245.116.147   159.89.221.240   80:31113/TCP,443:30596/TCP   2d21h
```

You can see that my external IP address is: `159.89.221.240`.  
If you are getting started with DNS management I recommend [DigitalOcean](https://digitalocean.com) which is free and easy to use. Here is how I use the CLI to create the record for `my-site.matiaspan.dev`:
```sh
doctl compute domain create my-site.matiaspan.dev --ip-address 159.89.221.240

Domain                     TTL
my-site.matiaspan.dev      0
```
And this is how the UI looks like:

![DigitalOcean control panel for DNS management](/images/2019-serverless-static-sites/digital-ocean-dns-management-panel.png)

## Map the custom domain with a FunctionIngress
Now it's time to map the custom domain with a `FunctionIngress`, just like Alex showed in the [previous blog post](https://www.openfaas.com/blog/custom-domains-function-ingress/). 

Save the following in a YAML file `example-site-fni.yml`:
```yaml
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: example-site-tls
  namespace: openfaas
spec:
  domain: "my-site.matiaspan.dev"
  function: "example-site"
  ingressType: "nginx"
  tls:
    enabled: true
    issuerRef:
      name: "letsencrypt-prod"
      kind: "Issuer"
```

* For the `name` I used a convention of the function’s name plus a suffix of -tls if using TLS.
* Edit the `domain` to point as your own DNS A record or sub-domain
* For the `issuerRef`, you can use the `-staging` or `-prod` issuer which you set up earlier using the OpenFaaS docs. If you are not using TLS then remove the `tls` section from the file.

Now apply the file with `kubectl apply -f example-site-fni.yml`

## Check out your brand new site!
After creating the `FunctionIngress` our IngressOperator will detect the recently created CRD and create an ingress record. If you are using TLS this ingress will be decorated with annotations that the CertManager then detects and creates the TLS certificate for your site.

Check the ingress record:
```sh
kubectl get ingress -n openfaas
NAME                  HOSTS                   ADDRESS          PORTS     AGE
example-site-tls      my-site.matiaspan.dev   165.22.164.208   80, 443   56s
```
Now the certificate:
```sh
kubectl get cert -n openfaas
NAME                    READY   SECRET                  AGE
example-site-tls-cert   True    example-site-tls-cert   89s
```
If you modify or delete the `FunctionIngress` then the certificate and the ingress will also be affected.

Navigate to your domain and check out your new site!

![Example website deployed at my-site.matiaspan.dev](/images/2019-serverless-static-sites/hugo-example-site.png)

## CI/CD
There are great tools available like [Netlify](https://netlify.com) and [Heroku](https://heroku.com) that allows us to have a completely automated experience. With a single push you get the new content of your site automatically deployed.  
I'm going to go over two different ways you can get this same experience using OpenFaaS Cloud or GitLab.

### CI/CD with OpenFaaS Cloud
[OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) can offer you an automated experience, with a single push you can have your site deployed in no time!  
If this sounds interesting to you check out our "single click" [bootstrap tool](https://github.com/openfaas-incubator/ofc-bootstrap) to install OpenFaaS Cloud in less than 100 seconds or apply for access to the [Community Cluster](https://github.com/openfaas/community-cluster).

In OpenFaaS Cloud by default we limit the templates that the users can use. This means we need to add the Hugo template before being able to deploy a function. To do this, edit the `git-tar` deployment in the `openfaas-fn` namespace and add the Hugo template URL `https://github.com/matipan/openfaas-hugo-template` to the `custom_templates` environment variable.

Create a repository on GitHub(or your self hosted GitLab) called `example-site`. Add this repository to your GitHub app or add the `openfaas-cloud` tag if you are using GitLab.  
Since we don't do recursive clones in OpenFaaS Cloud you will need to clone your site's theme instead of adding it as a submodule. Once you've done that commit and push your changes.  
After a while, if you head over to your personal dashboard(find it at `system.<your domain>/dashboard/<username>`) you will see your new function deployed.  
Edit the `FunctionIngress` so that it points to our brand new function `kubectl edit -n openfaas functioningresses.openfaas.com example-site`:
```yaml
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: example-site-tls
  namespace: openfaas
spec:
  domain: "my-site.matiaspan.dev"
  function: "<username>-example-site"
  ingressType: "nginx"
  tls:
    enabled: true
    issuerRef:
      name: "letsencrypt-prod"
      kind: "Issuer"
```
* You need to update the `function` to match with the new one. OpenFaaS Cloud deploys function using the following convention: `<username>-<function name>`. If you are unsure about the name you can find it with `faas-cli list`.

We won't be using our previous function anymore so remove it:
```sh
faas-cli remove example-site
```

Try creating a new blog post with: `Hugo new posts/my-first-post.md`. Remember to run that command inside the folder of your Hugo site, not the root folder of the project.  
Commit and push your changes again, after OpenFaaS Cloud does its thing you will be able to see your new changes deployed.

### CI/CD with GitLab
GitLab offers 2000 hours/month for free in their CI/CD offerings. We can take advantage of the [Shared Runners](https://docs.gitlab.com/ce/ci/quick_start/#shared-runners) that allow us to build docker images. Save the following content [from OpenFaaS's official documentation](https://docs.openfaas.com/reference/cicd/gitlab/) to a YAML file in the root folder of the repository `.gitlab-ci.yml`:
```yaml
image: docker:stable

stages:
  - build

services:
   - docker:dind

before_script:
  - apk add --no-cache git
  - if [ -f "./faas-cli" ] ; then cp ./faas-cli /usr/local/bin/faas-cli || 0 ; fi
  - if [ ! -f "/usr/local/bin/faas-cli" ] ; then apk add --no-cache curl git && curl -sSL cli.openfaas.com | sh && chmod +x /usr/local/bin/faas-cli && /usr/local/bin/faas-cli template pull && cp /usr/local/bin/faas-cli ./faas-cli ; fi

build:
  stage: build
  script:
    - git submodule init && git submodule update
    # Build Docker image
    - /usr/local/bin/faas-cli template pull https://github.com/matipan/openfaas-hugo-template
    - /usr/local/bin/faas-cli build --tag=sha -f example-site.yml

    # Login & Push Docker image to private repo
    - echo -n "$CI_DOCKER_LOGIN" |  docker login --username $(echo -n "$CI_DOCKER_USERNAME") --password-stdin
    - /usr/local/bin/faas-cli push --tag=sha -f example-site.yml
    - echo -n "$CI_OF_PWD" | /usr/local/bin/faas-cli login --gateway $(echo -n "$CI_OF_GATEWAY") --username admin --password-stdin

    # Deploy function from private repo
    - /usr/local/bin/faas-cli deploy --tag=sha -f example-site.yml
  only:
    - master
```
Go to your project's CI/CD page and set the following variables:

* `CI_DOCKER_LOGIN`: the password for docker hub
* `CI_DOCKER_USERNAME`: your docker username
* `CI_OF_PWD`: the password for your OpenFaaS gateway
* `CI_OF_GATEWAY`: the URL for your OpenFaaS gateway

Commit and push your changes and see how your function gets automatically built and deployed!

## Wrapping up
The Hugo template we showed today combined with the IngressOperator and OpenFaaS Cloud(or GitLab CI/CD) allowed us to create a great way to build and host sites for your project's documentation, personal blogs and more.  
I chose Hugo for today's blog post but you can create another template for your favorite tool. Check out this [static server](https://gitlab.com/matipan/static-server) for an easy way to serve the content built by your static site tool.

Connect with us to discuss further or to share what you’ve built.

* Join OpenFaaS [Slack community](https://docs.openfaas.com/community)
* Follow @OpenFaaS on [Twitter](https://twitter.com/openfaas).