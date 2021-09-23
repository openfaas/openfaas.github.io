---
title: "Case-study: Building a Low Code automation platform with OpenFaaS"
description: "Veselin Pizurica, President of Waylay.io tells us about Low Code automation OpenFaaS"
date: 2021-09-23
image: /images/2021-09-low-code/waylay-top.jpg
categories:
 - hosting
 - lowcode
 - casestudy
 - kubernetes
author_staff_member: veselin
dark_background: true

---

Veselin Pizurica, President of Waylay.io tells us about Low Code automation OpenFaaS

## "Nobody ever got fired for buying IBM"

Back in the 90s, when Enterprise IT departments would make a vendor selection, IBM was always seen as the safe choice. If they chose IBM and it didn't work out, well, it was still seen as a reasonable decision and people would just blame IBM. But if you deviated from the norm and chose something else that didn't work out, people would blame IT for it. 

In a sense, the same thing is happening today. Few Enterprise IT departments would dare select something else than AWS, Azure or GCP as their "infra baseline".The Big three were careful to provide similar cloud offerings, but different enough so that regardless of which one you would choose, you would be signing off for a vendor lock-in from day one. Waylay's goal is to provide a pre-build automation backbone for Enterprise with an open API that is based on software components and services that are compatible with all clouds. Still, many people would argue that the lock-in is not as bad as it sounds. And that’s a fair point. When making the vendor selection, big enterprises always ask themselves questions along these lines:

* Do we care about portability? 
* Do we ever consider moving from one cloud to another? 
* Are we required to provide solutions across different cloud platforms?
* Is there a strategic aspect we need to consider to be able to run our solution on-prem, or on custom clouds where being agnostic is important?

## How to avoid vendor lock-in?

If the answer on any of these questions is affirmative, enterprises still need to go over "the build vs. buy" decision. Thousands of blogs and articles were written on how to build an automation stack on top of kafka, mongo, etc.. It all sounds very simple till it isn’t. In the end, the success of such an incredible effort is not only a matter of knowledge, resources, budget and time, but also of how secure, scalable and maintainable such a platform is in the long run. In 2014, Waylay set out on a journey to provide an alternative cloud agnostic automation platform: not as a one-off gig - we do it for a living. Our goal was to set up a Low Code automation platform that is portable across all clouds and that runs on top of every IAAS stack. 

There are two possible strategies in order to achieve this goal:

One approach is what I call cloud neutral, where Waylay would build independent proxies which delegate eventual cloud services to cloud providers. In that respect, our solution would be sort of a "cloud facade", where proxies would wrap APIs and interfaces for every microservice provided by different clouds. That approach would be hard to follow, as proxies would need constant updates, while still not solving the challenge of on-prem installations.

Or as [Allen Holub](https://twitter.com/allenholub) put it:

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">The idea of wrapping an external platform (e.g. AWS), so you can rewrite that wrapper if you need to change platforms, rarely works. You use a platform because of its features. Moving⇒implementing those things yourself. Won’t happen. Best to just use platform APIs. It’s simpler.</p>&mdash; Allen Holub (@allenholub) <a href="https://twitter.com/allenholub/status/1432739484873883648?ref_src=twsrc%5Etfw">August 31, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

The second approach, which is also our strategy, is to build our solution on top of software components which offer similar robust capabilities and can be installed on any IAAS stack, thereby removing dependencies on any specific cloud provider. That is what I call the cloud agnostic approach. Compared to the neutral approach, it brings two important advantages: a better TCO for our customers, given our stack runs on top of any IAAS, and also enables the Waylay platform to run on-prem and on the edge, which is essential for many Industry 4.0 use cases.

By following the cloud agnostic approach, Waylay has built a set of automation microservices such as our automation engine, serverless plugin interface, digital twin, alarms service, time series storage, machine learning framework etc...

## How we discovered OpenFaaS


When selecting a software component to be part of Waylay’s "infra", the first criteria is always the quality and robustness of that component - we simply can’t compromise on this requirement. When that candidate software component is also open source - it is always our preferred choice. Having said that, building a company on top of open source is a sound strategy as long as the open source ecosystem is healthy. Therefore, when evaluating possible open source components, we always ask ourselves the following questions:

* How robust and performant is that component?
* How easy is it to configure, install, and run this component?
* How big and active is the community?
* How is that community managed?
* What is the business and support model of that component?
* Can we establish a good support and commercial model with that community?

The last two questions are incredibly important to us. When we select a particular open source component, we also want to become part of that community as well. Along the way, we want to contribute, but we also understand that maintaining a huge code base and community requires constant engagement and commitment from maintainers and the overall community. 

When we were in the process of selecting a serverless component for our platform, we followed the same process. We ran benchmarks, looked at how easy it is to integrate such components in our stack, looked at how strong the community is and found OpenFaaS checking all of these boxes. Finally I was ready to call [Alex](https://twitter.com/alexellisuk/).

> After an open and frank discussion, we were absolutely committed to building healthy and sound commercial relations with OpenFaaS. We purchased [OpenFaaS PRO licenses](https://openfaas.com/support/) and decided to become a [platinum sponsor](https://openfaas.com/). 

## Try Waylay IO for free and discover what you can do!

As an OpenFaaS community member, you may wonder what Waylay has to offer on top of OpenFaaS? If you wonder what you can build with Waylay, please have a look at Sander's [recent project for Growlab](https://dev.to/sandervanhove/building-a-growlab-using-raspberry-pi-waylay-4dl9?utm_source=openfaas&utm_medium=web&utm_campaign=sponsorship). [Sander](https://twitter.com/SanderWaylay) is our community manager at Waylay.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Planted some strawberry, pennyroyal, crispleaf mint, jalapeño, chilli and citrina seeds 😋 let&#39;s go! <a href="https://twitter.com/hashtag/growlab?src=hash&amp;ref_src=twsrc%5Etfw">#growlab</a> <a href="https://t.co/Jk4eeW63eI">pic.twitter.com/Jk4eeW63eI</a></p>&mdash; Sander Vanhove (@SanderWaylay) <a href="https://twitter.com/SanderWaylay/status/1397606250796433416?ref_src=twsrc%5Etfw">May 26, 2021</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

If you are interested in trying Waylay IO, please go to our [signup page](https://www.waylay.io/products/waylay-io/product?utm_source=openfaas&utm_medium=web&utm_campaign=sponsorship) to try it out for 30 days. If after this trial period you are still in doubt, we offer one more thing, your very own local installation, what we call a [tinyAutomator](https://docs-io.waylay.io/#/features/automator/?utm_source=openfaas&utm_medium=web&utm_campaign=sponsorship). Immerse yourself into the future of automation, but at your own pace, take your time and have fun! Talk to us today if you have any further questions and please reach out to on [our forum](https://forum.waylay.io/?utm_source=openfaas&utm_medium=web&utm_campaign=sponsorship).

We will be waiting for you.

Yours truly,

Veselin

> A note from Alex: I want to thank Veselin for using, for giving actionable feedback and for supporting us through OpenFaaS' business model of sponsorship, support and commercial add-ons. I hope you enjoyed the case-study and will check our Waylay's free trial or Sander's project with Growlab.
>
> If you're using OpenFaaS in production, you can become an individual or corporate [supporter via GitHub Sponsors](https://github.com/sponsors/openfaas).
>
> For OpenFaaS Pro features such as Scale to zero, Kafka integration and SSO with OIDC and Enterprise Support, checkout [our support page](https://openfaas.com/support/)
