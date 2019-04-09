---
title: "Run your OpenFaaS functions for free on Google Cloud Run"
description: Yesterday Google announced a new serverless SaaS product named Cloud Run, learn how to deploy your OpenFaaS functions for free
date: 2019-04-09
image: /images/openfaas-cloud-gitlab/palms-1.jpg
categories:
  - cloud
  - kubernetes
  - cicd
  - gitops
author_staff_member: alex
dark_background: true
---

In this post I'll show you how to build your OpenFaaS functions into the well-known Docker / OCI-image format so that you can deploy them to your own OpenFaaS cluster or to Google's new Cloud Run SaaS product.

Yesterday Google [launched their new product](https://news.ycombinator.com/item?id=19610830) named Cloud Run. This is a proprietary serverless add-on for Google Cloud Platform (GCP) built around their flagship Istio and Knative projects.

What does that mean for you and me? It means that we can deploy functions in containers to GCP and run them up to certain limits without incurring any billing costs. I thought it would be worth kicking the tires by deploying on of the functions I developed in my latest introductory post on [OpenFaaS Cloud & GitLab](https://www.openfaas.com/blog/openfaas-cloud-gitlab/).

You may already be familiar with OpenFaaS - Serverless Functions Made Simple. I started the project in December 2016 out of a desire to run serverless-style workloads on any cloud without fear of getting locked-in. For that reason OpenFaaS builds Docker or OCI-format container images.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">✅Has a simple HTTP contract on port 8080<br>✅Is packaged in containers<br>✅Runs functions OR microservices<br>✅Can use any 64-bit Linux binary or HTTP server<br>✅Auto-scales on QPS, even to zero<br>✅Started over 2.5 years ago 🤔<br><br>Name this <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> framework?</p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1115530479598473216?ref_src=twsrc%5Etfw">April 9, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The traits and characteristics of Cloud Run / Knative match exactly what I outlined for OpenFaaS over two and a half years ago.

| Trait                        | OpenFaaS          | Cloud Run      | Knative
|------------------------------|-------------------|----------------|-------------|
| License                      | Open Source (MIT) | Proprietary    | Open Souce (Apache 2) |
| Workload                     | Container         | Container      | Container |
| TCP Port                     | HTTP 8080         | HTTP 8080      | HTTP 8080 |
| Auto-scaling on QPS          | Yes               | Yes    | Yes |
| Scale to zero                | Yes               | Yes    | Yes |
| Stateless microservices      | Yes               | Yes    | Yes |
| Functions                    | Yes               | No    | No |
| Run any binary as a service  | Yes               | No    | No |


There's an undeniable level of similarity between the work we've done in the OpenFaaS community and what we're seeing today in Google's Knative project. There are however some important differences but this is beyond the scope of the post.

<iframe src="https://giphy.com/embed/9S706ievhjXVfG9s9Q" width="480" height="480" frameBorder="0" class="giphy-embed" allowFullScreen></iframe><p><a href="https://giphy.com/gifs/cat-clone-cloned-9S706ievhjXVfG9s9Q">via GIPHY</a></p>

## Sign-up for GCP

If you're a customer of GCP then you can continue, otherwise [sign-up here](https://cloud.google.com/free/)

### Enable GCP APIs and services

You'll need to enable:

* Cloud Build - this is to enable automated linking to your GitHub repo

* Container Registry - Google won't allow you to deploy to Cloud Run unless you first push your images into a `gcr.io` registry/account.

* Cloud Run - Google's SaaS platform for deploying serverless containers

All of the above require a linked Billing Account which means entering a valid credit-card.

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

Since Google Cloud Build doesn't appear to allow the use of images not within a `gcr.io` account, we cannot use the OpenFaaS CLI from the Docker Hub. We'll need to pull it to our local machine then push it to our GCR project.

```
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

Each time your CI build finishes a new Revision will be created and deployed which is attached to the Cloud Run Service. This means if you do 10 successful builds, 10 Revisions will be deployed and linked to the Service.

### Create a Cloud Run Service

Now that we have CI and CD configured it's time to create a Service.

Go to Cloud Run in the GCP console and enter the following:

![](/openfaas-cloudrun/create-service.png)

Make sure you click *Allow unauthenticated invocations* so that anyone can invoke the function.

Now click *Create*.

Unfortunately it seems like the Cloud Run service is only available in the `us-central-1` region which means that you may incur significant latency if you live in Europe like myself. I expect this to be extended over time to cover additional regions.

### Enable CD

Now go over to your fork of my GitHub repo and edit your `cloudbuild.yaml` file. Un-comment the lines for the step: `## Deploy to "Cloud Run"`.  This will trigger a new build and we can watch it progress in the Google Cloud Build console.

![](/images/openfaas-cloudrun/cloud-build.png)

When complete it will deploy a second revision to the Cloud Run Service and we'll get a URL on the Cloud Run dashboard.

## Wrapping up

We took an OpenFaaS function and without making any functional of configuration changes to it were able to deploy it to a brand new container SaaS platform built by a third-party. I think this is testament to the portability and ubiquity of the Docker / OCI-image format which I decided to use with OpenFaaS back in December 2016 when the project began.

Going forward you can continue to leverage OpenFaaS on any cloud - private, hybrid or public through OpenFaaS on Kubernetes, but today marks the day where OpenFaaS is so portable, that it even works on proprietary SaaS platforms.

The Cloud Run and Knative approach to serverless containers mirrors almost exactly the design I outlined over two and a half years ago. There are however key differences in complexity, running costs and driving values between the Knative project and OpenFaaS.

The OpenFaaS community values are: developers-first, operational simplicity and community-centric.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">✅Has a simple HTTP contract on port 8080<br>✅Is packaged in containers<br>✅Runs functions OR microservices<br>✅Can use any 64-bit Linux binary or HTTP server<br>✅Auto-scales on QPS, even to zero<br>✅Started over 2.5 years ago 🤔<br><br>Name this <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> framework?</p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1115530479598473216?ref_src=twsrc%5Etfw">April 9, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

If you have comments, questions or suggestions then please [join the OpenFaaS Slack](https://docs.openfaas.com/community/) to chat with the community.

### You may also like:

* [Build a single page app with OpenFaaS Cloud](https://www.openfaas.com/blog/serverless-single-page-app/)
* [Sailing through the Serverless Ocean with Spotinst & OpenFaaS Cloud](https://spotinst.com/blog/2019/03/25/sailing-through-the-serverless-ocean-with-openfaas-cloud/)
* [OpenFaaS workshop](https://github.com/openfaas/workshop/)
