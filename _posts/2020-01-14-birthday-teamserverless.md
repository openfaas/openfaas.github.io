---
title: "OpenFaaS 3rd Birthday Celebrations"
description: As we celebrate the 3rd OpenFaaS Birthday, I look back over the past three years and towards a 2020 vision
date: 2020-01-14
image: /images/2020-01-14-birthday-teamserverless/cake.png
categories:
  - serverless
  - paas
  - kubernetes
  - kubecon
  - events
author_staff_member: alex
dark_background: true

---

As we celebrate the 3rd OpenFaaS Birthday, I look back over the past three years and towards a 2020 vision

## We're 3!

I started OpenFaaS with [a single commit back in 2016](https://github.com/openfaas/faas/commit/d94cfeb660705028b6c101412a03519a8164712d). Since its inception the community of users and contributors has grown at a steady rate. Join me in this blog post to celebrate the 3rd birthday of OpenFaaS. I'll give a short history of the project, share our online celebration, talk about the future and congratulate the SWAG contest winners. You'll also get a few links at the end on how to get involved in time for our next birthday.

![](/images/2020-01-14-birthday-teamserverless/stats.jpg)

*Thank you to [Iheb](https://twitter.com/iboonox/) for this graphic.*

### A short history

Back in 2016 I wanted to explore Serverless and started out with AWS Lambda, it worked well, but I wanted a way to run my functions on my own hardware using Docker containers. My first attempt was called [funker-dispatch](https://github.com/alexellis/funker-dispatch), which built upon some prior art by a Docker employee and was written in Node.js. I quickly hit the limits of funker and so went back to the drawing-board. [Justin Cormack](https://twitter.com/justincormack) from Docker invited me to the Cambridge office for a day and we brainstormed some ideas and came up with the ["watchdog" concept](https://docs.openfaas.com/architecture/watchdog/).

The first version was called "faas" (Functions as a Service). faas lived in my personal GitHub account as alexellis/faas, I wrote a blog post about it in 2017, which received a lot of interest and encouraged me to keep pushing: [Functions as a Service (FaaS)](https://blog.alexellis.io/functions-as-a-service/).

> the opportunity felt like a once-in-a-lifetime thing

In mid-2017 I won a competition to present in Dockercon's keynote in Austin and wrote up a [new blog post showing off "faas-cli"](https://blog.alexellis.io/build-and-deploy-with-faas/) - the opportunity felt like a once-in-a-lifetime thing and resulted in me getting a promotion to Principal-level at work.

Shortly after Dockercon, I built [faas-netes](https://github.com/openfaas/faas-netes) which added [Kubernetes](https://kubernetes.io/) support to OpenFaaS. I planned how to tackle the problem over a few days but wrote the code on a Sunday evening in one-shot. I then had the opportunity to present to the CNCF's Serverless Working Group: [OpenFaaS presents to CNCF Serverless workgroup](https://blog.alexellis.io/openfaas-cncf-workgroup/).

> Justin Cormack said "you need to quit your job and work on OpenFaaS full-time"

The [CLI received even more enhancements](https://blog.alexellis.io/quickstart-openfaas-cli/) and shortly before the end of 2017, I flew to my first KubeCon to give a talk on [FaaS and Furious - 0 to Serverless in 60 Seconds, Anywhere](https://www.youtube.com/watch?v=XgsxqHQvMnM). At the following Dockercon in Copenhagen I gave a session in the community theatre which was flooded with people, Justin Cormack said "you need to quit your job and work on OpenFaaS full-time". My wife was supportive of the idea and I began to look for ways to do that.

> "the success of the project was dependent on more than just my personal contributions and it felt great"

As more contributors joined the project, the success of the project was dependent on more than just my personal contributions and it felt great to see new features being developed by the community. In that time we gained a documentation site, got permission to list end-user logos from dozens of companies, event-triggers, spoke at dozens of conferences and collected hundreds of blog posts and tutorials. I also started [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/) - a platform to offer a managed, multi-user experience for teams. The [Community Cluster](https://docs.openfaas.com/openfaas-cloud/community-cluster/) gives free access to developers in the community, and gives a very similar experience to Google's Cloud Run product, but with CI/CD and secrets management built-in.

> Shortly after that the community rallied around and helped me

In early 2018 VMware offered me a job and asked me to come onboard as a Senior Staff Engineer. I built up a small team to continue my work with OpenFaaS whilst retaining rights to the project. I learned a lot over those 12 months and made some good friends, but left in March when the company put their serverless program on hold. One of my highlights was [giving a talk with Vision Banco at KubeCon](https://www.youtube.com/watch?v=mPjI34qj5vU) on how they'd put OpenFaaS intro production for their home-banking service. Shortly after that the community rallied around and helped me launch a new openfaas.com website with a professionally-designed theme and styled-blog.

> I've focused on OpenFaaS Ltd, joined the CNCF Ambassadors and launched new OSS projects

[Since leaving VMware](https://blog.alexellis.io/openfaas-bright-2019/) I've focused on OpenFaaS Ltd which offers Cloud Native consulting, OpenFaaS support, product feedback, and developer-marketing. This past year has also seen me start new projects like [k3sup](https://k3sup.dev) for installing Kubernetes apps and k3s clusters and [inlets](https://inlets.dev/) for tunnelling services out from behind NAT and firewalls. Both projects are complimentary to OpenFaaS and share contributors with the main project.

I spoke on the [PLONK stack for Kubernetes Application Developers](https://blog.alexellis.io/getting-started-with-the-plonk-stack-and-serverless/), if you've ever used or heard of LAMP or MEAN, then PLONK is something you should look into. Since [I joined the CNCF Ambassadors program](https://blog.alexellis.io/joining-the-cncf-ambassadors/), talking about PLONK seems like a good way to help people connect the dots and adopt Kubernetes for applications.

Throughout these past three years, the community of users and contributors has grown as has the [The Pressures of Leadership](https://blog.alexellis.io/the-5-pressures-of-leadership/) and the demands of doing Open Source without sustainable funding. The [GitHub sponsors program](https://insiders.openfaas.io/) is currently funding less than 1 day per month of my time. All individuals who sponsor get exclusive access to weekly digests from me on all my OSS work, blog posts, tutorials and updates for OpenFaaS. 

> I want to thank each one of you that has contributed, especially the Members and Core Team, this project is far too big to do alone and I'm grateful of your help.

I also want to say a thank you to our current OpenFaaS.com homepage sponsors:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">As part of our 3rd Birthday celebrations, we are excited to announce our newest <a href="https://t.co/8vBf3VPKYj">https://t.co/8vBf3VPKYj</a> homepage Sponsor - <a href="https://twitter.com/akashnet_?ref_src=twsrc%5Etfw">@akashnet_</a> <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> <a href="https://twitter.com/hashtag/openfaas3?src=hash&amp;ref_src=twsrc%5Etfw">#openfaas3</a> <a href="https://twitter.com/hashtag/teamserverless?src=hash&amp;ref_src=twsrc%5Etfw">#teamserverless</a><br><br>Checkout their Serverless Supercloud below<a href="https://t.co/kpoVaCrhiv">https://t.co/kpoVaCrhiv</a> <a href="https://t.co/M7aF3fbfpr">pic.twitter.com/M7aF3fbfpr</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/1207231528368889856?ref_src=twsrc%5Etfw">December 18, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Through OpenFaaS Ltd I've worked with several new clients including:

* [Civo](https://civo.com) - helped design and launch a managed k3s service #KUBE100 and build K8s-focused brand & content - [First Impressions of 'Managed K3s' - rancher.com](https://rancher.com/blog/2019/first-impressions-managed-k3s/)
* [Rancher Labs](https://rancher.com) - built content and tooling to enable adoption of k3s [k3sup](https://k3sup.dev/)
* [Equinix Metal](https://metal.equinix.com/) - [IoT drones project](https://github.com/packet-labs/iot) built with MQTT, OpenFaaS, Grafana, Postgresql and a drone simulator to show the value of edge compute and the [5G Sprint Curiosity](https://business.sprint.com/5g/) network
* [DX](https://w.dx.no/) - implementation, R&D, and ongoing commercial support of OpenFaaS Cloud for monolith and green/brown-field microservices at scale
* [Humio](https://www.humio.com/) - DX feedback and product marketplace design for enterprise index-free logging product

OpenFaaS Ltd's first year of business coincided with the OpenFaaS 3rd birthday and that brings us to the video celebration in the next section. 

### It's our birthday!

OpenFaaS 3rd Birthday Celebration!

<iframe width="560" height="315" src="https://www.youtube.com/embed/wXnYx-wD4Zk" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

* I presented my top 5 things from 2019 including PLONK, k3sup, node12 async template and more
* [Martin Dekov](https://github.com/martindekov) showed us the new `npm install` for the faas-cli and other CLI enhancements for making the workflow easier
* [Lucas Roesler](https://twitter.com/theaxer?lang=en) gave us a deep dive on logs and multiple-namespace support
* [Alistair Hey](https://twitter.com/alistair_hey) showed off OpenFaaS Cloud 0.12.0 which adds runtime logs and additional UX enhancements

I'll be planning a number of other community meetings this year. If you have an idea or a project that uses OpenFaaS, or have contributed a feature, then please let me know if you'd like to present.

### SWAG winners

It's not a proper birthday without presents, so as promised, I'll be sending out free swag to the top 5 Tweets with the `#TeamServerless` hashtag during our Birthday week. If you missed out, then you need to be following [@openfaas](https://twitter.com/openfaas) on Twitter so that you're ready for our next promotion.

<blockquote class="twitter-tweet"><p lang="in" dir="ltr">OpenFAAS on a Raspberry Pi 4 using Containerd! <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> <a href="https://t.co/CGHxc7sMdt">pic.twitter.com/CGHxc7sMdt</a></p>&mdash; Mark Sharpley (@MarkSharpley4) <a href="https://twitter.com/MarkSharpley4/status/1208025727238647808?ref_src=twsrc%5Etfw">December 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Open Source Telar Social prerelease demo running on <a href="https://twitter.com/OpenFaaSCloud?ref_src=twsrc%5Etfw">@OpenFaaSCloud</a>. <br>Using Golang, Websocket server,Mongdb,redis<br>Try demo: <a href="https://t.co/aB5hROVIbw">https://t.co/aB5hROVIbw</a><br>A lot of thanks to <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a> for <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> project.<a href="https://twitter.com/hashtag/Serverless?src=hash&amp;ref_src=twsrc%5Etfw">#Serverless</a> <a href="https://twitter.com/hashtag/Social_Media?src=hash&amp;ref_src=twsrc%5Etfw">#Social_Media</a> <a href="https://twitter.com/hashtag/teamserverless?src=hash&amp;ref_src=twsrc%5Etfw">#teamserverless</a> <a href="https://twitter.com/hashtag/faas?src=hash&amp;ref_src=twsrc%5Etfw">#faas</a> <a href="https://twitter.com/hashtag/microservices?src=hash&amp;ref_src=twsrc%5Etfw">#microservices</a> <a href="https://twitter.com/hashtag/FaaSFriday?src=hash&amp;ref_src=twsrc%5Etfw">#FaaSFriday</a> <a href="https://t.co/TEzordQb5l">pic.twitter.com/TEzordQb5l</a></p>&mdash; Amir Movahedi (@qolzam) <a href="https://twitter.com/qolzam/status/1207968055738810369?ref_src=twsrc%5Etfw">December 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Well here&#39;s me staying late at work last night doing some <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> fun, hooking up my home Raspberry Pi to a database in a Kubernetes cluster for monitoring. <a href="https://t.co/9IGPbqJHg4">pic.twitter.com/9IGPbqJHg4</a></p>&mdash; Kai (@KaiPMDH) <a href="https://twitter.com/KaiPMDH/status/1207953778432983040?ref_src=twsrc%5Etfw">December 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Recently, I&#39;ve been playing with <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> and in the process I also wrote couple blog posts about it! Thanks to <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a> for lots of feedback and suggestions. I&#39;m happy to be part of <a href="https://twitter.com/hashtag/openfaas?src=hash&amp;ref_src=twsrc%5Etfw">#openfaas</a> community.<a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> <a href="https://t.co/9M85kmDN2D">pic.twitter.com/9M85kmDN2D</a></p>&mdash; Martin Heinz (@Martin_Heinz_) <a href="https://twitter.com/Martin_Heinz_/status/1207787849384366080?ref_src=twsrc%5Etfw">December 19, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">I’m enjoying being a new contributor to <a href="https://twitter.com/hashtag/openfaas?src=hash&amp;ref_src=twsrc%5Etfw">#openfaas</a>. The contribution guidelines and steps are clear, &amp; the community, starting from <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a>, have been very supportive. I finished workshop yesterday, even submitted an issue &amp; PR for minor edits. Glad to be on <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a>! <a href="https://t.co/M1HsELSncL">pic.twitter.com/M1HsELSncL</a></p>&mdash; frankie (@codegold79) <a href="https://twitter.com/codegold79/status/1207720859907108866?ref_src=twsrc%5Etfw">December 19, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Running <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> on <a href="https://twitter.com/containerd?ref_src=twsrc%5Etfw">@containerd</a> <br>Using it to color a picture of my bestest &quot;best frien&quot;. I miss you!<br>And it&#39;s fast! Video measuring cold start times compared to k8s coming soon!<br>Thanks to <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a> &#39;s guide <a href="https://t.co/ZTAncy49lO">https://t.co/ZTAncy49lO</a> <a href="https://t.co/O8nidtDnkl">pic.twitter.com/O8nidtDnkl</a></p>&mdash; Utsav Anand (@Utsav2Anand) <a href="https://twitter.com/Utsav2Anand/status/1207775970192572416?ref_src=twsrc%5Etfw">December 19, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

If you'd like to order an OpenFaaS or inlets hoodie or t-shirt, then send an email to [sales@openfaas.com](mailto:sales@openfaas.com) with your size and full address. For UK orders you'll pay via bank transfer (faster payments) and for world-wide via PayPal.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">sunday work from home sessions with <a href="https://twitter.com/Bmenzalji?ref_src=twsrc%5Etfw">@Bmenzalji</a> be like <a href="https://t.co/LBwqa0vrHq">pic.twitter.com/LBwqa0vrHq</a></p>&mdash; Greg Osuri (@gregosuri) <a href="https://twitter.com/gregosuri/status/1216500425181913088?ref_src=twsrc%5Etfw">January 12, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Here's a couple of our happy customers with their hoodies shipped all the way to San Francisco.

### What's next for OpenFaaS?

As you'll hear at the end of the video, I'm inviting you to help us drive the roadmap for OpenFaaS. I'll be compiling a 2020 vision along and spending time with the OpenFaaS Members and Core team to condense that down into a roadmap and a "compass bearing".

After getting some initial feedback we're considering SDKs for the OpenFaaS REST API to enable enterprise teams to integrate with ease, request-signing from asynchronous invocations and event-triggers to enable non-repudiation for fintech and banking customers, an API for long-running batch-jobs, and improvements to OpenFaaS Cloud's bootstrap process. We'll also continue to explore [faasd](https://github.com/alexellis/faasd) which combines [containerd](https://containerd.io) and CNI to build an efficient and fast functions platform without the need for Kubernetes and clustering.

OpenFaaS Ltd is now hosting the project, covering any costs, providing commercial support, and building commercial add-ons for enterprise users.

The first three products are: 

* [Commercial support](https://github.com/openfaas/faas/blob/master/BACKERS.md#sponsor-plus-packages) which offers backlog and PR prioritization, support via e-mail, and implementation of OpenFaaS / OpenFaaS Cloud.

* [OIDC / OAuth2 plugin](https://docs.openfaas.com/reference/authentication/#oauth2-support-in-the-api-gateway-commercial-add-on)

    The plugin provides OIDC Connect / OAuth2 authentication for the gateway UI, CLI, and for CI/CD. It comes with first-class support for Auth0 and GitLab IDPs and has been used by some early customers to integrate with LDAP.

* [inlets-pro](https://inlets.dev)

    [Inlets PRO](https://inlets.dev) builds upon the success of [inlets](https://github.com/inlets/), the open-source tunnel for HTTP/s traffic enabling companies to tunnel and proxy L4 TCP traffic such as databases, TLS, and SSH.

The aim of commercial software is to contribute towards the huge R&D costs involved in running a project like OpenFaaS which has been adopted by dozens of companies in production. The first two products have a clear enterprise target market and don't take functionality away or restrict the experience for community developers. We will continue to support multi-arch Docker images expanding automation and support for ARMHF and ARM64.

In 2020, OpenFaaS Ltd will also explore commercial add-ons for OpenFaaS Cloud and look into a hosted version of OpenFaaS Cloud. If there are features you'd like to see, or could use at work, then please do reach out.

Beyond 2020, I'd like to develop the OpenFaaS Ltd business and hire full-time staff to maintain and support the project for customers and the community, whilst continuing to explore opportunities to improve the open source and serverless ecosystem for Kubernetes and Cloud Native.

### Make a resolution you can keep

Since we're still in January you are still allowed to make one or two new resolutions, especially if they're ones you can keep. Why don't you start by trying out OpenFaaS and join the Slack community? OpenFaaS with PLONK covers both microservices and functions and makes Kubernetes easier to approach by providing a slick developer experience and sane defaults.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Happy New Year from the OpenFaaS Community.<br><br>Join us on Slack to make a resolution that you can keep. <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> <a href="https://twitter.com/hashtag/k8s?src=hash&amp;ref_src=twsrc%5Etfw">#k8s</a> <a href="https://t.co/fhO1w9uKJ7">https://t.co/fhO1w9uKJ7</a> <a href="https://t.co/wQaxxpdunM">pic.twitter.com/wQaxxpdunM</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/1217107491206680578?ref_src=twsrc%5Etfw">January 14, 2020</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

* PLONK is a Cloud Native stack that combines Prometheus, Linux, OpenFaaS, NATS and Kubernetes to build an application stack for developers

    [Watch my PLONK video from the Serverless Practitioners Summit at KubeCon](https://blog.alexellis.io/getting-started-with-the-plonk-stack-and-serverless/)

* Try the OpenFaaS workshop

    The workshop is a hands-on set of labs for building functions and services on Kubernetes with OpenFaaS:
    
    [openfaas/workshop](https://github.com/openfaas/workshop)

* k3sup - ketchup

    k3sup is a super easy way to get started with Kubernetes using k3s, or to install popular apps packaged with helm, for instance: openfaas, nginx-ingress, kubernetes-dashboard, istio, linkerd, minio, postgresql, inlets-operator, and many more. Each app can be automated with a single command such as `k3sup app install metrics-server`

    [Download k3sup now](https://k3sup.dev/)

Are you already an OpenFaaS user? Do you need CI/CD and somewhere to host your functions? Checkout [The OpenFaaS Community Cluster](https://github.com/openfaas/community-cluster/)

## Join our community

Feel free to reach out if you need help with any cloud native problems you're trying to solve, or if you could use an external perspective on what you're building from OpenFaaS Ltd: [alex@openfaas.com](mailto:alex@openfaas.com). If you'd like to amplify your brand in 2020, then check out the [support and sponsorship options](https://openfaas.com/support).
