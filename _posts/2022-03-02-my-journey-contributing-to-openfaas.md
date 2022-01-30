---
title: My Journey Contributing To OpenFaaS So Far
description: "Nitishkumar shares his experiences from using OpenFaaS at work, to becoming a community contributor."
date: 2022-03-02
image: /images/2022-contributing/background.jpg
categories:
  - faasd
  - case-study
  - certifier
  - contributing
  - community
author_staff_member: nitishkumar
dark_background: true
---

Nitishkumar shares his experiences from using OpenFaaS at work, to becoming a community contributor.

In this short post, I'm going to tell you a bit about how I found out about openfaas, what my team did with it at work, and then how I've been involved as a contributor. Finally, I'll give you some tips for getting started. Contributing to open source can be really rewarding and it also helped with my own career development.

## How I Came to Know about OpenFaaS

My first experience with OpenFaaS was at the start-up I was working at AthenasOwl.

When you work in a startup, the first pressing issue is to deliver a minimum viable product (MVP). As part of that, you also need to be able to iterate quickly and release new versions to early customers often. Once you have that set up, you may then start thinking about efficiency and optimizing. for us that was: working on reducing the cost for scaling out.

We had two pressing issues:

* We needed to deploy the whole suite of products into a client's environment. This was because the client's data couldn't leave their on-premises environment, for regulatory reasons.
* There were a lot of internal services which didn't have much load, so we wanted to reduce the additional up and running cost for them.

We were well versed with Cloud Native and saw it as the answer. The first issue can be solved by Kubernetes, by allowing our code to run on the cloud and on-premises. For the second issue, we needed a serverless framework, built for Kubernetes.

It sounded simple, but it wasn't. Once you have a product there will be always some new requirements and bug fixes with higher priority from clients.

> As our team was not an expert in Kubernetes, we were not in a position to support a full migration to Kubernetes quickly. This brought us to the conclusion that we can not solve both problems together.

We started to compare different serverless frameworks - both those that target Kubernetes, and those that can run on a VM. And after countless hours of research, we concluded that OpenFaaS was the best fit for us. But why? OpenFaaS provides targets for deployment, meaning it's able to suit different client requirements - both with and without Kubernetes. The best part was that developer experience is the same. From the outside, looking it - it was clear that the community spent time focusing here.

OpenFaaS has a provider model. That's what enables Kubernetes or plain old VMs to be used for functions:

* [faas-netes](https://github.com/openfaas/faas-netes) is for teams on Kubernetes
* [faasd](https://github.com/openfaas/faasd) is for a regular virtual machine, bare-metal host or Raspberry Pi
* [faas-swarm](https://github.com/openfaas/faas-swarm) has been deprecated, but enabled Docker Swarm to be used for functions

The team selected faas-swarm to migrate our services in serverless architecture which saved us quite a few bucks. When the time came to deploy the same services on Kubernetes there was no effort at all except changes in the deployment environment. Now when I look back, I feel we can have easily gone with faasd and moved to Kubernetes when required. The unique value of openfaas is to focus on developer experience and this is what brought me to the community.

## How I started to contribute

I think that the biggest problem for any new contributor is getting started and plugged into the community. Where do you even start?

As a new contributor, I wanted to contribute something quickly - whatever it was and that's actually where it can go wrong. Some people believe that before contributing to a project, we have to understand how it works internally and the entire ecosystem on which it's built.

I used to think that way, but now I know that the easiest way to begin is to start using the project and building something with it. This helped me identify something to improve in the project and meant I could give good feedback to the maintainers. In my case, the first contribution came into [Arkade](https://github.com/alexellis/arkade) which OpenFaaS uses as an installer for Kubernetes. It's a Kubernetes marketplace, and I improved a number of apps, then was asked to fix a few problems, you can [see my changes here](https://github.com/alexellis/arkade/pulls?q=nitishkumar71).

I use arkade to get my Kubernetes environments set up quickly and to download all the various CLIs that I need for development.

To begin with, I started bumping versions of components in the marketplace. Then after a while when I became more comfortable with code, I was able to add some new apps and tools and see developers using them! While using arkade I started to explore other projects from openfaas. After playing a bit with them, I was able to contribute to them in a similar way.

You see, it doesn't have to be complicated. You don't need to know everything. I was just able to start by changing a version of something and help the maintainers out that way.

## How is it going

Recently I have been contributing mostly to faasd, which I mentioned earlier is OpenFaaS for VMs for bare-metal, without Kubernetes. If you want to know more about faasd and what solutions you can build from it then [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) (written by Alex) is the best book for it. Although, mentioned use-cases are just a glimpse of what can be done from it. There are much more use-cases you can solve out of it.

So coming back, One of the key contributions I made was to enable multiple namespace support into faasd which is already available in faas-netes. It allows users to separate their functions based on the use-case. You would prefer to use a different namespace If you want to keep your development and production environment separate from each other. If you have some functions for home automation and another few functions to manage business for a small store. You would definitely like to separate them into different namespaces.

![Multiple namespaces in faasd](/images/2022-01-30-my-journery-in-openfaas/faasd-with-multiple-namespace.png) 
> Multiple namespaces in faasd

Deploying and invoking functions into multiple namespaces is quite easy with the help of [faas-cli](https://github.com/openfaas/faas-cli). I am gonna show how you can make a namespace available for functions deployment. I will skip how to set up faasd and deploy functions, as there a plenty of material available for the same as well it's briefly explained into [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else). Assuming you have faasd setup already done in local.

### Create and Label the namespaces

Labeling the namespace is important. This will make sure that faas components are only working on the intended namespaces. We will use `ctr` CLI from containerd for the same. The faasd installation will take care of the installation for all the required tools.

```bash
sudo ctr namespace create dev-home
sudo ctr namespace create prod-home
sudo ctr namespace label dev-home openfaas=true
sudo ctr namespace label prod-home openfaas=true
```

That's all you need. From here on all the steps are common for deployment/invoke/list/remove functions as you are doing in faas-netes with multiple namespaces. You can use any community supported [templates](https://github.com/openfaas/templates) or build your own templates to deploy your function. You can use the book [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) to explore more.

Additionally I have been contributing to [Certifier](https://github.com/openfaas/certifier). Certifier can be used to validate the installation of openfaas supported faas-providers. Since faasd and faas-netes are the active providers, Certifier supports both of them. Sometimes I even use to test e2e after some major changes into faasd to be sure that everything is working as expected.

## Wrapping Up

I think that if you are willing to contribute to open source projects, then begin with one which you are using or have used in past. But don't rush to contribute.

First, explore the internal working of the project to understand it. Attend the community meetings to get better visibility of what is happening in the project. After these, you will find yourself contributing to it within some time. Alex and Lucas really supported me through my contributions, and the more I put in, the more they helped me and gave me opportunities to grow. Alex mentioned that we're always looking for people to contribute and to help us maintain OpenFaaS, but also [arkade](https://arkade.dev), [k3sup](https://k3sup.dev/), [Derek](https://github.com/alexellis/derek) and the many other initiatives that make up the ecosystem.

We're pretty sure we can find something interesting for you to do, so get in touch.

### The story of the OpenFaaS community over the past 60 months

There's been 340 people that have contributed to OpenFaaS over the past 5 years, many of them self a sense of belonging and benefited in their career development too.

Alex tells the story of [OpenFaaS over the past 60 months at Gophercon](https://www.youtube.com/watch?v=QzwBmHkP-rQ):

{% include youtube.html id="QzwBmHkP-rQ" %}

Feel free to check out some of the links we've mentioned below:

* [OpenFaaS Weekly Office Hours](https://github.com/openfaas/faas/issues/1683)
* [OpenFaaS eBook for learning faasd and getting started](https://store.openfaas.com/l/serverless-for-everyone-else)
* [OpenFaaS certifier](https://github.com/openfaas/certifier)
* [arkade](https://github.com/alexellis/arkade)
