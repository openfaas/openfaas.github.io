---
title: My Journey Contributing To The OpenFaaS Community So Far
description: "Nitishkumar shares his experience of working in the OpenFaaS community"
date: 2022-01-30
image: /images/kubernetes-operator-crd/pexels-asphalt-blue-sky-clouds-490411.jpg
categories:
  - faasd
  - certifier
  - openfaas
author_staff_member: nitishkumar
dark_background: true
---

Nitishkumar shares his experiences from contributing code to OpenFaaS and joining the community.


## How I Came to Know about OpenFaaS
When you work in a product startup the first pressing issue is to deliver a minimum viable product with the ability to quickly release the new versions. Once you have that, you start working on reducing the cost, optimizing for scale, etc. We too were in the later phase and we had two pressing issues.

* Deploy entire product suite in the client environment. As data can't go out of the client environment. Client infrastructure could be cloud/on-prem based. 
* There were a lot of internal services which didn't have much load. We wanted to reduce the additional up and running cost for them.

If you have heard about cloud-native, you already know what is the answer for those 2 issues. The first one can easily be solved by Kubernetes. Any Kubernetes based serverless framework can solve the second issue. It was simple, wasn't it? Let me assure you it's not that simple. Once you have a product there will be always some new requirements and bug fixes with higher priority from clients.

As our team was not an expert in Kubernetes, we were not in a position to support a full migration to Kubernetes quickly. This brought us to the conclusion that we can not solve both problems together. We started to look at a serverless framework that can work on standard VM and Kubernetes. After a lot of research OpenFaaS was the best candidate for us. OpenFaaS provides multiple faas engine-based implementation for different environments to support client requirements. The best part is that developer experience is the same in any environment, which has been always the key focus in openfaas community.

* [faas-netes](https://github.com/openfaas/faas-netes) for Kubernetes
* [faasd](https://github.com/openfaas/faasd) for Standard virtual machine, Raspberry pi or home system
* [faas-swarm - Deprecated](https://github.com/openfaas/faas-swarm) for Docker Swarm

The team selected faas-swarm to migrate our services in serverless architecture which saved us quite a few bucks. When the time came to deploy the same services on Kubernetes there was no effort at all except changes in the deployment environment. Now when I look back, I feel we can have easily gone with faasd and moved to Kubernetes when required. The unique value of openfaas is to focus on developer experience and this is what brought me to the community.

## How I started to contribute
This is the biggest problem for any new contributor. The new contributors want to contribute something quickly anyhow. This is where it goes wrong. Before contributing to a project, we need to understand how it works internally and the entire ecosystem on which it's built. The easiest way to begin would be to start building something using a project. This will help to identify something which you would like to improve in the project. In my case, the first contribution came into [Arkade](https://github.com/alexellis/arkade) that too after more than 4-5 months. Arkade makes it easy to download favorite CLI tools and helm charts using a single command. Using Arkade setting up a development environment can be done quickly. Follow the [post](https://www.openfaas.com/blog/openfaas-arkade/) to know more about Arkade.

My initial contributions were just some version upgrades for the apps already supported by Arkade. After a while when I became more comfortable with code. I was able to add some new apps and tools into arkade. While using arkade I started to explore other projects from openfaas. After playing a bit with them, I was able to do some minor contributions to it.

## How is it going

Recently I have been contributing mostly to faasd. If you want to know more about faasd and what solutions you can build from it then [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) is the best book for it. Although, mentioned use-cases are just a glimpse of what can be done from it. There are much more use-cases you can solve out of it.

So coming back, One of the key contributions I made was to enable multiple namespace support into faasd which is already available in faas-netes. It allows users to separate their functions based on the use-case. You would prefer to use a different namespace If you want to keep your development and production environment separate from each other. If you have some functions for home automation and another few functions to manage business for a small store. You would definitely like to separate them into different namespaces.


![](/images/2022-01-30-my-journery-in-openfaas/faasd-with-multiple-namespace.png) 

Deploying and invoking functions into multiple namespaces is quite easy with the help of faas-cli. I am gonna show how you can make a namespace available for functions deployment. I will skip how to set up faasd and deploy functions, as there a plenty of material available for the same as well it's briefly explained into [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else). Assuming you have faasd setup already done in local.

### Create and Label the namespaces
Labeling the namespace is important. This will make sure that faas components are only working on the intended namespaces. We will use `ctr` CLI from containerd for the same. The faasd installation will take care of the installation for all the required tools.
```
sudo ctr namespace create dev-home
sudo ctr namespace create prod-home
sudo ctr namespace label dev-home openfaas=true
sudo ctr namespace label prod-home openfaas=true
```

That's all you need. From here on all the steps are common for deployment/invoke/list/remove functions as you are doing in faas-netes with multiple namespaces. You can use any community supported [templates](https://github.com/openfaas/templates) or build your own templates to deploy your function. You can use the book [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) to explore more.

Additionally I have been contributing to [Certifier](https://github.com/openfaas/certifier). Certifier can be used to validate the installation of openfaas supported faas-providers. Since faasd and faas-netes are the active providers, Certifier supports both of them. Sometimes I even use to test e2e after some major changes into faasd to be sure that everything is working as expected.

## Wrapping Up

If you are willing to contribute to open source projects, then begin with one which you are using or have used in past. Don't rush to contribute. First, explore the internal working of the project to understand it. Attend the community meetings to get better visibility of what is happening in the project. After these, you will find yourself contributing to it within some time. We are also looking for contributors for the OpenFaaS community. If you are using any OpenFaaS providers, we would be happy to have you in the community. Even if you are not using any OpenFaaS providers but want to contribute, please feel free to join the community.