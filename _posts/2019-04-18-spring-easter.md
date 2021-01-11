---
title: "Get to grips with Serverless Kubernetes this Spring"
description: Alex will give you his top five tips for getting to grips with Serverless on Kubernetes for this Spring including training materials and ways to connect with the community.
date: 2019-04-18
image: /images/spring-easter/crocus.jpg
categories:
  - community
  - workshop
  - events
  - kubernetes
author_staff_member: alex
dark_background: true
---

In this post I want to run through my top five tips for getting to grips with Serverless on Kubernetes. If you're taking some time off over the Easter Bank Holiday weekend, then grab a cup of tea or coffee and your laptop to begin learning.

### 1. Connect with the community

> The OpenFaaS community values are: developers-first, operational simplicity, and community-centric.

The easiest way to start learning is to connect with the OpenFaaS community. We're a friendly bunch and enjoy meeting-up in person at conferences and local events. 
All future, past and present events and blog posts are recorded in the community guide which is available publicly. So if you'd like to meet face-to-face or hear about what we're all building in person check that out.

![](/images/spring-easter/contributors.jpg)

*This is what 200 contributors looks like 🎉*

* [Community events 2019](https://github.com/openfaas/faas/blob/master/community.md#events-in-2019)
* [Community blogs 2019](https://github.com/openfaas/faas/blob/master/community.md#blog-posts-and-write-ups-2019)

* [OpenFaaS Community Slack](https://docs.openfaas.com/community/)
* [#TeamServerless private group on LinkedIn](https://www.linkedin.com/groups/13670843/)
* [@openfaas Twitter](https://twitter.com/openfaas/)

We have dedicated channels for all sorts of topics including #general talk about containers and cloud, #kubernetes for all things k8s and CNCF, #faas-provider if you're looking to build your own provider for OpenFaaS, #contributors for those of you looking to cut some code and #arm-and-pi for ARM and small devices.

### 2. Kick the tires

Did you know that you can build and deploy both functions and stateless microservices on OpenFaaS? That means that if you are using or considering using containers, then OpenFaaS can offer you value and time-savings. In my latest blog post I wrote up about [Simple Serverless with Golang Functions and Microservices](https://www.openfaas.com/blog/golang-serverless/).

You can deploy OpenFaaS in a couple of minutes to any cloud using Kubernetes or Docker Swarm (other options are available, too).

Here's three of the top guides from the documentation and blog:

* [Kubernetes guide](https://docs.openfaas.com/deployment/kubernetes/) / [Kubernetes helm-chart](https://github.com/openfaas/faas-netes/blob/master/HELM.md)
* [Docker Swarm guide](https://docs.openfaas.com/deployment/docker-swarm/)
* [One-click deployment via the DigitalOcean Marketplace](https://www.openfaas.com/blog/digitalocean-one-click/)

After that you may want to try the workshop (below) or one of the many tutorials and blog posts [from the community guide](https://github.com/openfaas/faas/blob/master/community.md#blog-posts-and-write-ups-2019).

* [Will it cluster? k3s on your Raspberry Pi](https://blog.alexellis.io/test-drive-k3s-on-raspberry-pi/)

Something that resonates particularly well with our community as a weekend-project is building a Raspberry Pi cluster. In the post I explain the need for k3s, its differences to other local Kubernetes distributions and then full Bill of materials (BoM) for the cluster. You'll follow step-by-step instructions on how to deploy Kubernetes using the new light-weight [k3s project from Rancher](https://k3s.io/) and how to use it with OpenFaaS on the Raspberry Pi (ARM) platform.

### 3. Find out about our end-user community

![End users as of Apr 2019](/images/spring-easter/end-users.png)

*End users, as of April 2019*

One of the most recent recordings of an OpenFaaS end-user was from KubeCon in Seattle in late 2018.

[Patricio Diaz](https://twitter.com/padiazg?lang=en) joined me from Vision Banco in Paraguay to relate his experiences of moving from unstable, legacy systems to 100% uptime with OpenFaaS on Kubernetes.

<iframe width="560" height="315" src="https://www.youtube.com/embed/mPjI34qj5vU" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

If you're using OpenFaaS at your company or within your team for internal or external-facing projects or products, please reach out over email to: alex@openfaas.com for how to join.

In just a few weeks, at KubeCon two more end-user companies will present on how they're leveraging OpenFaaS in production to solve business problems.

* [How LivePerson is Tailoring its Conversational Platform Using OpenFaaS - Simon Pelczer, LivePerson](https://kccnceu19.sched.com/event/MPeR/how-liveperson-is-tailoring-its-conversational-platform-using-openfaas-simon-pelczer-liveperson-ivana-yovcheva-vmware)
* [Accelerating the Journey of an AI Algorithm to Production with OpenFaaS - Joost Noppen, BT PLC & Alex Ellis](https://kccnceu19.sched.com/event/MPeF/accelerating-the-journey-of-an-ai-algorithm-to-production-with-openfaas-joost-noppen-bt-plc-alex-ellis-vmware)

### 4. Try the self-paced labs or an in-person workshop

Over the past 18 months the community has been been building, delivering and refining a set of 12 self-paced labs that cover everything you need to know about Serverless on Kubernetes. The labs use examples in Python, but even if you don't write a lot of code, the examples are broken down into small chunks that are easy to understand.

![](/images/spring-easter/serverless2.0.png)

*Pictured above: portable functions and microservices starts with Serverless 2.0*

> The workshop is open-source and questions, comments and suggestions are welcomed.

Topics include:

* Lab 1 - Prepare for OpenFaaS by creating your cluster
* Lab 2 - Test things out and get familiar with the CLI, UI and Function Store
* Lab 3 - Introduction to Functions
* Lab 4 - Go deeper with functions

* Lab 5 - Create a GitHub bot
* Lab 6 - HTML for your functions
* Lab 7 - Asynchronous Functions

* Lab 8 - Advanced Feature - Timeouts
* Lab 9 - Advanced Feature - Auto-scaling
* Lab 10 - Advanced Feature - Secrets
* Lab 11 - Advanced feature - Trust with HMAC

You can check [the community events](https://github.com/openfaas/faas/blob/master/community.md#events-in-2019) for your next in-person training or [request one via email](mailto:alex@openfaas.com).

> If you've already done the workshop with Docker Swarm, try the new updated version for Kubernetes and make sure you don't miss my [5 productivity tips for the faas-cli](https://www.openfaas.com/blog/five-cli-tips/).

Begin the [OpenFaaS workshop](http://github.com/openfaas/workshop) or *Star* it on GitHub for later.

### 5. Try the OpenFaaS Cloud Community Cluster

If all this talk of containers and Kubernetes is unfamiliar territory, then you can request for access to the OpenFaaS Cloud Community Cluster which is a hosted platform operated by the community.

With OpenFaaS Cloud you get for free:

* Integration into GitHub so that you only have to type `git push` to deploy functions
* Detailed metrics, logs and a badge for your README.md
* Your own personal dashboard
* HTTPS for every function or microservice
* A personal sub-domain for your GitHub account

Here's a demo of the OpenFaaS Cloud flow in action:

<iframe width="560" height="315" src="https://www.youtube.com/embed/Sa1VBSfVpK0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

Form: [Request access now](https://forms.gle/8e6ZXJKMcDHpV6Xu6)

If you're experienced with OpenFaaS, then perhaps you'd like to stand-up your own OpenFaaS Cloud with the [ofc-bootstrap tool](https://github.com/openfaas/ofc-bootstrap)? It takes around 100 seconds to deploy to a Kubernetes service such as [DigitalOcean Kubernetes](https://www.digitalocean.com/products/kubernetes/) or [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/). You'll get the same experience as with the Community Cluster including automatic TLS and support for GitHub.com or GitLab self-hosted.

## Wrapping up

I've shared my 5 top tips for getting to grips with Serverless on Kubernetes. I hope you'll enjoy the material and projects as much as we have enjoyed building, testing and refining them over the past 2.5 years.

If you have comments, questions or suggestions or would like to join the community, then please [join us on OpenFaaS Slack](https://docs.openfaas.com/community/).

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

### You may also like:

* [Introducing the Kubernetes Operator and CRD](/blog/kubernetes-operator-crd/)
* [Build a single page app with OpenFaaS Cloud](/blog/serverless-single-page-app/)
* [Simple Serverless with Golang Functions and Microservices](https://www.openfaas.com/blog/golang-serverless/)
