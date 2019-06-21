---
title: The OpenFaaS 2019 Project Update
description: Alex shares the OpenFaaS 2019 Project Update, case-studies, personal highlights, and the roadmap for the year.
date: 2019-06-21
image: /images/2019-project-update/background.jpg
categories:
  - update
  - project
  - community
  - kubernetes
author_staff_member: alex
dark_background: true
---

The founder Alex Ellis shares the OpenFaaS 2019 Project Update, case-studies, his personal highlights, and the roadmap for the year ahead.

> In March 2019 [I left VMware](https://blog.alexellis.io/openfaas-bright-2019/) to continue developing OpenFaaS in full-time as an open-source project.

Since then I've had some personal highlights including [becoming a CNCF Ambassador](https://blog.alexellis.io/joining-the-cncf-ambassadors/). I launched a business called [OpenFaaS Ltd](https://www.openfaas.com/support/) to host and support the OpenFaaS project and brand. Through OpenFaaS Ltd I provide professional services to the community such as training, consultations, product evaluation, along with OSS & community strategy.

> If you would like to associate your brand with one of the fastest-growing developer communities then [consider sponsoring openfaas.com](https://www.openfaas.com/support/). Or if you want to [buy me a coffee or a beer](https://github.com/users/alexellis/sponsorship), I'm now participating in GitHub's new Sponsorship program.

In this blog post I'll share the community briefing and then pick out a few of the parts I feel are most important for the community.

## Community Briefing Video

You can catch-up with all the latest news and traction in the recording below

{% include youtube.html id="Hj_XeYXSaxw" %}

I'll highlight a few specific areas below.

### Community Traction

Traction continues to grow at a fast rate with:

* Over 17.8k GitHub stars
* Over 210 contributors
* A projection of 350 community blog posts by 2019
* Over 4 dozen end-user companies in production

The end-user community presents a sub-section of OpenFaaS users who have corporate clearance to use their logo and use-case to tell the world about how they are using OpenFaaS.

![](/images/2019-project-update/end-users.jpg)

### Competitive Landscape

With the launch of Keda from the Azure team, and Knative from Google and her partners it seemed a good time to write-up a new landscape. The Serverless 2.0 Landscape has been presented to the Google, RedHat and Azure teams and represents a new level of interoperability that 1st-generation products never had.

![](/images/2019-project-update/serverless2.jpg)

The primitive is a Docker or OCI-format image that listens to traffic on port 8080. Pick-n-mix your favourite build templates, runtime and Kubernetes platform then add in any optional parts from the right hand side, such as scale to zero, events or hosted options.

### Performance Tuning

Performance has been tuned.

![](/images/2019-project-update/performance.jpg)

* Scale to and from Zero enable resource over-commit and can save you money on your infrastructure bill
* Did someone tell you that OpenFaaS works through `stdio`? They are only half-right - any binary can be made into a function by wrapping it with our Classic Watchdog, it then exposes HTTP for any code.
* OpenFaaS can run any HTTP server which listens on port 8080. Our new of-watchdog gives a compatible wrapper for this purpose. You can access HTTP templates using of-watchdog by typing in `faas-cli template store list`
* For Kubernetes users, I highly recommend trying the httpProbe functionality, it reduces the CPU consumption of the `kubelet`

### Applying Torque

![](/images/2019-project-update/security.jpg)

* Authentication by default - for both Kubernetes and Docker Swarm, authentication is always enabled
* Non-root - we've worked really hard to make our core services and your functions run as non-root to help mitigate potential container security issues
* Read-only filesystem - this prevents your function code from mutating, but also protects the userspace and libraries you are consuming
* OpenFaaS Cloud now has OAuth2 enabled for GitHub.com and GitLab and in addition provides SealedSecrets for storing API keys

### Roadmap for 2019

We've worked really hard on the user experience for the community and for cloud native developers and one of our project values is "Developers First". At a networking event at Accel I was challenged to re-think what "Developers First" meant for the enterprise.

Some of the work done of the past year has been focused on performance, ecosystem, hardening, and security, but there are some more basic needs that I want to look at now.

![](/images/2019-project-update/roadmap.jpg)

* Multiple-namespace support will enable OpenFaaS Cloud to grow and give even more isolation between tenants and users.
* OAuth2 with OpenID Connect will allow the UI, CLI and CI processes to connect to the OpenFaaS API using a federated security model.
* The `faas-cli logs` feature is coming soon and will improve the debugging experience. Today our community uses `kubectl logs` or `stern` instead.

## Wrapping up

I hope you enjoyed the video and my personal highlights from 2019. You can get connected with the community and the life of the project through Slack and Twitter.

### Connect

If you have comments, questions or suggestions or would like to join the community, then please [join us on OpenFaaS Slack](https://docs.openfaas.com/community/).

You can follow [@openfaas on Twitter](https://twitter.com/openfaas/)

### Give back

Are you using OpenFaaS in production? [Join the end-user community](https://github.com/openfaas/faas/issues/776)

Want to sponsor openfaas.com, [start here](https://www.openfaas.com/support/)?

### Contribute

OpenFaaS has no corporate sponsor or financial backer, so we rely on community contributors. We welcome contributions at all levels and have a current need for:

* front-end developers
* content-writers
* Golang coders
* Kubernetes expertise

All contributors appear on openfaas.com after their first PR has been merged.

![](/images/2019-project-update/contribute.jpg)

If you would like to help, [join us on Slack](https://docs.openfaas.com/community/) and check out the [open issues on GitHub](https://github.com/openfaas/).
