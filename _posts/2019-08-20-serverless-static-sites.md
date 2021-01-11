---
title: "Bringing Serverless to a Web Page Near you with Hugo & Kubernetes"
description: Learn how you can migrate your Hugo static sites over to OpenFaaS including custom domains, TLS and CI/CD through OpenFaaS Cloud (or GitLab).
date: 2019-08-20
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

Learn how you can migrate your Hugo static sites over to OpenFaaS including custom domains, TLS and CI/CD through OpenFaaS Cloud (or GitLab).

[OpenFaaS](https://github.com/openfaas/faas) is one of the most popular open-source platforms on the [CNCF Landscape](https://landscape.cncf.io/category=installable-platform&format=card-mode&grouping=category&sort=stars) for building and deploying functions and microservices on Kubernetes. It's likely that you are used to seeing OpenFaaS used only to deploy functions, but in this post we want to show you what is possible through the project's templating system.

Each programming language has its own custom-built template, which contains an entrypoint, a Dockerfile, and a sample handler to edit. Users can create their own templates with OpenFaaS in a very short period of time and in this tutorial I will show the one I created for [Hugo](https://gohugo.io), a popular static site generator.

A note from [Alex Ellis, OpenFaaS Founder](https://www.openfaas.com/team/):

> Now many people may associate "Serverless" only with SaaS products and cloud functions, but major players in the computing industry such as IBM, Red Hat, Pivotal and Google are all making an investment in Serverless 2.0. Serverless 2.0 is portable between any cloud or computer and is not subject to the limitations of SaaS products. Some users may perfectly happy with being locked into a single vendor and whatever the boundaries are, but for everyone else there's a new world. Find out more in my [Serverless Beyond the Hype video](https://www.youtube.com/watch?v=yOpYYYRuDQ0).

> This tutorial is for users who may want to deploy any number of workloads including: microservices, blogs, functions, batch jobs, legacy HTTP servers, and static sites.

> The goal of this tutorial *is not to show you that you need a Kubernetes cluster to run a static website*, it's to show what can be done with OpenFaaS and Kubernetes. You can set up a managed Kubernetes service for as little as 15 USD / mo and after following this tutorial, it will have very little administrative overhead. I'd also recommend you read the tutorial on how to build a complete [Serverless Single Page App](https://www.openfaas.com/blog/serverless-single-page-app/) to understand more behind the workflow and developer experience.

## Pre-reqs

* Kubernetes

You need to have a Kubernetes cluster up & running. I would recommend [DigitalOcean](https://www.digitalocean.com/), it's cost-efficient and very easy to set-up. [Get free credits](https://m.do.co/c/2962aa9e56a1).

* [Install Helm](https://github.com/openfaas/faas-netes/blob/master/HELM.md)

You'll need helm to install the components in the cluster. If you can't install `Tiller`, helm's server-side component, in your cluster then you can use `helm template`.

* [Install OpenFaaS using Helm](https://github.com/openfaas/faas-netes/blob/master/chart/openfaas/README.md#install)

For this tutorial we will configure OpenFaaS to use a Kubernetes IngressController. Traffic will reach the OpenFaaS gateway through the IngressController, instead of through a network LoadBalancer.

Set `ingress.enabled=true` and `exposeServices=false` when installing with helm:

```sh
helm repo update

helm upgrade openfaas --install openfaas/openfaas \
    --namespace openfaas  \
    --set basic_auth=true \
    --set functionNamespace=openfaas-fn \
    --set ingress.enabled=true \
    --set exposeServices=false
```

If you already have OpenFaaS installed, then you can run the command again to upgrade to the latest versions.

* Install an IngressController

The new [IngressOperator](https://github.com/openfaas-incubator/ingress-operator) will create TLS records and Ingress entries for our new sites. This means that users can reach our endpoints through a custom domain.

The IngressOperator supports the followin options: [Nginx](https://github.com/kubernetes/ingress-nginx), [Traefik](https://docs.traefik.io/user-guide/kubernetes/) and Zalando's [Skipper](https://opensource.zalando.com/skipper/kubernetes/ingress-controller/).

I will be using Nginx for today's tutorial:

```sh
helm install stable/nginx-ingress --name nginxingress --set rbac.create=true
```

* [Install the cert-manager](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#10-ssl-for-the-gateway) (optional)

Installing the cert-manager to get automatic TLS certificates is optional but I highly recommend it. I will be using it today.

* [Install the Hugo CLI](https://gohugo.io/getting-started/installing)

You'll need to install the Hugo CLI. Use it to create a static site and to serve it locally for development and test.

* DNS management

You'll need to create an A record to serve your static site. I'm using [DigitalOcean](https://digitalocean.com) which offers free domain management at time of writing.

The easiest way to create DNS records is with the DigitalOcean CLI: [install doctl](https://github.com/digitalocean/doctl#installing-doctl).

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

Templates in OpenFaaS are like a scaffold for an application, they lay down some common components which you don't have to think about. It means that you can save hundreds of lines of repetitive boiler-late coding and YAML.

Templates can then be shared through the [The Template Store](https://www.openfaas.com/blog/template-store/).

Let's take a look at my template for Hugo static sites called [openfaas-hugo-template](https://github.com/matipan/openfaas-hugo-template). This template copies the contents of your Hugo site, builds it into the `public` directory and then uses the OpenFaaS of-watchdog to serve the content. It also provides metrics and a health check for Kubernetes that follows the [OpenFaaS runtime contract](https://docs.openfaas.com/architecture/production/#workload-or-function-guidelines).

## Create a new Hugo site

Create a new Hugo site using `faas-cli` (or its alias `faas`):

```sh
# Create a new folder
mkdir -p my-blog/
cd my-blog

# Initialize a git repo
git init

# Pull in my †emplate using its URL
faas template pull https://github.com/matipan/openfaas-hugo-template

# Get an account at https://hub.docker.com
export DOCKER_HUB_USER="your-hub-account"

# Now create a Hugo site called `example-site`
faas new --lang hugo example-site --prefix ${DOCKER_HUB_USER}
```

This will create a folder called `example-site` where we will place the content for the site along with its configuration and any themes we may want.

The `example-site.yml` file is called a *stack file* and can be used to configure the deployment on OpenFaaS.

The following steps are based upon the [Hugo quick-start guide](https://gohugo.io/getting-started/quick-start/#step-2-create-a-new-site):

```sh
cd example-site

# Create a new site
hugo new site .

# Add a custom theme

git submodule add https://github.com/budparr/gohugo-theme-ananke.git themes/ananke

# Append the theme to the config file
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

Edit to `config.toml` and set the `baseURL` to the custom DNS domain that you will be using.

Now deploy your site:

```sh
export OPENFAAS_URL="" # Set when installing OpenFaaS

faas-cli up -f example-site.yml
```

## Create the DNS A record for your sub-domain

I'm using my personal domain `matiaspan.dev` that I registered at [namecheap.com](https://namecheap.com). I can now create sub-domains for each function or website I deploy with OpenFaaS.

If you are familiar with DNS, then create an A record for the IP address of the LoadBalancer created for your Nginx IngressController:

Find its `EXTERNAL-IP`:

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

Now it's time to map our Hugo blog to the custom domain above. We can do that with a `FunctionIngress` record, just like Alex showed in his [previous blog post](https://www.openfaas.com/blog/custom-domains-function-ingress/). 

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

After creating the `FunctionIngress` our IngressOperator will detect the recently created CRD and create a Kubernetes Ingress record. If you are using TLS this ingress will be decorated with annotations that the cert-manager then detects and creates the TLS certificate for your site.

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

If you modify or delete the `FunctionIngress` then the certificate and the Ingress record will be updated too.

Navigate to your domain and check out your new site:

![Example website deployed at my-site.matiaspan.dev](/images/2019-serverless-static-sites/hugo-example-site.png)

You can now repeat the above for any other static-sites, microservices, functions, or endpoints that you want to deploy.

## CI/CD (optional)

* Continuous Integration - the act of building whatever is pushed into our Git repositories, continuously to become aware of any integration problems or regression in tests. This results in artifacts such as Docker images.
* Continuous Delivery - the process of deploying new artifacts to production as soon as they become available.

Some tools combine both CI/CD into one pipeline. The classic example is [Heroku](https://heroku.com) which enables a "git-based" workflow, or "GitOps". A more modern alternative is [Netlify](https://netlify.com), which is very popular with those hosting static sites such as their documentation or blogs.

I'm going to go over two different ways you can get this same experience using OpenFaaS Cloud or OpenFaaS combined with GitLab.

### CI/CD with OpenFaaS Cloud

[OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) offers you an integrated and automated experience, with a single push you can have your site deployed in seconds. You'll also get logs and metrics linked directly to your commit.

If this sounds interesting to you check out the "one-click" [bootstrap tool](https://github.com/openfaas/ofc-bootstrap) to install OpenFaaS Cloud in less than 100 seconds or apply for an account on [The Community Cluster](https://github.com/openfaas/community-cluster) for free shared access.

In OpenFaaS Cloud by default we limit the templates that the users can use. This means we need to add the Hugo template before being able to deploy a function. To do this, edit the `git-tar` deployment in the `openfaas-fn` namespace and add the Hugo template URL `https://github.com/matipan/openfaas-hugo-template` to the `custom_templates` environment variable.

Create a repository on GitHub (or your self hosted GitLab) called `example-site`. Add this repository to your GitHub app or add the `openfaas-cloud` tag if you are using GitLab.  
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

Try creating a new blog post with:

```bash
hugo new posts/my-first-post.md
```

Remember to run that command inside the folder of your Hugo site, not the root folder of the project.  

Commit and push your changes again, after OpenFaaS Cloud does its thing you will be able to see your new changes deployed.

### CI/CD with GitLab.com

There are two ways to operate GitLab, the first involves installing and hosting it yourself and then you can run as many builds as you have capacity for. The second option is to use GitLab.com, the hosted SaaS product which is similar to GitHub.com.

GitLab.com offers 2000 hours per month to use for free automated builds. We can take advantage of the [Shared Runners](https://docs.gitlab.com/ce/ci/quick_start/#shared-runners) to build Docker images for OpenFaaS.

Save the following content [from OpenFaaS's official documentation](https://docs.openfaas.com/reference/cicd/gitlab/) to a YAML file in the root folder of the repository `.gitlab-ci.yml`:

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

Using a mixture of the new Hugo template, the [IngressOperator](https://github.com/openfaas-incubator/ingress-operator) and either [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud), or GitLab we were able to host a static site with TLS and CI/CD in a very short period of time. You can use this to host any static site such as documentation, blog posts, and landing pages for websites.

I chose Hugo for today's blog post but you could create another template using your favourite tooling. When we were chatting about this blog post in the OpenFaaS Slack Community, someone suggested writing a template for [GatsbyJS](https://www.gatsbyjs.org). We would love to see that happen, and if you want to have a go, you can just fork my [Hugo template](https://github.com/matipan/openfaas-hugo-template) and update it.

Did you know that you can run any Docker image on OpenFaaS as long as it follows the [workload contract](https://docs.openfaas.com/architecture/production/#workload-or-function-guidelines)? This makes OpenFaaS one of the easiest ways to run any containerised workload on Kubernetes.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Do you want to deploy any of the following to Kubernetes?<br><br>💻 Static webpages<br>💻 Microservices<br>💻 Blogs - Ghost/Wordpress<br>💻 CLIs<br>💻 Functions<br><br>Get productive as quick as possible with <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@OpenFaaS</a> on your own laptop or your favourite Kubernetes engine. <a href="https://t.co/bcD7493eUD">https://t.co/bcD7493eUD</a> <a href="https://t.co/2zZSeYRFbS">pic.twitter.com/2zZSeYRFbS</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/1162414762652835841?ref_src=twsrc%5Etfw">August 16, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

### Connect with us

Connect with us to discuss this blog post, or to share what you're building with OpenFaaS.

* Join OpenFaaS [Slack community](https://docs.openfaas.com/community)
* Follow @OpenFaaS on [Twitter](https://twitter.com/openfaas)

### You may also like

* [How to build a Serverless Single Page App](https://www.openfaas.com/blog/serverless-single-page-app/)
* [OpenFaaS Insiders](https://github.com/openfaas/faas/blob/master/BACKERS.md) - become an OpenFaaS Insider to get regular updates on new features, early access, tips and hints directly from the OpenFaaS Founder
* [k3sup ("ketchup")](https://github.com/alexellis/k3sup) - the fastest way to create local, remote, or edge clusters with Kubernetes.
