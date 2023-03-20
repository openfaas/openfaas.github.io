---
title: "How do changes to the Docker Hub affect OpenFaaS?"
description: "We wanted to clarify how recent changes to the Docker Hub affect OpenFaaS users."
date: 2023-03-20
image: /images/2023-03-20-docker-hub/sunrise.jpg
categories:
- communityedition
- supplychain
- dockerhub
author_staff_member: alex
---

We wanted to clarify how recent changes to the Docker Hub affect OpenFaaS users.

I published an article last week in response to Docker Inc's move to delete free open source organisations and their associated images from the Docker Hub. The response was overwhelming, with over 105k page views, hundreds of [Hacker News comments](https://news.ycombinator.com/item?id=35166317) and [community Tweets](https://twitter.com/search?q=https%3A%2F%2Fblog.alexellis.io%2Fdocker-is-deleting-open-source-images%2F&src=typed_query) being shared as people came to terms with the proposed changes and in particular - the style of delivery.

You can read up on the full story here, including a link to Docker's later press-release: [Docker is deleting Open Source organisations - what you need to know](https://blog.alexellis.io/docker-is-deleting-open-source-images/)

**TL;DR**

The following may only affect OpenFaaS Community Edition (CE) or "free users" who haven't updated their systems in over two years. There is no change for OpenFaaS Standard/Enterprise customers.

Note: in the OpenFaaS CE, Pro charts and for faasd - we continue to make use of Prometheus and NATS images which are hosted on the Docker Hub. We do not have control over where these images are hosted, and recommend buying a Docker Hub account to avoid running into rate-limits. Alternatively, [you could mirror these images to your own registry](https://docs.actuated.dev/tasks/registry-mirror/).

## What does this mean for OpenFaaS?

In October 2020, I wrote up a similar article when Docker Inc introduced [restrictive rate-limits on the Docker Hub for free, public images](https://docs.docker.com/docker-hub/download-rate-limit/). At the time, my advice was to pay Docker for a Pro account and my advice focused on how to configure the required authentication.

[How to prepare for the Docker Hub Rate Limits](https://inlets.dev/blog/2020/10/29/preparing-docker-hub-rate-limits.html)

I even wrote an Open Source Kubernetes Operator which is still by a number of companies today to replicate their Docker Hub paid account credentials through their cluster - [alexellis/registry-creds](https://github.com/alexellis/registry-creds).

At the time, we made a decision in the community to stop publishing images to the Docker Hub, and to migrate to GitHub's Container Registry (ghcr.io). The main reason was that any user of OpenFaaS CE would need to pay for A Docker Hub account before they could use the project.

Even if they did manage to pull the images, if they needed to do an update, they may have run into the limit. We didn't want that barrier to entry.

## We've deleted images from the Docker Hub

Since 2020 images have been published to ghcr.io instead of the Docker Hub. That means that if you are using images from well over two years ago in production, that you've made yourself vulnerable to a significant amount of risk by not updating.

I would have rather left the images available, however with Docker's threat to delete them within 30 days, we were left with very few options.

We've made concerted efforts to [encourage commercial users](https://github.com/openfaas/faas/blob/master/ADOPTERS.md), even Fortune 500s to sponsor OpenFaaS for the value they receive from the Community Edition, however this has been in vain. At time of writing, [OpenFaaS receives around 700 USD / mo in total via GitHub Sponsors](https://github.com/sponsors/openfaas/), possibly less since GitHub removed the option for payment via PayPal. We simply cannot justify taking on Docker's 420 USD / year bill for the OpenFaaS organisation.

What about Docker's OSS program?

As I explain in the article. Docker's OSS program is out of touch. They will not allow any project to join if there is a way to pay for a better level of service, additional features, or for commercial support.

How do we maintain the project without funding from commercial users?

The Community Edition of OpenFaaS is already provides a large amount of value, which presents a challenge to monetization, especially in the middle of a global downturn. However, since 2019, we've focused on an open-core and support model, and existing customers of OpenFaaS Ltd, are not affected by this change.

## What about Docker Swarm?

Support for Docker Swarm was formally deprecated 2 years and 3 months ago. The code is available on GitHub, but with the deletion of images from the Docker Hub, there are currently no container images available for OpenFaaS CE on Swarm.

If you were still using OpenFaaS with Docker Swarm, so long after the deprecation, we would recommend making a move to OpenFaaS CE with K3s, or the simpler [faasd project](http://github.com/openfaas/faasd), which runs on a single VM.

I wrote a manual for faasd called [Serverless For Everyone Else](https://store.openfaas.com/l/serverless-for-everyone-else) which is based around practical examples written in Node.js - such as connecting to a database, managing secrets, monitoring, adding cron-schedules, custom domains and hosting functions on cloud VMs.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">I&#39;ve just sent out an update to the 1000 people who&#39;ve bought my OpenFaaS eBook 🐳<br><br>Hope you enjoy the new Node 18 template and the new free bonus content<br><br>If you&#39;re using faasd at home or work I&#39;d like to hear from you<a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> <a href="https://twitter.com/hashtag/ebook?src=hash&amp;ref_src=twsrc%5Etfw">#ebook</a> <a href="https://twitter.com/hashtag/nodejs?src=hash&amp;ref_src=twsrc%5Etfw">#nodejs</a> <a href="https://twitter.com/hashtag/faas?src=hash&amp;ref_src=twsrc%5Etfw">#faas</a><a href="https://t.co/9g3XM3Yj1p">https://t.co/9g3XM3Yj1p</a> <a href="https://t.co/9f4ci9Y97W">pic.twitter.com/9f4ci9Y97W</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1636666516656607233?ref_src=twsrc%5Etfw">March 17, 2023</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

[Find out when to use OpenFaaS CE on Kubernetes vs faasd](https://docs.openfaas.com/deployment/#faasd-serverless-for-everyone-else)

## What do we need to do - going forward?

There is no change for CE and Pro users who have deployed OpenFaaS over the past two years. You will continue to receive updates and new features as they are released through images on GitHub's container registry (ghcr.io).

If you have custom OpenFaaS templates, check and make sure the "FROM" for the OpenFaaS watchdog point to GHCR and not docker.io. A lack of a prefix also uses the Docker Hub.

```diff
-FROM --platform=${BUILDPLATFORM:-linux/amd64} openfaas/of-watchdog:0.8.0 as watchdog
+FROM --platform=${BUILDPLATFORM:-linux/amd64} ghcr.io/openfaas/of-watchdog:0.8.0 as watchdog
```

This isn't necessary unless you forked templates or created your own custom ones over two years ago.

## Summary

Whilst there was very vocal opposition to the way the changes were made by Docker Inc and the short time-line given, we had already migrated to ghcr.io for images in 2020, and we've been using it for all new releases since then.

The deletion of our deprecated images from the Docker Hub will affect a number of users who haven't updated their systems in a very long time, however, using images that are so old is a huge risk to your business or to your employer.

For OpenFaaS CE aka "free users" - simply update the images in your chart to the equivalents on ghcr.io, or install the chart again over the top of an existing installation to upgrade to the latest version.

* [OpenFaaS CE Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas)
* [faasd](https://github.com/openfaas/faasd)

We hold a weekly Office Hours calls for OpenFaaS users, if you'd like to talk to us about your options, [feel free to join](https://docs.openfaas.com/community/). Or send us a note about your use-case to the [ADOPTERS.md file](https://github.com/openfaas/faas/blob/master/ADOPTERS.md).

If you are a commercial user of OpenFaaS CE, and haven't updated your system in a very long time, it may be worth seeing what we now offer in a paid subscription: [OpenFaaS comparison](https://www.openfaas.com/pricing)

If you want to support our Open Source work on OpenFaaS CE and faasd, [you can do so via GitHub Sponsors](https://github.com/sponsors/openfaas/) which goes towards the salaries of full-time staff working on the project.
