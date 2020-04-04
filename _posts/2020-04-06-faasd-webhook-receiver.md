---
title: "Using faasd as a lightweight webhook receiver"
description: Burton explains webhooks, and how to set up a lightweight serverless receiver with faasd
date: 2020-04-04
image: /images/2020-04-04-faasd-webhook/chain-hook.jpg
categories:
  - faasd
  - serverless
  - webhook
author_staff_member: burton
dark_background: true
---

# Webhooks open the door to many possibilities
A [webhook](https://en.wikipedia.org/wiki/Webhook), also referred to as a callback, is a way for an application or service to invoke some action in a separate application in near real-time. Webhooks are a great way to build out custom functionality for many popular services that offer registering webhooks. Applications like [GitHub](https://developer.github.com/webhooks/), [Jira](https://developer.atlassian.com/cloud/jira/platform/webhooks/), [Stripe](https://stripe.com/docs/webhooks), and many more offer the ability to register an API endpoint that they will `POST` a message to when certain events occur on their application. You can then use the data they send to do almost anything you want with it. But first, we need something to receive those webhook requests.

# Setting up a faasd receiver
OpenFaaS is a serverless framework for deploying functions and microservices to Kubernetes. [faasd](https://github.com/openfaas/faasd/) is OpenFaaS with containerd making it a lightweight alternative without the need for a full Kubernetes cluster.

The system requirements for running faasd are minimal. Most cloud providers' smallest instance will be enough, or if you are hosting on your own hardware, you could even use a [Raspberry Pi](https://blog.alexellis.io/faasd-for-lightweight-serverless/)

Deploying your faasd instance to a cloud provider, you can utilize Canonical's [cloud-init](https://cloud-init.io/) in order to automatically setup and configure everything you need. You'll need to copy your public ssh key into the [cloud-config.txt](https://github.com/openfaas/faasd/blob/master/cloud-config.txt) file provided in the repository. Then, paste your modified script into the cloud-init input for the cloud provider.

If you're using your own hardware, or your cloud provider does not yet support cloud-init, you can install the dependencies and setup faasd manually.

You will need:
* [CNI](https://github.com/containernetworking/plugins)
* [containerd](https://github.com/containerd/containerd)
* [runc](https://github.com/opencontainers/runc)

More information for how to setup each of these requirements can be found in the [manual installation instructions](https://github.com/openfaas/faasd/blob/master/docs/DEV.md)

# Setting up the webhook
For this example, we will use a publicly available Trello board in order to share with the world the status of some features that are being developed in a private GitHub repository. 

The idea is similar to the [AWS containers roadmap](https://github.com/aws/containers-roadmap/projects/1) and the [Cloudcraft roadmap](https://trello.com/b/mv14mX1U/cloudcraft-roadmap). Both of these companies have decided to share their plan and progress publicly while keeping their codebase private. This allows visibility and customer input into the products being built without sharing proprietary information.

# Processing the information


# Wrapping Up
Thanks to how lightweight faasd is, and the ability to use the cloud-init to have a new instance start up with no configuration, we are able to start and stop the webhook receiver as needed. 

With the portability of the OpenFaaS functions, we are able to build and test locally, and have the same experience once deployed. Also, if the time comes to where a Kubernetes cluster is made available, there would be no changes needed to move our webhook receiver functions to a Kubernetes backed OpenFaaS instance.

## Join our community

Your input and feedback is welcome. Please join the community [Slack workspace](https://slack.openfaas.io) and bring any comments, questions or suggestions that you may have.