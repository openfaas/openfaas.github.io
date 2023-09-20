---
title: "How I built Good First Issue bot with OpenFaaS Cloud"
description: In this post Rajat will share what triggered him to write goodfirstissue bot, where was it deployed and how it was an easy decision to move it to OpenFaaS cloud.
date: 2019-09-23
image: /images/good-first-issue/yellow-stone.jpg
categories:
  - bot
  - golang
  - go
  - twitter
author_staff_member: alex
dark_background: true
---
I’d like to introduce you to Rajat Jindal who is our guest-writer for today’s end-user blog post. Rajat will talk about the goodfirstissue bot that he wrote for helping connect first time contributors with open source projects that encourage contributions from first timers.

> Author bio: [Rajat Jindal](https://twitter.com/rajatjindal1983?lang=en-gb) is staff software engineer at a US based cyber security company. He’s working on service delivery team making tools for developers to help them ship their services to production with high quality and velocity.

<img src="/images/good-first-issue/rajat.jpg" width="25%" height="25%" />

### What is a "good first issue"?

A lot of opensource projects are often managed by volunteers who work on these awesome projects during their ```spare``` time and are used by a lot of companies/people for their products/projects. 

Almost all of these projects encourage next generation of contributors to engage in the community and make meaningful contributions by labeling appropriate issues with ```good first issue```. 

These are issues which do not need very deep knowledge of project and are relatively easy to implement. This can be a small bug in implementation, a small new feature or even a documentation change.

### How do new contributors know there is a new ‘good first issue’

Generally the new contributors look for open source project in the language of their choice and then subscribe to events from that project. And when they get the notification of a new issue reported which is ‘good first issue’ they go to the project, and contribute to that issue/project. 

The problem I had with this approach is when you subscribe to the repo, you get notification for not only ALL the issues reported, but also new release, commits, PR’s, wiki updates etc. which can get overwhelming if you want to subscribe to more than one project.


### So what is goodfirstissue bot

```goodfirstissue``` is a github bot, which once installed on repo/org, will notify first time contributors through [@goodfirstissue](https://twitter.com/goodfirstissue) handle. It tweets only when there is an unassigned and open issue which also have a label ```good first issue```. This way you can filter out all the other noise that you get when you subscribe to repo/org directly.

it consists of two parts:

* [A github bot](https://github.com/apps/goodfirstissue) that is installed on org/repo who encourage first time contributors to contribute to their projects. This sends notification to a openfaas function which filters noise and tweet the issue if it qualifies for a ```good first issue```
* [A twitter handle](https://twitter.com/goodfirstissue) that is followed by potential ‘first time contributors’ who can now get real time notification about ```good first issue``` from awesome opensource projects in a variety of different languages.

### Architecture

<img src="/images/good-first-issue/architecture.png" />

### Why did I pick OpenFaaS for the bot?

The first version of goodfirstissue bot was deployed as a webservice on Kubernetes cluster on Digital Ocean. Deployment was easy, but few things were bothering me:

* Manual configuration of my custom domain referencing to loadbalancer created by DO.
* Getting ```https``` endpoint for the service. using https gives more confidence to your users.
* Infrastructure Cost. Once promotional credits were over it was going to cost money to run this cluster. The maintenance of this cluster was also going to cost me time.

Although above could be achieved relatively easily with tools like [cert-manager](https://github.com/jetstack/cert-manager/), but I didn't wanted to get into managing the Kubernetes cluster myself.

While I was collecting feedback on this function, Alex suggested me to change this bot to a function and also made me aware of OpenFaaS community cluster which provided me:

* CI/CD with git pushes
* Free hosting
* Free https endpoint
* Secure Secrets management using Sealed Secrets
* Easy debugging using slack events/bot commands. (this is so awesome !!)
* Easy access to dashboard with pre-created metrics about the function.
* Access to OpenFaaS community to share my experience with them, and learn from their experiences.

### Current Users

Some projects have already opted to install ```goodfirstissue``` bot on their Orgs/Projects and we are working with other community projects to onboard them to ```goodfirstissue``` bot.

one of the glorious moment for me was when goodfirstissue was installed on helm org, and helm core contributor [@mattfarina](https://twitter.com/mattfarina) tweeted about it.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Did you know that <a href="https://twitter.com/goodfirstissue?ref_src=twsrc%5Etfw">@goodfirstissue</a> shares good first issues on some open source projects?</p>&mdash; Matt Farina (@mattfarina) <a href="https://twitter.com/mattfarina/status/1093535027407798272?ref_src=twsrc%5Etfw">February 7, 2019</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

We even got a shoutout from [@alexellisuk](https://twitter.com/alexellisuk/) during the kubecon EU.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Cool <a href="https://twitter.com/goodfirstissue?ref_src=twsrc%5Etfw">@goodfirstissue</a> by <a href="https://twitter.com/rajatjindal1983?ref_src=twsrc%5Etfw">@rajatjindal1983</a> getting a shout-out today at today&#39;s <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> project update at <a href="https://twitter.com/hashtag/kubeconeu?src=hash&amp;ref_src=twsrc%5Etfw">#kubeconeu</a> <a href="https://t.co/27SvCsIDgu">pic.twitter.com/27SvCsIDgu</a></p>&mdash; John McCabe (@mccabejohn) <a href="https://twitter.com/mccabejohn/status/1130372301659283456?ref_src=twsrc%5Etfw">May 20, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

#### List of users 

(generated using [github-app-installations](https://github.com/rajatjindal/github-app-installations))

| Org/User | Repository |
| ------ | ------ |
| [fastify](https://github.com/fastify) | [All](https://github.com/fastify) |
| [asyncapi](https://github.com/asyncapi) | [All](https://github.com/asyncapi) |
| [storyscript](https://github.com/storyscript) | [All](https://github.com/storyscript) |
| [zuzakistan](https://github.com/zuzakistan) | [All](https://github.com/zuzakistan) |
| [tektoncd](https://github.com/tektoncd) | [All](https://github.com/tektoncd) |
| [helm](https://github.com/helm) | [All](https://github.com/helm) |
| [openfaas](https://github.com/openfaas) | [All](https://github.com/openfaas) |
| [rajatjindal](https://github.com/rajatjindal) | - [github-app-installations](https://github.com/rajatjindal/github-app-installations)<br/>- [goodfirstissue](https://github.com/rajatjindal/goodfirstissue) |
| [pmlopes](https://github.com/pmlopes) | [vertx-starter](https://github.com/pmlopes/vertx-starter) |
| [citrusframework](https://github.com/citrusframework) | - [citrus](https://github.com/citrusframework/citrus)<br/>- [citrus-db](https://github.com/citrusframework/citrus-db)<br/>- [citrus-simulator](https://github.com/citrusframework/citrus-simulator) |
| [alexellis](https://github.com/alexellis) | - [derek](https://github.com/alexellis/derek)<br/>- [github-exporter](https://github.com/alexellis/github-exporter)<br/>- [inlets](https://github.com/alexellis/inlets)<br/>- [minikube-operator](https://github.com/alexellis/minikube-operator)<br/>- [ubiquitous-octo-guacamole](https://github.com/alexellis/ubiquitous-octo-guacamole) |
| [google](https://github.com/google) | [go-github](https://github.com/google/go-github) |
| [reactiverse](https://github.com/reactiverse) | [es4x](https://github.com/reactiverse/es4x) |
| [jetstack](https://github.com/jetstack) | [cert-manager](https://github.com/jetstack/cert-manager) |
| [nut-tree](https://github.com/nut-tree) | - [nut.js](https://github.com/nut-tree/nut.js)<br/>- [secrets](https://github.com/nut-tree/secrets)<br/>- [trailmix](https://github.com/nut-tree/trailmix) |
| [sakuli](https://github.com/sakuli) | [sakuli](https://github.com/sakuli/sakuli) |
| [Ewocker](https://github.com/Ewocker) | [vue-lodash](https://github.com/Ewocker/vue-lodash) |

### Limitations

* At the time of this writing, `goodfirstissue` bot relies on the owner of project/org to enable webhooks for sending push notifications when issues are created/updated.
* It does not tweet about onboarding of new projects. It will be nice, as a follower of this twitter account, to know which new projects will start sending `goodfirstissue` issues our way.

### Future Enhancements

* Ability to poll for events in a scalable way for projects that support `goodfristissue` but are reluctant to install too many webhook integrations on the project/org.
* Ability to publish metrics around how many `goodfirstissue` were tweeted, how many contributors actually benefited from it. And we can do these metrics along a few dimensions like Programming language, UI/Backend/Infra etc. 

### Wrapping up

The goal of ```goodfirstissue``` bot is to connect first time contributors with great projects giving opportunity to learn and contribute and we recently crossed 100 followers on twitter account.

* If you are maintainer of an open source project, we would highly appreciate you considering [installing](https://github.com/apps/goodfirstissue) this on your org/project.
* If you are new to open source community and looking for a starting point, consider following [@goodfirstissue](https://twitter.com/goodfirstissue).
* If you like this project, it will encourage us if add a star to the [repo](https://github.com/rajatjindal/goodfirstissue). (we are one star away from first magical number `10`).
* You can also follow [Rajat Jindal](https://twitter.com/rajatjindal1983) who is your fellow "first time contributor".

### Acknowledgements

Many thanks to [@alexellisuk](https://twitter.com/alexellisuk/) for helping me write, build and deploy this [@openfaas](https://twitter.com/openfaas/) function to openfaas-cloud.

### Join the community

The OpenFaaS community values are: developers-first, operational simplicity, and community-centric.

If you have comments, questions or suggestions or would like to join the community, then please [join us on the weekly Office Hours call](https://docs.openfaas.com/community/).

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

### You may also like:

* [Introducing the Kubernetes Operator and CRD](/blog/kubernetes-operator-crd/)
* [Build a single page app with OpenFaaS Cloud](/blog/serverless-single-page-app/)
* [Sailing through the Serverless Ocean with Spotinst & OpenFaaS Cloud](https://spotinst.com/blog/2019/03/25/sailing-through-the-serverless-ocean-with-openfaas-cloud/)
