---
title: "Introducing the PLONK Stack for Cloud Native Developers"
description: You've heard of LAMP, JAM, and MEAN, but what's the PLONK stack, and why should you be considering it for your Cloud Native Applications?
date: 2019-08-04
image: /images/2019-intro-plonk/map-reader.jpg
categories:
  - community
  - end-user
  - production
  - kubernetes
  - plonk
  - cloud native
author_staff_member: alex
dark_background: true
---

You've heard of LAMP, JAM, and MEAN, but what's the PLONK stack, and why should you be considering it for your Cloud Native Applications?

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Introducing the PLONK! stack.<br><br>Probably fits in less than 1GB of RAM when used with k3s. <a href="https://twitter.com/PrometheusIO?ref_src=twsrc%5Etfw">@PrometheusIO</a> <a href="https://twitter.com/linkerd?ref_src=twsrc%5Etfw">@linkerd</a> <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> <a href="https://twitter.com/nats_io?ref_src=twsrc%5Etfw">@nats_io</a> <a href="https://twitter.com/kubernetesio?ref_src=twsrc%5Etfw">@kubernetesio</a> <a href="https://twitter.com/CloudNativeFdn?ref_src=twsrc%5Etfw">@CloudNativeFdn</a> <a href="https://twitter.com/Rancher_Labs?ref_src=twsrc%5Etfw">@Rancher_Labs</a> <a href="https://t.co/TMTtu2oRup">pic.twitter.com/TMTtu2oRup</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1154385264925650950?ref_src=twsrc%5Etfw">July 25, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The PLONK stack combines the following Cloud Native technologies from the Cloud Native Landscape:

* Prometheus
* Linkerd
* OpenFaaS
* NATS
* Kubernetes

Out of the projects listed, four are CNCF-hosted. Of the CNFC projects, 2 are "graduated" and the other two are "incubating" and showing signs of graduation soon. In this post I'll explain what each of these CNCF projects lends to OpenFaaS, and how they can build a first-class FaaS or PaaS when combined.

### The projects

Let's take a quick look at each project, where you can get it from and how it is used.

#### Prometheus

> The Prometheus monitoring system and time series database.

With its [origins in the engineering team at SoundCloud](https://www.youtube.com/watch?v=cdKc8ePbj4A), Prometheus is now the de-facto monitoring solution for Cloud Native projects. It combines a simple interface with a powerful query language to monitor and observe microservices and functions, which are the two primitives of any FaaS or PaaS.

[Prometheus](https://prometheus.io) is the core project, but the ecosystem is rich, and growing.

* [node_exporter](https://github.com/prometheus/node_exporter) - get metrics from machines in your cluster, VMs, or servers
* [alertmanager](https://github.com/prometheus/alertmanager) - fire off alerts according to custom rules including integrations to Hipchat, Slack, Pagerduty, and more

There are two ways to expose metrics to Prometheus:

* add an instrumentation endpoint to each of your applications using a [client library](https://github.com/prometheus/client_golang)
* create an "exporter" which leaves your code unmodified

The project community encourage users to add instrumentation endpoints such as `/metrics` to their applications.

Once you've added instrumentation endpoints, and decided what to record, you set up a Prometheus server and tell it which endpoints to start collecting from. Collecting is also called "scraping" and multiple "service-discovery" mechanisms exist such as DNS, or Consul which means no manual lists of endpoints are required. This makes Prometheus perfect for auto-scaling systems.

Here's an example of the dashboard you can deploy with OpenFaaS using Grafana. Grafana is an open-source dashboarding tool which can render and save collections of queries onto the Prometheus time-series.

![Dashboard](https://camo.githubusercontent.com/24915ac87ecf8a31285f273846e7a5ffe82eeceb/68747470733a2f2f7062732e7477696d672e636f6d2f6d656469612f4339636145364358554141585f36342e6a70673a6c61726765)

#### Linkerd

[Linkerd](https://linkerd.io) is a service-mesh which aims to be: lightweight, non-intrusive, easy-to-use and simple. There are two versions with the first one being written in Java and the second, called Linkerd2, which is written in a mixture of Rust and Go. The ethos of the Linkerd team and project align very well with OpenFaaS.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">The Serverless + Linkerd2 for Kubernetes guide has been updated.<br><br>🍻 canaries and blue/green<br>🍻 mTLS for Ingress&lt;&gt;GW&lt;&gt;Function<br>🍻 Live tap / mesh data<br>🍻 Prometheus dashboards<br>🍻 balanced LB, even with KeepAlive<a href="https://t.co/ngUJWz1950">https://t.co/ngUJWz1950</a> <a href="https://twitter.com/hashtag/servicemesh?src=hash&amp;ref_src=twsrc%5Etfw">#servicemesh</a> <a href="https://twitter.com/hashtag/faas?src=hash&amp;ref_src=twsrc%5Etfw">#faas</a> <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> <a href="https://twitter.com/hashtag/kubernetes?src=hash&amp;ref_src=twsrc%5Etfw">#kubernetes</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1156504558044110848?ref_src=twsrc%5Etfw">July 31, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

It's my opinion that some people can benefit from using a service-mesh. It is probably the only optional part of the PLONK stack, but I also believe it offers some great benefits at a very low operational cost.

* end-to-end encryption through mutual TLS

Linkerd can encrypt HTTP traffic through the use of mTLS which is enabled by default for all meshed services. OpenFaaS primarily uses HTTP for synchronous function invocations or microservice calls which means that you can get encryption right from your Ingress Controller through to the API Gateway, to the Pod that served your request.

* detailed metrics

One of the reasons people love OpenFaaS is that it adds instrumentation for all functions or microservices. OpenFaaS achieves that by routing all traffic through the API gateway. The API gateway can even be auto-scaled to stop it from becoming a dreaded "Single Point of Failure" (SPOF). Well Linkerd adds even more metrics and comes with great dashboards built-in.

You will love the Linkerd UI and dashboard which you can open up with a single command `linkerd dashboard`.

* traffic shifting

One of the newest features of Linkerd 2.4 is the ability to shift traffic proportionally between two services by assigning them both a weight. This works out of the box with OpenFaaS without any additional need for changes to the project.

Linkerd has a very active and welcoming community. Their primary sponsor is [Buoyant](https://buoyant.io), which was founded by [William Morgan](https://twitter.com/wm) and [Oliver Gould](https://twitter.com/olix0r) after leaving Twitter.

There are many other features a service-mesh can offer, but these are my top features based upon their usefulness to a FaaS or PaaS.

#### OpenFaaS

When I started OpenFaaS in 2016, the project was going up against some very successful projects from huge corporations. Oftentimes the corporations were producing products which were far too complex to use and operate on a daily-basis. Even the newest projects in the Serverless space have been widely criticised for trying to do too much and being spread thin.

<blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">Three years in, what&#39;s the mission of <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@OpenFaaS</a>? <a href="https://t.co/WigsKE4UZ9">pic.twitter.com/WigsKE4UZ9</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1158064708202749954?ref_src=twsrc%5Etfw">August 4, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The motto of OpenFaaS is "Serverless Functions Made Simple" and this is reflected in the project values:

* developers-first

* operationally simple

* community-centric

To date there are dozens of end-user companies, some of which have given permission to list their logo on [OpenFaaS.com](https://openfaas.com), over 230 contributors, 18k GitHub stars, and [hundreds of community blogs and events recorded](https://github.com/openfaas/faas/blob/master/community.md).

If you're new to OpenFaaS and are wondering what it's all about, then you can get up to speed with my video from Goto: Serverless Beyond the Hype:

<iframe width="560" height="315" src="https://www.youtube.com/embed/yOpYYYRuDQ0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

In simple terms OpenFaaS offers:

* an easy way to package any code or binary
* a rich ecosystem of language templates
* a function store to collaborate and share
* metrics, auto-scaling, and dozens of detailed tutorials
* a native experience on Kubernetes, without the overheads
* a dedicated community ready to help you, when you need it most

[OpenFaaS.com](https://www.openfaas.com/) is hosted by [OpenFaaS Ltd](mailto:sales@openfaas.com) and developed by a [voluntary team of developers and experts](https://www.openfaas.com/team/).

Users can get commercial support, help with architecture, training and consultation from [OpenFaaS Ltd](mailto:sales@openfaas.com).

#### NATS

> NATS.io is a simple, secure and high performance open source messaging system for cloud native applications, IoT messaging, and microservices architectures.

[NATS](https://nats.io) was developed by [Derek Collison](https://www.linkedin.com/in/derekcollison/) and gained significant traction among Cloud Native developers. So much so, that it was accepted into the CNCF as a hosted project in 2018.

OpenFaaS uses NATS Streaming as a queuing system, so that invocations can be queued up and processed in parallel as capacity becomes available within your cluster. Asynchronous invocations are built-in and do not require any updates to your endpoint, you can even request a HTTP callback when the invocation has completed.

```sh
faas-cli store deploy figlet

# Synchronous, or blocking

curl http://gateway.example.com/function/figlet -d NATS

# Asynchronous, or non-blocking:

curl http://gateway.example.com/function/figlet -d NATS -H "X-Callback-Url: http://gateway.example.com/function/after-figlet"
```

NATS, just like Linkerd and OpenFaaS aims to be simple to install, operate, and use over time.

> Derek has now gone on to found a new company called [Synadia](https://synadia.com) aiming to "Connect Everything" through NATS 2.0. NATS 2.0 brings many similar features to those offered by a Service Mesh and is being positioned as a "digital dial-tone".

#### Kubernetes

Many new users to OpenFaaS may not know the "origin story" of the project. I developed OpenFaaS in 2016 as I explored how to bring Serverless to containers. I was a Docker Captain back then and wanted to bring containers to new clustering system called *Docker Swarm*. The key difference between software like Docker Swarm and Kubernetes vs Docker containers, is that the former is declarative and the later is used imperatively. A declarative system says: "I want this, can you go off and do it for me?" and an imperative system says "Do exactly this, right now".

I entered OpenFaaS, or "FaaS" as it was called back then to the Dockercon Cool Hacks contest, and won a place to present in the closing keynotes in late April 2017. Since then the project has had a significant, ongoing investment, has changed, grown, and adapted to changes in the industry. What you see before you today is the result of that journey. I sensed that Kubernetes was going to become even more important, so I added in May 2017, just one month after my Dockercon presentation.

Today OpenFaaS runs on Kubernetes much the same as it did in 2017, with a few enhancements:

* HTTP probes are the default for efficient scaling
* Scale to and from zero was added
* CRDs and an operator are available
* A helm chart was developed and is now the community's favourite way to get OpenFaaS
* Stateless microservices became a first-class citizen along with Functions
* Support for secrets
* The "of-watchdog" was developed to enable either STDIO or HTTP to be the interface to your code

Everything deployed with OpenFaaS uses an idiomatic approach, so that things are exactly where you would expect them to be, without magic. For that reason you can use your favourite commands from the [kubectl cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/).

You can [get Kubernetes](https://kubernetes.io/) from your favourite cloud as a service, in your own datacenter, or run it on your laptop.

#### Summing up PLONK

* FaaS or PaaS?

    In the introduction I mentioned that OpenFaaS can be used as a FaaS or a PaaS. I believe that "FaaS" really is only a specialization of PaaS adding in a templating system for creating and managing code. Given how OpenFaaS has changed since it was originally developed, it makes a feature-rich platform for deploying any kind of services.

    <blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">What does it get you? <a href="https://t.co/GrQCrYtKNr">pic.twitter.com/GrQCrYtKNr</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1154385354755125248?ref_src=twsrc%5Etfw">July 25, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

* But are you ready for Serverless?

    I often hear people say to me "we are not ready for Serverless". If you're ready for Kubernetes, then OpenFaaS gives you a lower barrier to entry, a stream-lined developer experience and a passionate community of real users. For me Serverless describes an approach to architecture, rather than some new magic that users can be "ready for", or not.

    Here's an example of how OpenFaaS can save you code on packaging.

    <blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">What does it get you? <a href="https://t.co/GrQCrYtKNr">pic.twitter.com/GrQCrYtKNr</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1154385354755125248?ref_src=twsrc%5Etfw">July 25, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

* Summing up

    It's hard to sum up 3-years of R&D, community interaction, events, blog posts, tutorials, and workshops, but the end result looks something like: PLONK. I hope you'll kick the tires with OpenFaaS if you haven't already, or if you tried it some time ago, will come back and see how much it's improved.

#### Get involved

OpenFaaS is an independent project, hosted by [OpenFaaS Ltd](mailto:sales@openfaas.com). If you would like to support the project you can become a backer or sponsor through GitHub's new Sponsorship program.

<blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">Is there a practical way you can support the project? <a href="https://t.co/1aANvhY0uU">pic.twitter.com/1aANvhY0uU</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1158065047098318848?ref_src=twsrc%5Etfw">August 4, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Become an OpenFaaS Insider through a sponsorship, starting at the cost of a coffee. You'll receive updates on all my OSS work, events, blogs, videos and news about the project.

Connect with the community:

* [Sponsor on GitHub](https://www.openfaas.com/support/)
* [Join Slack now](https://goo.gl/forms/SqpLSdyzVoOboRqs1)
* [Contribute](https://docs.openfaas.com/contributing/get-started/)

You can try OpenFaaS with helm with your favourite Kubernetes service, or on your laptop:

<blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">How can you get it? <a href="https://t.co/mlIEvS0uih">pic.twitter.com/mlIEvS0uih</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1154385446069256192?ref_src=twsrc%5Etfw">July 25, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

If you'd like step-by-step instructions, you can start with [The Official OpenFaaS workshop](https://github.com/openfaas/workshop).
