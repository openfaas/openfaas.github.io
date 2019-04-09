---
title: "Run your OpenFaaS Functions on Google Cloud Run for free"
description: Yesterday Google announced a new serverless SaaS product named Cloud Run, learn how to deploy your OpenFaaS Functions without modifications in the free tier
date: 2019-04-09
image: /images/openfaas-cloudrun/cupping.jpg
categories:
  - cloud
  - kubernetes
  - cicd
  - gitops
author_staff_member: alex
dark_background: true
---

In this post I'll introduce Google's new Cloud Run product which like OpenFaaS allows any HTTP Server packaged in a Docker or OCI image format to be deployed and scaled.

## Serverless 2.0 - it's about containers

In my conference talk at [goto Copenhagen](https://www.youtube.com/watch?v=yOpYYYRuDQ0) last fall I coined the term *Serverless 2.0*. Serverless 2.0 builds upon the learnings of the first-generation of proprietary SaaS products from major cloud vendors by using containers for portability and to avoid lock-in. Your deployments for Serverless and the rest of your applications no-longer have to be orthogonal managed by two sets of tools. This approach has been core to the OpenFaaS community from day 1.

Yesterday we saw Google [launch a new product](https://news.ycombinator.com/item?id=19610830) named [Cloud Run](https://cloud.google.com/run/docs/). This is a proprietary serverless add-on for Google Cloud Platform (GCP) built around their flagship [Istio](https://istio.io) and [Knative](https://cloud.google.com/knative/) projects.

> What does that mean for you and me?

It means that we can deploy functions in containers to GCP and run them [up to certain limits](https://cloud.google.com/run/pricing) without incurring costs. I thought it would be worth kicking the tires by deploying one of the OpenFaaS functions I developed in my latest introductory post on [OpenFaaS Cloud & GitLab](https://www.openfaas.com/blog/openfaas-cloud-gitlab/).

You may already be familiar with OpenFaaS - Serverless Functions Made Simple. I started the project in December 2016 out of a desire to run serverless-style workloads on any cloud without fear of getting locked-in. For that reason OpenFaaS builds Docker or OCI-format container images.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">✅Has a simple HTTP contract on port 8080<br>✅Is packaged in containers<br>✅Runs functions OR microservices<br>✅Can use any 64-bit Linux binary or HTTP server<br>✅Auto-scales on QPS, even to zero<br>✅Started over 2.5 years ago 🤔<br><br>Name this <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> framework?</p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1115530479598473216?ref_src=twsrc%5Etfw">April 9, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The traits and characteristics of Cloud Run (hosted Knative) closely follow [what I outlined for OpenFaaS over two and a half years ago](https://blog.alexellis.io/functions-as-a-service/). This validates the design and [future of OpenFaaS into 2019 and beyond](https://blog.alexellis.io/openfaas-bright-2019/).

| Trait                        | OpenFaaS          | Cloud Run      | Knative
|------------------------------|-------------------|----------------|-------------|
| License                      | Open Source (MIT) | Proprietary    | Open Souce (Apache 2) |
| Workload                     | Container         | Container      | Container |
| TCP Port                     | HTTP 8080         | HTTP 8080      | HTTP 8080 |
| Auto-scaling on QPS          | Yes               | Yes            | Yes |
| Scale to zero                | Yes               | Yes            | Yes |
| Stateless microservices      | Yes               | Yes            | Yes |
| Functions                    | Yes               | No             | No |
| Run any binary as a service  | Yes               | No             | No |
| SaaS offering                | [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/)    | Cloud Run      | 3rd-party offerings |

There's an undeniable level of similarity between the work we've done in the OpenFaaS community and what we're seeing today in Google's Knative project. There are however some important differences, however exploring these is beyond the scope of this post. One of the key differences is that OpenFaaS targets light-weight, simple primitives directly within the Kubernetes API. The [OpenFaaS design](https://docs.openfaas.com/architecture/gateway/) builds its own set of UNIX-like primitives that allow any container orchestrator to implement functions.

<iframe src="https://giphy.com/embed/9S706ievhjXVfG9s9Q" width="480" height="480" frameBorder="0" class="giphy-embed" allowFullScreen></iframe><p><a href="https://giphy.com/gifs/cat-clone-cloned-9S706ievhjXVfG9s9Q">via GIPHY</a></p>

## Tutorial

Let's get started with the tutorial.

### Sign-up for GCP

If you're a customer of GCP then you can continue, otherwise [sign-up here](https://cloud.google.com/free/)

### Enable GCP APIs and services

You'll need to enable billing through a Linked Account which means it's time to go and grab your credit-card.

* Cloud Build - this is to enable automated linking to your GitHub repo

* Container Registry - Google won't allow you to deploy to Cloud Run unless you first push your images into a `gcr.io` registry/account.

* Cloud Run - Google's SaaS platform for deploying serverless containers

> Note: If you need to run on-premises, you can already deploy OpenFaaS on any [Kubernetes or OpenShift cluster](https://docs.openfaas.com/deployment/kubernetes/).

### Download the `gcloud` SDK/CLI

Grab the `gcloud` SDK (CLI) and authenticate to your chosen project.

* [Download here](https://cloud.google.com/sdk/)

```sh
gcloud auth login
```

### Fork the example project

Now fork my example project to your GitHub account.

[https://github.com/alexellis/openfaas-cloud-test](https://github.com/alexellis/openfaas-cloud-test)

### Configure Cloud Build

Since Google Cloud Build doesn't appear to allow the use of images not within a `gcr.io` account, we cannot use the official OpenFaaS CLI image which is published to quay.io and the Docker Hub. This means pulling the image to our local machine, then tagging it and pushing it up to the GCR project.

```sh
# Check "gcloud projects list" to find your project ID

export PROJECT_ID="alexellis"
docker pull openfaas/faas-cli:0.8.8
docker tag openfaas/faas-cli:0.8.8 gcr.io/$PROJECT_ID/faas-cli:0.8.8
docker push gcr.io/$PROJECT_ID/faas-cli:0.8.8
```

You've now created a mirror of the faas-cli Docker image to be used in the Cloud Build.

In the GCP Console find "Cloud Build" and "Triggers".

Now create a build for your forked repository. Accept all of the defaults.

![](/images/openfaas-cloudrun/cloud-build-trigger.png)

Save the trigger.

You can see from the `cloudbuild.yaml` contents that we'll first use the CLI to pull in the relevant templates, then create a build-context, carry out a build using the Cloud Builder's Docker adapter and then deploy it to a Cloud Run service.

```yaml
steps:
## Shinkwrap
- name: 'gcr.io/$PROJECT_ID/faas-cli:0.8.8'
  args: ['faas-cli', 'template', 'store', 'pull', 'node8-express']
- name: 'gcr.io/$PROJECT_ID/faas-cli:0.8.8'
  args: ['faas-cli', 'build', '--shrinkwrap']
## Build Docker image
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/timezone-shift:$REVISION_ID', '-t', 'gcr.io/$PROJECT_ID/timezone-shift:latest', '-f' ,'./build/timezone-shift/Dockerfile', './build/timezone-shift/']

## Deploy to "Cloud Run"
- name: 'gcr.io/cloud-builders/gcloud'
  args: ['beta', 'run', 'deploy', 'timezone-shift', '--image', 'gcr.io/$PROJECT_ID/timezone-shift:$REVISION_ID', '--region', 'us-central-1']

images: 
- 'gcr.io/$PROJECT_ID/timezone-shift'
```

We have a chicken-and-egg situation right now. The `cloudbuild.yaml` file does a build and then a deploy to an existing Cloud Run Service, but our Cloud Run Service does not yet exist and cannot be deployed without a valid YAML file.

Comment out the lines for the step named `## Deploy to "Cloud Run"` and then do a commit. This will push a container image into our `gcr.io` registry.

Each time your CI build finishes a new Revision will be created and deployed which is attached to the Cloud Run Service. This means if you do 10 successful builds, 10 Revisions will be deployed and [linked to the Service](https://cloud.google.com/run/docs/managing/services).

### Create a Cloud Run Service

Now that we have CI configured (and CD temporarily disabled) it's time to create a *Service*.

Go to Cloud Run in the GCP console and enter the following:

![](/images/openfaas-cloudrun/create-service.png)

Make sure you click *Allow unauthenticated invocations* so that anyone can invoke the function.

Now click *Create*.

Unfortunately it seems like the Cloud Run service is only available in the `us-central-1` region which means that you may incur significant latency if you live in Europe like myself. I expect this to be extended over time to cover additional regions.

### Enable CD

Now go over to your fork of my GitHub repo and edit your `cloudbuild.yaml` file. Un-comment the lines for the step: `## Deploy to "Cloud Run"`.  This will trigger a new build and we can watch it progress in the Google Cloud Build console.

![](/images/openfaas-cloudrun/cloud-build.png)

When complete it will deploy a second revision to the Cloud Run Service and we'll get a URL on the Cloud Run dashboard.

> Don't like managing a `cloudbuild.yaml` file for every one of your GitHub repositories? No problem - checkout [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/) which uses your existing stack.yml file to automate CI/CD for any linked repository on GitHub or self-hosted GitLab.

### Monitor the function

The Cloud Run UI has a somewhat spartan feel with many details hidden away or not yet available.

![](/images/openfaas-cloudrun/overview.png)

You can however view which Revision of your service is active and checkout the container logs:

![](/images/openfaas-cloudrun/logs.png)

### Cold starts

There appears to be some work-in-progress on [cold starts](https://github.com/knative/serving/issues/1297) in Knative. It's still early, but I would hope to see some improvements over time. As the linked issue explains, part of the additional latency is due to the decision to tightly couple to a service mesh (Istio). Istio can deliver some interesting features such as traffic-splitting and mutual TLS, but does not come for free.

## Wrapping up

We took an OpenFaaS function and without making any code or configuration changes to it we were able to deploy it to a brand new container SaaS platform built by a third-party. I think this is testament to the portability and ubiquity of the Docker / OCI-image format which I decided to use with OpenFaaS back in December 2016 when the project began.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">✅Has a simple HTTP contract on port 8080<br>✅Is packaged in containers<br>✅Runs functions OR microservices<br>✅Can use any 64-bit Linux binary or HTTP server<br>✅Auto-scales on QPS, even to zero<br>✅Started over 2.5 years ago 🤔<br><br>Name this <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> framework?</p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1115530479598473216?ref_src=twsrc%5Etfw">April 9, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Going forward you can continue to leverage OpenFaaS on any cloud - private, hybrid or public through OpenFaaS on Kubernetes, but today marks the day where OpenFaaS is so portable, that it even works on proprietary SaaS platforms. The Cloud Run and Knative approach to serverless containers mirrors very closely the design I outlined over two and a half years ago. There are however there are key differences in implementation, design and target audience between Knative project and the OpenFaaS community. In this post we built and packaged code with the OpenFaaS CLI and build templates and in my opinion that is a good place for Serverless 2.0 to start to converge. It takes much more than building and running container images to become a successful Open Source serverless project, to find out more about OpenFaaS read my post: [a bright future for 2019](https://blog.alexellis.io/openfaas-bright-2019/).

The OpenFaaS community values are: developers-first, operational simplicity, and community-centric. If you have comments, questions or suggestions or would like to join the community, then please [join us on OpenFaaS Slack](https://docs.openfaas.com/community/).

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

### You may also like:

Serverless 2.0 can also be used as a packaging format for other proprietary platforms such as AWS Lambda. Here's a preview of faas-lambda by [Ed Wilde](https://github.com/ewilde), a back-end provider built with OpenFaaS primitives that means functions can be written once and deployed to both AWS Lambda and OpenFaaS on Kubernetes without any modifications:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">What if I told you, that you could deploy your OpenFaaS functions directly to AWS Lambda or Kubernetes without changing them using all the same tools? <a href="https://t.co/D4qO4wnyoP">pic.twitter.com/D4qO4wnyoP</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1112632495286161413?ref_src=twsrc%5Etfw">April 1, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

* [Build a single page app with OpenFaaS Cloud](https://www.openfaas.com/blog/serverless-single-page-app/)
* [Sailing through the Serverless Ocean with Spotinst & OpenFaaS Cloud](https://spotinst.com/blog/2019/03/25/sailing-through-the-serverless-ocean-with-openfaas-cloud/)
* [OpenFaaS workshop](https://github.com/openfaas/workshop/)
