---
title: "Our KubeCon San Diego Highlights"
description: We share our highlights from the OpenFaaS community and friends at KubeCon, San Diego including OpenFaaS Cloud, Flux from Weaveworks, Dive from Buoyant and k3s going GA.
date: 2019-11-26
image: /images/2019-kubecon-san-diego/background.jpg
categories:
  - serverless
  - paas
  - kubernetes
  - kubecon
  - events
author_staff_member: alex
dark_background: true

---
We share our highlights from the OpenFaaS community and friends at KubeCon, San Diego including [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud/), [Flux](https://github.com/fluxcd) from [Weaveworks](https://www.weave.works), [Okteto](https://okteto.com), Dive from [Buoyant](https://buoyant.io) and [k3s](https://k3s.io) going GA.

## Saturday @ Cloud Native Rejekts

It was my first time at the [Cloud Native Rejekts](https://cloud-native.rejekts.io) pre-conference and I would highly recommend it. [Kinvolk](https://kinvolk.io) started the event as a way of giving speakers with rejected talks a way to recycle their hard work. I met Chris Kuehl on the first day and he also told me that the event also offers people a way to share ideas and projects which came about after the KubeCon CfP closes. I think that this is something the main event should also consider.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Come and get an <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> sticker and <a href="https://twitter.com/inletsdev?ref_src=twsrc%5Etfw">@inletsdev</a> at the sticker exchange over at <a href="https://twitter.com/rejektsio?ref_src=twsrc%5Etfw">@rejektsio</a> <a href="https://t.co/fsHfoOAqX2">pic.twitter.com/fsHfoOAqX2</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1195828490290860032?ref_src=twsrc%5Etfw">November 16, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

I dropped some brand-new inlets swag and OpenFaaS #TeamServerless stickers off at the event.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Come to my session at 16:30 at <a href="https://twitter.com/rejektsio?ref_src=twsrc%5Etfw">@rejektsio</a> to hear about <a href="https://twitter.com/inletsdev?ref_src=twsrc%5Etfw">@inletsdev</a> 😎🌮 <a href="https://t.co/K2bOhpinQG">pic.twitter.com/K2bOhpinQG</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1195821181305118721?ref_src=twsrc%5Etfw">November 16, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The event was held in a museum set within [Balboa Park](https://www.balboapark.org) and the organisers put on Tacos for the attendees. I loved the ambience of the area and it reminded me of the time we were [in Barcelona for KubeCon EU](https://www.openfaas.com/blog/meet-us-at-barcelona/).

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">&quot;Kubernetes is kind of already a service mesh&quot; 🤯🤯<a href="https://twitter.com/rejektsio?ref_src=twsrc%5Etfw">@rejektsio</a> <a href="https://twitter.com/CloudNativeFdn?ref_src=twsrc%5Etfw">@CloudNativeFdn</a> <a href="https://twitter.com/kubernetesio?ref_src=twsrc%5Etfw">@kubernetesio</a> <a href="https://twitter.com/thockin?ref_src=twsrc%5Etfw">@thockin</a> <a href="https://t.co/h8mnTAXWaG">pic.twitter.com/h8mnTAXWaG</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1195828744318939136?ref_src=twsrc%5Etfw">November 16, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

We also got treated to a "state of Kubernetes" talk by Tim where he explored topics like the need for Ingress v2 and how Kubernetes is already a service mesh of sorts.

### inlets-operator - get tunnels to your Kubernetes cluster

On Saturday I spoke on the issues we face as IPv4 addresses run out from the original pool of 4 Billion. IPv6 was supposed to fix this problem, but 25 years later, it's still not ready to take over.

I introduced and demoed both inlets and the inlets-operator which give incoming network access (ingress) to any Kubernetes cluster whether on premises or within a restrictive VPC. This is achieved by the client making an outbound network request over a known port such as 80, 8080, or 443 to establish a long-running uplink.

View the slides below, and subscribe to my Twitter handle for a notification of when the video is ready.

<iframe src="//www.slideshare.net/slideshow/embed_code/key/5CIkLdzheA7P1" width="595" height="485" frameborder="0" marginwidth="0" marginheight="0" scrolling="no" style="border:1px solid #CCC; border-width:1px; margin-bottom:5px; max-width: 100%;" allowfullscreen> </iframe> <div style="margin-bottom:5px"> <strong> <a href="//www.slideshare.net/AlexEllis11/still-waiting-for-ipv6-try-the-inletsoperator" title="Still waiting for IPv6? Try the inlets-operator" target="_blank">Still waiting for IPv6? Try the inlets-operator</a> </strong> from <strong><a href="https://www.slideshare.net/AlexEllis11" target="_blank">Alex Ellis</a></strong> </div>

inlets is proud to be featured on the CNCF Landscape

Get started with either of the tools I demoed: [inletsctl](https://github.com/inlets/inletsctl) or [inlets-operator](https://github.com/inlets/inlets-operator) for Kubernetes automation.

## Serverless Practitioners Summit

The second pre-conference I attended was the [Serverless Practitioners Summit](https://www.cncf.io/events-well-be-at/serverless-practitioners-summit-2019/) (SPS). Leading up to the event I'd had the opportunity to help review papers and organise the event. [Doug Davis](https://github.com/duglin) from IBM hosted the event on the day with [Cloud Foundry](https://www.cloudfoundry.org) sponsoring.

Keep an eye out for the CfP for Amsterdam, these talks do not count against your quota for the main event and can be a great way to mix with subject-matter experts and end-users too.

### Beyond than FaaS - The PLONK Stack for Kubernetes Developers

You can watch my talk where I explore the difference between FaaS and Serverless, and introduce a stack for developers to build out application on Kubernetes.

<iframe width="560" height="315" src="https://www.youtube.com/embed/NckMekZXRt8" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

[Ramiro](https://www.linkedin.com/in/ramiroberrelleza/) gave a talk on accelerating the "hot reload" experience for Kubernetes pods and applied that to OpenFaaS. He used his platform called [Okteto](https://okteto.com), check it out if you could benefit from a live development experience for your applications on Kubernetes.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Looking forward to a demo of this! <a href="https://twitter.com/hashtag/kubecon?src=hash&amp;ref_src=twsrc%5Etfw">#kubecon</a> <a href="https://twitter.com/oktetohq?ref_src=twsrc%5Etfw">@oktetohq</a> <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> <a href="https://t.co/gGHmNFNGoy">pic.twitter.com/gGHmNFNGoy</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1196540671231791104?ref_src=twsrc%5Etfw">November 18, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

You can [watch his recording here](https://www.youtube.com/watch?v=Yx1nGH2zh0k) and I'm looking forward to collaborating more with the team.

## KubeCon 🌮

The North American event this year saw an estimated 12k attendees, making this the largest tech event I've been a part of so far. I was also attending as a CNFC Ambassador for the first time - our main perk was being given a cape to wear!

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Looking serious at <a href="https://twitter.com/hashtag/KubeCon?src=hash&amp;ref_src=twsrc%5Etfw">#KubeCon</a> <a href="https://twitter.com/LachlanEvenson?ref_src=twsrc%5Etfw">@LachlanEvenson</a> <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a> <a href="https://t.co/QIZhMeqgw5">pic.twitter.com/QIZhMeqgw5</a></p>&mdash; Tamao Nakahara @ KubeCon (@mewzherder) <a href="https://twitter.com/mewzherder/status/1197634178004602880?ref_src=twsrc%5Etfw">November 21, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

There were so many concurrent sessions and tracks that scrolling through the agenda for one day could take a few minutes - this isn't your 2014 KubeCon. I imagine this will continue to grow in the coming years. Personally, I spent most of my time in the "hallway track", the expo area, having ad-hoc meetings and attending the keynotes. I did manage to catch a few breakout sessions.

I was excited to see the Open Source team at Intel running a serverless demo at their booth. I asked what they used to built it and they told me it was powered by OpenFaaS.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Great to see <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> used in the <a href="https://twitter.com/intel?ref_src=twsrc%5Etfw">@intel</a> booth for machine learning. <a href="https://t.co/xv4JAn4tBQ">pic.twitter.com/xv4JAn4tBQ</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1196949307804372992?ref_src=twsrc%5Etfw">November 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

How cool is that? You draw boxes and blocks, then a machine-learning model served by OpenFaaS generates a real photo of a building.

### Linkerd and OpenFaaS Cloud for a Secure Multi-tenant Serverless Platform

If you've heard of Linkerd or OpenFaaS, but haven't seen them working together, then check out this talk. I spoke with Charles from Buoyant on security features within OpenFaaS Cloud - some of which are taken directly from Kubernetes at an infrastructure level and others that are applied through the platform. 

<iframe width="560" height="315" src="https://www.youtube.com/embed/sD7hCwq3Gw0" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

OpenFaaS Cloud builds on top of OpenFaaS to provide a managed experience for teams. It can be set up by an SRE or platform engineer and then used by multiple users and teams within the organisation to migrate applications to Kubernetes. CI/CD is built-in along with logs, metrics, and a dashboard.

### Linkerd / Dive.co

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">New from <a href="https://twitter.com/BuoyantIO?ref_src=twsrc%5Etfw">@BuoyantIO</a> - <a href="https://twitter.com/divedotco?ref_src=twsrc%5Etfw">@divedotco</a> <br><br>The control plane for your platform team. <br><br>Fine out more at <a href="https://t.co/TqQLwZqs7y">https://t.co/TqQLwZqs7y</a> <a href="https://t.co/5dA8dLmOIh">pic.twitter.com/5dA8dLmOIh</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1196835627821453313?ref_src=twsrc%5Etfw">November 19, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Whilst out in San Diego I was invited to an end-user and adopters dinner where I learned about [Dive.co](https://dive.co) which is Buoyant's latest venture. You can think of it like an SRE's toolbox mixed with social media - check it out and let the team know if you use Linkerd in production.

Some OpenFaaS users like Istio and others prefer the simplicity of Linkerd. Whichever you prefer, you can try out a set of free hands-on labs: [Lightweight Serverless on Kubernetes with mTLS and traffic-splitting with Linkerd2](https://github.com/openfaas-incubator/openfaas-linkerd2).

### Flux & Argo

Our friends at Weaveworks announced that the Flux project (an incubating project of the CNCF), would merge with the Argo Project developed at Intuit.

[Stefan Prodan](https://stefanprodan.com) who is also an OpenFaaS contributor spoke in a panel on GitOps. The session was so popular that it had to be moved to the main stage, how about that?! Watch the video here: [Panel: GitOps User Stories](https://www.youtube.com/watch?v=ogw6_Y3WBQs)

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Three years of <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> and <a href="https://twitter.com/hashtag/teamserverless?src=hash&amp;ref_src=twsrc%5Etfw">#teamserverless</a> 😎 <a href="https://t.co/4lnb7qZY0C">pic.twitter.com/4lnb7qZY0C</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1197206927094112256?ref_src=twsrc%5Etfw">November 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Myself and Stefan with our OpenFaaS hoodies.

### K3s Under the Hood: Building a Product-grade Lightweight Kubernetes Distro

[Darren Shepherd](https://twitter.com/ibuildthecloud) gave an insightful talk to a packed-out room on what it took to get k3s from a Proof of Concept (PoC) to a GA Kubernetes distribution with commercial support.

> If you've read [my blog](https://blog.alexellis.io/test-drive-k3s-on-raspberry-pi/) you'll know I've done a lot of work with k3s since it launched and how well it works on any architecture - PC, ARM64 or Raspberry Pi.

I live-tweeted my highlights, just click below to view the thread:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">&quot;k3s is specialised to be lightweight and easy to use&quot; <a href="https://twitter.com/ibuildthecloud?ref_src=twsrc%5Etfw">@ibuildthecloud</a> <a href="https://twitter.com/Rancher_Labs?ref_src=twsrc%5Etfw">@Rancher_Labs</a> <a href="https://twitter.com/hashtag/kubecon?src=hash&amp;ref_src=twsrc%5Etfw">#kubecon</a> <a href="https://t.co/JXydPKauSW">pic.twitter.com/JXydPKauSW</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1197643645727330304?ref_src=twsrc%5Etfw">November 21, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

I thought it was notable that:

* k3s runs in 300MB of memory for a server, 50MB for an agent
* only needs a 1000 line patch, vs. 3 million when it started
* uses the same tunnelling library as [inlets.dev](https://inlets.dev/)
* is marketed for edge, but works great on the desktop and for general purpose
* hit [10k stars on GitHub](https://github.com/rancher/k3s) in just a few months

Last but not least, Darren and the team also built out new innovating projects that can be used to make Kubernetes lighter-weight such as [kine](https://github.com/rancher/kine), an interface for how Kubernetes uses etcd.

Watch [his video here](https://www.youtube.com/watch?v=-HchRyqNtkU) and look out for when he mentions [k3sup](https://k3sup.dev) and [Civo Cloud](https://civo.com/)

Did you know that [k3sup ('ketchup')]() can install Kubernetes in < 1 minute on any VM, bare-metal machine or Raspberry Pi? It was great to hear from folks who were using it for their clusters.

The newest feature of k3sup is `k3sup app install` which can get you a production-ready OpenFaaS installation on any Kubernetes cluster in a couple of minutes.

![](https://github.com/alexellis/k3sup/raw/master/docs/k3sup-app-install.png)

It works by wrapping helm charts up in Golang commands and hiding away obscure settings behind CLI flags and parameters.

This is what it looks like in action:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Today I showed <a href="https://t.co/v4Pzmxdhpm">https://t.co/v4Pzmxdhpm</a> as an installer to get <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@OpenFaaS</a> along with cert-manager, Nginx-ingress and a TLS certificate for the gateway.<br><br>The other thing k3sup can do is install k3s and join nodes.<br><br>Would renaming to &quot;ketchup&quot; show it&#39;s not just for k3s? <a href="https://t.co/nwsJsDhfzW">pic.twitter.com/nwsJsDhfzW</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1196607816078745600?ref_src=twsrc%5Etfw">November 19, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Checkout the GitHub repo for issues and to [get started](https://k3sup.dev).

## That's a wrap

I had a great time at the event, learned a lot, made lots of new connections and learned about new use-cases for OpenFaaS. My last highlight was this research from [EMA Research](https://twitter.com/TorstenVolk) that showed OpenFaaS in the top 5 Kubernetes technologies of the year.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Awesome to see <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@OpenFaaS</a> as the 4th top Kubernetes Component in this research. <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> <a href="https://t.co/s1lRxLU7nn">https://t.co/s1lRxLU7nn</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1197061893690552320?ref_src=twsrc%5Etfw">November 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

If you use or are a contributor to the project, you should feel proud.

The next KubeCon event will be [KubeCon EU, Amsterdam](https://events19.linuxfoundation.org/events/kubecon-cloudnativecon-europe-2020/) in 2020.

If you'd like to submit a paper to the Serverless Practioner's Summit or to KubeCon about OpenFaaS, inlets, k3sup, or something else related to these technologies, feel free to get in touch via [alex@openfaas.com](mailto:alex@openfaas.com).

You can connect with the community via the [OpenFaaS Slack](https://slack.openfaas.io/) where we have channels for `#k3sup`, `#inlets`, `#openfaas` and `#openfaascloud`. Looking forward to seeing you there, [on Twitter](https://twitter.com/alexellisuk) or in Amsterdam.

