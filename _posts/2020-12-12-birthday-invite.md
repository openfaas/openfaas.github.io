---
title: "You're invited to our 4th Birthday!"
description: "Join our 4th Birthday celebrating for an update on 2020, what's coming in 2021 and how to build your own private cloud with Raspberry Pis"
date: 2020-12-12
image: /images/2020-12-12-birthday/background.jpg
categories:
 - serverless
 - containers
 - community
 - event
author_staff_member: alex
dark_background: true

---

Join our 4th Birthday celebrating for an update on 2020, what's coming in 2021 and how to build your own private cloud with Raspberry Pis.

# Introduction

This year has been a tough one for many people, including the OpenFaaS community, however with the support of our contributors, customers, sponsors and contributors, we've been able to stay in the game.

The purpose of OpenFaaS is to make Serverless accessible and portable for application developers, and over the years that's meant going through some changes. We initially leveraged Docker Swarm for running functions, then added support for Kubernetes. Today we recommend all users use Kubernetes for the best experience, but you'll also note that this is the year we introduced faasd.

Catch-up with our [3rd Birthday celebration blog post](https://www.openfaas.com/blog/birthday-teamserverless/) from last year.

![OpenFaaS at KubeCon](/images/2020-12-12-birthday/openfaas-kubecon.jpeg)

> OpenFaaS on the keynote stage at KubeCon in 2017

## CKA optional

You don't have to take a CKA to develop applications with OpenFaaS. Most of the time, using OpenFaaS and our supporting tooling like arkade and k3sup means Kubernetes gets out of your way.

In the Birthday event we'll also talk about faasd and OpenFaaS Cloud:

### faasd

faasd is a portable, and lean version of OpenFaaS which uses the same low-level components as a Kubernetes cluster - containerd, runc and Container Networking Initiative (CNI)), but without the complexity of managing infrastructure.

It was built as an alternative to Kubernetes, and is already being used in production by several end-user companies and community members. It doesn't include clustering or high-availability, and as a result is much cheaper and easier to operate.

### OpenFaaS Cloud

[OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) was designed for technical leads and platform engineers, so that they can offer a GitOps-style experience to colleagues who aren't interested in learning how to manage Kubernetes. It's open source and you can self-host it.

> We built it because we saw many companies adopting OpenFaaS and building the same thing: a PaaS that deployed code was committed to a repository.

OpenFaaS Cloud is built using OpenFaaS functions - from the new dashboard, to the CI pipeline, to the webhook handlers, to garbage collection.

We'll mention both in our Birthday update along with much more!

## Your birthday invite

We'll be holding a prize draw, which is optional when signing up for your place on the 18th December.

![Birthday invite](https://pbs.twimg.com/media/EOQIw-nW4AEiwr9?format=jpg&name=small)

The agenda will include:

* Changes and developments in 2020
* A new OpenFaaS Core Team member
* Thanking our community and sponsors
* Announcements & plans for 2021

* [Save the date 🎂 - OpenFaaS 4th birthday!](https://github.com/openfaas/faas/issues/1592)

## How to build your own private cloud with Raspberry Pis

As part of our 2020 experiences we moved all of our CI from Travis to GitHub Actions, and whilst we were there we made all of our templates and projects multi-arch. Meaning that the containers will run on Intel and ARM computers without any changes.

> As a side benefit, it means you'll be able to run OpenFaaS on your new Apple M1!

Running OpenFaaS Cloud on a Raspberry Pi was never one of our goals for the project. It was meant to be for companies and teams, it's designed for collaboration and ease of use.

We developed OpenFaaS Cloud in 2017 and have been improving it ever since, through community contributions and custom development for customers. This year at [GitHub's Universe event Kelsey Hightower showed a demo of GitOps](https://githubuniverse.com/Kelsey-Kubernetes-and-GitOps/) for a simple HTTP service written in Go.

### Prize draw

We'll be sending out SWAG and some surprise gifts. To participate in the prize draw, sign up and attend on the day. This is our way of saying thank you for your support.

![SWAG](https://pbs.twimg.com/media/EoEunmKXMAERUiT?format=jpg&name=small)

We also have a commemorative coffee and tea mug available for you [in the store](https://store.openfaas.com/) with a special design by contributor [Utsav Anand](https://openfaas.com/team). I personally like the "EST 2016" decal and 8-bit design.

<a href="https://store.openfaas.com/products/openfaas-4th-birthday-celebration-mug"><img src="https://cdn.shopify.com/s/files/1/0340/9739/7895/products/mockup-a83e8509_1024x1024@2x.jpg?v=1606569983" width="80%"></a>

> [OpenFaaS 4th Birthday Celebration Mug](https://store.openfaas.com/products/openfaas-4th-birthday-celebration-mug)

### The big demo we're preparing for you

We'll show you a similar demo, with our platform that can be run on any cloud, but you won't have to worry about configuring additional tooling. Once a GitHub or GitLab repository is connected to OpenFaaS Cloud, any "git push" events and commits merged into master will trigger a build and deployment of the code.

You can see a very quick demo here using our OpenFaaS Go template:
{% include youtube.html id="425SJZ2B81g" %}

The idea is that a platform engineer or an IT manager would deploy it, and then invite their team to link Git repositories and deploy their functions.

* Link self-hosted GitLab or GitHub.com, using organisations or individual repos
* OpenFaaS templates and Dockerfiles are supported
* Encrypted secrets are supported inside the repo
* Monitor and debug your functions from a single dashboard.

Here's a sneak preview of OpenFaaS Cloud running on two of my Raspberry Pis and auto-scaling during a load-test:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Thanks to everyone who helped to port <a href="https://twitter.com/OpenFaaSCloud?ref_src=twsrc%5Etfw">@OpenFaaSCloud</a> to ARM64 and <a href="https://twitter.com/Raspberry_Pi?ref_src=twsrc%5Etfw">@Raspberry_Pi</a> . Here&#39;s a moderate load-test showing auto-scaling and balancing of traffic between replicas. It&#39;s running under my TV over an <a href="https://twitter.com/inletsdev?ref_src=twsrc%5Etfw">@inletsdev</a> tunnel. <a href="https://t.co/TL0K3wtcFV">pic.twitter.com/TL0K3wtcFV</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1335229991886458881?ref_src=twsrc%5Etfw">December 5, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

And here's my demo rig used at KubeCon for my session on [Kubernetes on Raspberry Pi - past, present and future](https://www.youtube.com/watch?v=jfUpF40--60):

<blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">My demo rig for today. <a href="https://t.co/r6McGawHaU">pic.twitter.com/r6McGawHaU</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1329881233770369025?ref_src=twsrc%5Etfw">November 20, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

## Wrapping up

We hope that you can join us! Everyone who attends will get early access to the deployment instructions for OpenFaaS Cloud on their Raspberry Pi, and a bill of materials.

Don't miss out on our demo, our highlights of 2020 and what's to come in 2021.

* [Save the date 🎂 - OpenFaaS 4th birthday!](https://github.com/openfaas/faas/issues/1592)

Learn more:
* Video: [OpenFaaS Cloud + Linkerd: A Secure, Multi-Tenant Serverless Platform](https://www.youtube.com/watch?v=sD7hCwq3Gw0&feature=emb_title)
* Video: [Meet faasd. Look Ma’ No Kubernetes!](https://www.youtube.com/watch?v=ZnZJXI377ak)

