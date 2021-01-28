---
title: "New Serverless on Kubernetes Course by the LinuxFoundation"
description: "Did you know that there's a new free course by the LinuxFoundation introducing Serverless on Kubernetes?"
date: 2020-09-16
image: /images/2020-10-introduction-to-serverless/background.jpg
categories:
  - kubernetes
  - oauth2
  - security
  - sso
  - oidc
author_staff_member: alex
dark_background: true

---

Did you know that there's a new free course by the LinuxFoundation introducing Serverless on Kubernetes?

## Free training

![Free course!](/images/2020-10-introduction-to-serverless/headline.png)

> The course is accessible via the edx platform and was commissioned by the [LinuxFoundation](https://www.linuxfoundation.org)

You can now access a free training course on the [edx.org](https://www.edx.org) platform called ["Introduction to Serverless on Kubernetes"](https://www.edx.org/course/introduction-to-serverless-on-kubernetes). It was launched in September 2020 and was part of a collaboration with OpenFaaS Ltd and the training team at the LinuxFoundation.

From the course introduction:

> Learn how to build serverless functions that can be run on any cloud, without being restricted by limits on the execution duration, languages available, or the size of your code.

### What you'll learn

The course starts by introducing the term "Serverless", which we can all agree is somewhat controversial amongst the community. Some believe the term to be literal, some accept it to mean a developer-experience, and others have other very prescriptive definitions. The course then lays out the CNCF landscape and the various initiatives, projects and products available to practitioners.

The bulk of the course focuses on using OpenFaaS, from its initial installation, to building functions with built-in authentication, third-party libraries and then moves onto securing the installation and monitoring it at runtime. 

* Understand what serverless is.
* Get an overview of the CNCF landscape around serverless technologies.
* Learn how serverless can be made portable through the use of the Serverless 2.0 definition and Kubernetes.
* Explore the OpenFaaS toolchain, including: UI, CLI and REST API.
* Explore the OpenFaaS ecosystem, including the template store and function store for sharing functions and code templates.
* Build functions using Python, configure them, and use secrets.
* Add dependencies via pip, and learn how to build native extensions.
* Explore how to operate OpenFaaS with: autoscaling, metrics, dashboards, upgrades, custom URLs, and versioning.
* Expose functions securely on the Internet with TLS, and secure them with authentication.

All the content is self-paced and split across 9 different chapters with a quick quiz at the end of each, so that you can test your knowledge.

![Chapter 6 Learning Objectives](/images/2020-10-introduction-to-serverless/chapter-6-objectives.png)

> Here's an example of the learning objectives for Chapter 6. Create Your First Function with Python

* Do you know when to use Alpine Linux vs. Debian for your OpenFaaS functions?
* Do you know how a template works and needs to be structured?

In Chapter 7 you'll learn about the OpenFaaS watchdog component, how to return binary data from functions and how to authenticate a function using a Kubernetes secret.

![Convert color images with Python](/images/2020-10-introduction-to-serverless/convert-color-images.jpg)

> Convert a colour image to black and white using Pillow.

Chapter 8 is where things get turned-up a notch: Operating Serverless, by the end of that chapter you should be able to:

* Keep OpenFaaS up-to-date.
* Explore metrics available to you from OpenFaaS.
* Learn how auto-scaling works, and how to tune it.
* Deploy a dashboard to monitor functions.
* Add TLS for link-level encryption for OpenFaaS and your functions.
* Discuss strategies for versioning your functions, and for advanced HTTP routing.

You can get help along the way from the [OpenFaaS Docs](https://docs.openfaas.com) and from the community via [OpenFaaS Slack](https://slack.openfaas.io/).

### What are people saying about it?

The course was designed by OpenFaaS Ltd in close collaboration and within a few days of launch, we were excited to see over 1000 sign-ups. Here's what the team had to say about the collaboration:

> "Linux Foundation Training partnered with OpenFaaS to develop a new training course to be made available for free on edX titled 'Introduction to Serverless on Kubernetes'.
>
> Alex and team were great partners, providing high quality course materials on time, and following the launch of the course, they were very supportive in getting the word out. We look forward to continued collaboration with OpenFaaS around this and future training opportunities."
>
> [Clyde Seepersad](https://www.linkedin.com/in/clydeseepersad/), SVP and GM Training & Certification, The Linux Foundation 

The [initial response on Twitter was very encouraging](https://twitter.com/alexellisuk/status/1304079447885307904?s=20), and I'd like to thank everyone who reached out with personal messages.

## Wrapping up

As part of building the course, we enhanced various aspects of OpenFaaS including the documentation, Python templates, and the onboarding process for new users with [arkade](https://get-arkade.dev/). This was all contributed back to the community as open-source enhancements and we would welcome your feedback on what we can improve in the project, as you go through the course yourself.

You can enroll for the free course via edx.org here:

* [Introduction to Serverless on Kubernetes](https://www.edx.org/course/introduction-to-serverless-on-kubernetes)

### Connect with us?

If you're using OpenFaaS within your team, company or product, then join dozens of other companies and send us [a pull-request to the ADOPTERS.md file](https://github.com/openfaas/faas/blob/master/ADOPTERS.md). Let us, and the community know how you're using it.

If you have any other training needs, or want to talk about adopting Cloud and Kubernetes, feel free to contact me at [alex@openfaas.com](mailto:alex@openfaas.com).

Connect via:
* [The OpenFaaS Slack community](https://slack.openfaas.io/)
* [The OpenFaaS LinkedIn group](https://www.linkedin.com/groups/13670843/)
