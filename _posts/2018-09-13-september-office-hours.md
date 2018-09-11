---
title: September Office Hours
description: Multi-user OpenFaaS Cloud, Istio Service Mesh, and Stateless Microservices

date: 2018-09-13
image: /images/september-office-hours/team.jpg
categories:
  - office-hours
  - community
  - kubernetes
author_staff_member: burton
dark_background: true
---

September's OpenFaaS office hours meeting includes updates to OpenFaaS Cloud as a multi-user platform for teams, how we've improved the ability to run stateless microservices managed as functions, and includes a demo of Istio service mesh integration.

The OpenFaaS community holds regular office hours for anyone to join in as well as more focused discussions with project members

Types of calls:
* Office Hours (750 community members)
  * Questions and Answers
  * Project updates and direction
* Members Call (15 members)
  * Members of the Github organization
  * Assign and track issues
* Core Contributors (5 core members)
  * Wide project vision
  * Help with project direction

> All of the office hours meetings are recorded and available for later viewing on YouTube.

{% include youtube.html id="IQCnHMn1wdI" %}

Subscribe to the [Official OpenFaaS YouTube Channel](https://www.youtube.com/channel/UCdKi97g5FmzvrmtIp9FyOVA) where you can view the highlights from our meetings including demos of the newest features we're working on

## Project Goals and Purpose
OpenFaaS is focused on developers first, easy for operators, and the great community aspect

* Developer first
  * OpenFaaS gives you "Serverless on your terms"
  * Focused on being easy to use with a web UI and CLI (eg: `faas-cli up`)
    * [Five Tips and Tricks for the OpenFaaS CLI]({% post_url 2018-08-22-five-cli-tips %})
* Easy for operators
  * [OpenFaaS Operator](https://github.com/openfaas-incubator/openfaas-operator)
  * [Scale to Zero]({% post_url 2018-07-25-zero-scale %})
* Great Community
  * 130+ contributors
  * Most have multiple commits, coming back helping build the project
  * Built by the community, for you to use

## What's New
* [Stateless Microservices]({% post_url 2018-09-06-stateless-microservices %})
  * Deploy a regular microservice and manage them just like functions
* [Growing list of end users](https://docs.openfaas.com/#users-of-openfaas)
  * Shows growing traction as a production-ready FaaS platform
  * Add your company [here](https://github.com/openfaas/faas/issues/776)
* [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/)
  * GitOps for your functions
  * Becoming a platform to run OpenFaaS for multiple users or a team

## What's Coming
* Istio Service Mesh integration
  * Demonstration by Stefan Prodan
* OpenFaaS Cloud upgrades 
  * Better Multi-user support with OAuth 2.0 and React Dashboard
  * GitLab support
* OSS Summit in Edinburgh
  * October 22 - 24, 2018
  * Meet with some of the OpenFaaS members

## Istio Integration

"I wanted to integrate OpenFaaS with Istio to take advantage of Istio builtin security features and tracing capabilities. Some of the features demoed are: mutual TLS between OpenFaaS core services and functions, Jaeger tracing for function calls, function isolation with Mixer policies." - _Stefan Prodan_

## ARM Support

Did you know you can also run OpenFaaS on ARM architecture like the RaspberryPi?

During the community updates, some members mention they are adding better compatibility for ARM and ARMHF across all repositories with regular updates to the available images.

## Get Involved
Try OpenFaaS today with our self-paced [workshop](https://docs.openfaas.com/tutorials/workshop/)
> Try the workshop on a single node Kubernetes instance on DigitalOcean [here]({% post_url 2018-08-27-deploy-digitalocean-ansible %})

[Join us](https://docs.openfaas.com/community/#slack-workspace) on the community Slack channel

We announce the working hours meetings on Slack and Twitter, so be sure to join us for the next call!
