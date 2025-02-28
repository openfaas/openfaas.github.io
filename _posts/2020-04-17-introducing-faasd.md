---
title: "Meet faasd - portable Serverless without the complexity of Kubernetes"
description: "In this post Alex will introduce OpenFaaS' newest project: faasd - faasd brings the benefits of a portable Serverless experience without needing to learn and operate Kubernetes"
date: 2020-04-17
image: /images/2020-02-27-ofc-private-cloud/private-cloud-servers.jpg
categories:
  - microservices
  - kubernetes
  - serverless
  - containerd
author_staff_member: alex
dark_background: true

---

In this post Alex will introduce OpenFaaS' newest project: faasd. faasd brings the benefits of a portable Serverless experience without needing to learn and operate Kubernetes.

## Portable and open

From the first iteration of OpenFaaS in 2016 (then called "faas"), portability and openness were two driving values for the project and community. They've guided us ever since, and as the industry consolidated around Kubernetes, we added support in the project. That was back in May 2017.

<img src="https://raw.githubusercontent.com/openfaas/media/master/OpenFaaS_Magnet_3_1_png.png" width="400" alt="Workshop logo" />

The [faas-provider](https://github.com/openfaas/faas-provider) SDK allowed us to do this and was extracted from the core project shortly after adding support for Kubernetes. We've had a number of other community providers, but this is the one with the most traction today.

> It's my current opinion that Kubernetes is the best way to run OpenFaaS in production for everything from the edge to the very largest deployments.

After several years of working with Kubernetes and similar technology, I've become numb to its complexities and that makes me a bad judge of whether it's easy to use or not. OpenFaaS aims to abstract away the repetitive nature of YAML files and to add value through its API and ecosystem.

[As a consultant and CNCF Ambassador](https://www.alexellis.io/), I believe that teams need to use the right tool for the job, and that's not always the most powerful and featureful. I wrote about a tiered approach starting with managed services, then containers, then orchestrated containers in: [Your team might not need Kubernetes](https://medium.com/faun/your-team-might-not-need-kubernetes-57240e8d554a).

## Announcing "Serverless For Everyone Else"

![faasd ebook and workshop](https://pbs.twimg.com/media/EshzOvLUYAUbCxw?format=jpg&name=medium)

I've released my first eBook and video workshop called "Serverless For Everyone Else", in the book I cover how to build your own self-hosted Serverless Functions without needing AWS IAM or Kubernetes. It can run on commodity hardware like a Raspberry Pi or DigitalOcean Droplet.

In the labs you'll learn how to deploy faasd, how to use the OpenFaaS UI, CLI and REST API (via `curl`). The book then chances pace into hands-on labs with Node.js where you get to build out functions to query HTTP APIs, add npm modules, configure behaviour with environment variables and then add secrets. To top if off, you write a small CRUD API with Postgresql - all on the same host. The second half of the book concentrates on operational concerns like setting up TLS, or a HTTPS tunnel when you're running behind a firewall and gives detailed instructions on monitoring your functions.

[Check it out on Gumroad](http://store.openfaas.com/l/serverless-for-everyone-else)

## "But there's servers in serverless!"

We'll often hear cries of "But there's servers in serverless!" and this tends to come not from the Cloud Native community, but from users of managed services like AWS Lambda, Heroku and similar.

<img src="/images/2020-faasd-intro/meme.jpg" width="300" alt="Meme">

We all know that "cloud" was never a literal term, it's abstract and there are no actual computers floating in the sky. Perhaps they've not even used technology like Docker yet?

> I believe these comments come from a position of fear, and I would be scared too. I remember the first time I used Kubernetes.

Imagine if you needed "just a few functions" written in something like Golang or Node.js. How does OpenFaaS stack up to a fully managed platform like Heroku? Whilst option equates to "git push" and you're done, the other asks you to learn the basics of Docker and Kubernetes.

![k3s logo](https://img.stackshare.io/service/10432/logo-k3s.png)

So what about [k3s](https://k3s.io/)? I'm a big fan of Darren's work with k3s and I believe he was able to get so much interest in the project simply by inferring that it would be easier to use.

It turns out that k3s nailed the bootstrap process and has dramatically reduced the memory footprint vs [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/), but it's still upstream Kubernetes and it does not intrinsically make the day to day any easier.

## Enter faasd

[faasd](https://github.com/openfaas/faasd) was built specifically to address the complexity of the CNCF ecosystem and of Kubernetes.

![CNCF technology](/images/2020-faasd-intro/ofctr.png)

We didn't throw the baby out with the bathwater though. faasd uses two CNCF projects that are also used in Kubernetes:

* [containerd](https://github.com/containerd/containerd) with runc - to run functions in containers
* [CNI](https://github.com/containernetworking/cni) - container networking interface - to provide simple, solid networking

faasd doesn't use much more than that. It is distributed as a static binary instead of a Docker image and can be installed via cloud-init or via bash in a matter of minutes.

How have the community responded? Well there's now 9 contributors to the faasd project and indirectly, there's over 250 because faasd uses the exact same components of OpenFaaS. Instead of complicated YAML files and helm charts, faasd references the Docker images we built and push to the Docker Hub.

## How is faasd different from OpenFaaS on Kubernetes?

faasd is for anyone who wants to create an API, function, or microservice.

Parity with OpenFaaS on Kubernetes:

* ✅ [OpenFaaS workloads interface](https://docs.openfaas.com/reference/workloads/)
* ✅ [REST API](https://docs.openfaas.com/architecture/gateway/#swagger)
* ✅ private Docker registries
* ✅ scale to and from zero
* ✅ [async invocations](https://docs.openfaas.com/reference/triggers/#async-nats-streaming)
* ✅ Prometheus metrics
* ✅ logs
* ✅ secrets
* ✅ multi-arch - for both Intel and ARM
* ✅ faas-cli support
* ✅ Function Store and Template Store support
* ✅ compatible with CI and TLS solutions

Differences from Kubernetes:

* ✅ low memory footprint
* ✅ almost immediate scale from zero
* no clustering as of yet, use HA instead
* no HTTP healthcheck support yet
* no commercial OIDC / OAuth2 support

On a Dell XPS with a small, pre-pulled image unpausing an existing function took only 0.19s and a cold start only took 0.39s, without further optimization. It's very difficult to get anywhere near these sorts of cold-start speeds with Kubernetes

As far as HA is concerned, you can deploy faasd in redundancy. You can integrate with CI systems, and you can get TLS by installing a reverse proxy like Caddy or Nginx.

## When should I use faasd?

From [the Deployment docs](https://docs.openfaas.com/deployment/)

> faasd is a light-weight option for adopting OpenFaaS which uses the same tooling, ecosystem, templates, and containers as OpenFaaS on Kubernetes, but which doesn't require cluster management. faasd uses containerd as a runtime and CNI for container networking.

* You want to add some functions to a single-page app, or build a webhook receiver
* You want an easy and portable alternative to AWS Lambda or Azure Functions
* It's a lightweight option and is suited to use-cases such as: appliances, VMs, embedded use, edge, and for IoT.
* Teams may also find faasd useful for local development before deploying to Kubernetes.
* Teams who feel that they could benefit from functions and microservices, but who do not have the bandwidth to learn about Kubernetes may prefer this option.

[Mehdi Yedes](https://twitter.com/mehyedes) recently put together a tutorial for the kind of use-case for which we designed faasd. He also [walked through installing faasd to a Raspberry Pi](https://myedes.io/serverless-on-raspberrypi/) as an edge device, which can make a good alternative to using [k3s](https://k3s.io/).

* [Tracking Stripe Payments with Slack and faasd](https://myedes.io/stripe-serverless-webhook-faasd/)

## How do I get started?

There's multiple ways to deploy faasd, pick whichever suits your needs. The core dependency is a Linux host and we test primarily with the LTS version of Ubuntu.

* Run locally on [MacOS, Linux, or Windows with Multipass.run](https://gist.github.com/alexellis/6d297e678c9243d326c151028a3ad7b9)

* Use cloud-init on any IaaS or cloud platform: [Build a Serverless appliance with faasd](https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/)

* Terraform for DigitalOcean: [Automate everything within < 60 seconds and get a public URL and IP address back](https://gist.github.com/alexellis/fd618bd2f957eb08c44d086ef2fc3906)

* [Get started on armhf / Raspberry Pi](https://blog.alexellis.io/faasd-for-lightweight-serverless/)

## Wrapping up

OpenFaaS is best run on Kubernetes, but this does come with a learning curve and for some teams, an ongoing maintenance cost. Whilst Kubernetes is great for scaling up and scaling out, scaling down can be just as important, and that's where faasd comes into its own.  faasd presents a new option for teams that want to start out with Serverless and keep it both open-source and portable too.

* For production use and scale-out - use OpenFaaS on Kubernetes or k3s
* For local development and edge/Raspberry Pi - use OpenFaaS on k3s or Kubernetes
* Small teams / no-clustering: use faasd

Read more on the [OpenFaaS deployment page](https://docs.openfaas.com/deployment/)

Are you still using Docker Swarm in production?

We hope that faasd could provide a way for us to deprecate support for Docker Swarm, which is currently made available via [faas-swarm](https://github.com/openfaas/faas-swarm).

> If you're using OpenFaaS with Swarm in production, I'd strongly suggest that you get in touch to discuss your requirements: [support@openfaas.com](mailto:support@openfaas.com).

### You're not on your own!

We're here to help you, and if you need more than can be offered by the community, [OpenFaaS Ltd](mailto:sales@openfaas.com) offers reassurance and consulting services.

### Connect with the community

* Get a head-start with OpenFaaS with our [Official Workshop](https://github.com/openfaas/workshop).

Do you have questions, comments or suggestions? Tweet to [@openfaas](https://twitter.com/openfaas).

> Want to support our work? You can become a sponsor as an individual or a business via GitHub Sponsors with tiers to suit every budget and benefits for you in return. [Check out our GitHub Sponsors Page](https://github.com/sponsors/openfaas/)
