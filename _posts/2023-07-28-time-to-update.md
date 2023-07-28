---
title: "As OpenFaaS continues to elove, it's time to update your images"
description: "We've been doing some housekeeping with old container images, so it's time to update your OpenFaaS installation."
date: 2023-07-28
categories:
- openfaas
- community
- faasd
- ce
- vision
dark_background: true
image: "/images/2023-07-time-to-update/background.png"
author_staff_member: alex
hide_header_image: true
---

We've been doing some housekeeping with old container images, so it's time to update your OpenFaaS installation.

In this article I'll explain how we've been doing housekeeping on old images for a while now, starting with the Docker Hub reset, why it's so important to be running up to date versions of OpenFaaS, how to update your Helm chart and how the project has been evolving over the past few years of full-time work.

Earlier in this year in March, Docker Inc caused a commotion when its management team decided to make open source organisations chargeable, or delete the images of open source projects who weren't in a position to pay.

See also: [Docker is deleting Open Source organisations - what you need to know](https://blog.alexellis.io/docker-is-deleting-open-source-images/)

Eventually, the decision was reversed, but the damage was done, many maintainers moved their images and lost trust in the Docker Hub.

Now that's not to say that we don't still love docker, the tool within the OpenFaaS community. Our first version was built for Docker Swarm in 2016, and I personally pay for a subscription to support their business. Modern Cloud and DevOps owes a lot to the Docker team, past and present.

* [How do changes to the Docker Hub affect OpenFaaS?](https://www.openfaas.com/blog/how-does-docker-hub-affect-openfaas/)

At the time, I was surprised to see that there were lots and lots of image pulls for really quite old builds of OpenFaaS Community Edition. And I mean ancient, chock full of CVEs in Alpine Linux, Go dependencies, and so forth. Versions that clearly put teams and their customers at severe risk. Docker's move was a blessing and a curse - it made us to some housekeeping, and the fallout was relatively minor.

On a recently call with a potential customer, I heard they were using a version of OpenFaaS that was three years old, just before we introduced the Community Edition of OpenFaaS. Having done a quick image scan using grype, an Open Source tool made by Anchorage, I found over 60 CVEs, most of them high severity and around a dozen were critical.

Do you want to know the kicker? The engineering director told me that they went to special lengths to set up a dedicated cluster for a customer who was so security focused, they didn't want to have shared tenancy on the SaaS version of OpenFaaS this company ran.

This is an actively developed and maintained platform, so I'm not sure what's worse, misleading a customer that has high security needs, or just not updating container images for three years.

If you'd like to know how to scan container images using grype, I covered it in a recent blog post for an enterprise customer who needed SBOMs from us over on the actuated blog:

[How to add a Software Bill of Materials (SBOM) to your containers with GitHub Actions](https://actuated.dev/blog/sbom-in-github-actions)

## Time to update

So whether you run OpenFaaS Community Edition using the Helm chart, or [faasd](https://github.com/openfaas/faasd), you'll need to update if your are using a version of any image more than 90 days old.

Fortunately, we've made that very simple for you with our arkade tool, which we use ourselves to update images in Helm charts.

For your values.yaml file or `docker-compose.yaml` file (with faasd):

```
arkade chart upgrade \
    --file ./values.yaml \
    --write \
    --verbose
```

The `arkade chart verify` command can also be used to flag which older images may have been removed.

Alternatively, if you do not have a custom docker-compose.yaml file or values.yaml file, you can simply install the OpenFaaS chart again. This is the same approach we take for updating OpenFaaS between versions.

## Checking that everything is OK

Supporting self-hosted software, remotely, in an async fashion with customers in different timezones can be challenging. Fortunately we've created an Open Source tool that any free user or paying customer can make use of to check their configuration.

Here's a frequent conversation we have with customers:

* Our function timed out. Can you help?
* Sure, have you set these specific timeout values?
* Yes we've set them all and checked twice!

And we'd have to schedule a Zoom call, which may be days later, and within a few minutes we'd have seen that they hadn't updated those timeout values at all or had missed one we'd given. They'd sigh "Aha, there it is" and we'd have all wasted so much time.

That's when we wrote our [config-checker](https://github.com/openfaas/config-checker) tool.

You can run it against any Community Edition, Standard or For Enterprises OpenFaaS installation and get detailed recommendations and checks for your setup. And every time we have a support case with a customer, we tend to go back and add extra checks and rules to help you help yourselves.

There's two ways to run the config-checker:

1. Use my [alexellis/run-job](https://blog.alexellis.io/fixing-the-ux-for-one-time-tasks-on-kubernetes/) utility to run the Kubernetes job, collect the logs, and remove the left over Pod
2. Run kubectl commands one by one to do the same

You'll find details in the GitHub repository here: [config-checker](https://github.com/openfaas/config-checker)

## An ever-evolving story

OpenFaaS has been going as a project since 2016, I've been working full-time on it since 2017, and in 2019 after [only having less than 500 USD / mo in GitHub sponsorships](https://github.com/sponsors/openfaas/), we had to pivot to an open-core model and that's the only reason the project continues to exist today, used at companies large and small all around the world: [ADOPTERS.md](https://github.com/openfaas/faas/blob/master/ADOPTERS.md).

I made a commitment to see OpenFaaS through for the long-term, which has involved personal and financial sacrifice. Our work on OpenFaaS is bootstrapped, which means staff are only paid salaries by customers who purchase a commercial license.

So what's the Community Edition (CE)? The clue is in the name.

The Community Edition isn't meant for profit-making companies to exploit commercially, whilst we scratch our heads about how to pay the salaries for our team members, or how to fund the challenging work of maintaining a project with millions of downloads, hundreds of contributors and a very complex underlying technology stack (Kubernetes).

It's meant for experimentation, for early prototyping, research, getting a feel for the platform and learning. It may also be suitable for small teams to run for internal use.

But OpenFaaS Pro (Standard or For Enterprises) is where we have worked with customers tirelessly for the past four years to create a production-ready platform that's ready to scale.

We've developed:

* A new Identity and Access Management (IAM) system for multi-tenancy
* Event connectors for Kafka, AWS SQS, AWS SNS and will add new sources for customers who ask for them
* A new auto-scaler with different strategies to scale functions based upon their workloads
* Fine-tuned scale-to-zero and scale-from-zero with zero dropped traffic
* A new autoscaler to replace the deprecated NATS Streaming project, with JetStream from Synadia
* A new UI portal for OpenFaaS which blends metadata from your deployment with the status of the function
* A CRUD API for namespaces for multi-tenancy

And many many tutorials, guides, videos, conference talks. All that whilst maintaining this free Community Edition, for [which we receive less than 500 USD / mo in funding](https://github.com/sponsors/openfaas) from a few, passionate individuals.

OpenFaaS Standard is fully featured, and will suit most teams' needs for production. 

OpenFaaS for Enterprises adds what you need for multi-tenancy, advanced security and compliance (Single-Sign On, Identity And Access Control), and it's where we can provide you with a Service Level Agreement (SLA).

If you'd like to read about customers who've built a multi-tenant functions platform around OpenFaaS for Enterprises, read this article: [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/).

If you'd like to understand the differences between the Community Edition, Standard and For Enterprises, [then check out the pricing page](https://openfaas.com/pricing) or the [detailed comparison table](https://docs.openfaas.com/openfaas-pro/introduction/#comparison).
