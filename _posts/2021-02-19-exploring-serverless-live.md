---
title: "Exploring Serverless use-cases"
description: "Understand Serverless use-cases in this fireside chat with Alex Ellis from OpenFaaS and David McKay from Equinix Metal"
date: 2021-02-19
image: /images/2021-02-stream/background.jpg
categories:
 - live
 - use-cases
 - functions
author_staff_member: alex
dark_background: true

---

Understand Serverless use-cases in this fireside chat with Alex Ellis from OpenFaaS and David McKay from Equinix Metal

## Exploring Serverless use-cases

In this blog post I'll introduce you to use-cases for Serverless, a video recorded with [David McKay](https://twitter.com/rawkode) from the DevRel team at [Equinix Metal](https://metal.equinix.com/), and some resources for how to learn more and to start applying this to your own workflows.

[![The livestream](https://camo.githubusercontent.com/544dffaf339a4ff44439db1c14cd953de385640b99231688f8a49db61294a02e/68747470733a2f2f7062732e7477696d672e636f6d2f6d656469612f457378444745505841415968724c4f3f666f726d61743d6a7067266e616d653d6c61726765)](https://www.youtube.com/watch?v=mzuXVuccaqI)

> David and I have known each other for several years and are both active in Open Source, he's also contributed to OpenFaaS in the past.

OpenFaaS is a platform that makes Open Source serverless easy and accessible on any cloud or host, even on a Raspberry Pi. Every week our community is inundated with support requests, feature suggestions and feedback. However, one of the things that seems elusive is an understanding of what people use it for, and how it's being used.

Over the past 4 years I've spent time getting to know end-users, and asking probing questions, and in some cases users have gone ahead and written up a submission to the OpenFaaS ADOPTERS file. The first time I saw the concept of ADOPTERS files was in the Cloud Native Computing Foundation (CNCF)'s requirements for donating a project. It seemed like a good idea, and like it would help answer the question we often got: "what can I use serverless for?"

* [ADOPTERS.md](https://github.com/openfaas/faas/blob/master/ADOPTERS.md)

There's no stringent requirements for sending a Pull Request, but ideally we are looking for the company or project name, and one or two sentences explaining the value or how it's being used.

Let me give you an example from [RateHub.ca](https://ratehub.ca), written by their [CTO Chris Richards](https://www.linkedin.com/in/chrisrichard/?originalSubdomain=ca):

* "We're Canada's leading personal finance comparison site."
* "We're breaking apart our monolithic PHP and Java codebases into Node, PHP and Java OpenFaaS functions."
* "There's not much that we don't plan on moving to FaaS!"

Another, more recent example comes from [Simon Emms](https://twitter.com/mrsimonemms?lang=en), a DevOps consultant from the UK contracted to a government body.

> [HM Planning Inspectorate](https://www.gov.uk/government/organisations/planning-inspectorate) -is the UK Government body responsible for dealing with planning appeals, national infrastructure planning applications, examinations of local plans and other specialist casework in England and Wales. OpenFaaS eased the communication between the new planning appeals website and the monolithic back-office application and allowed easy retries in the event of network failure.

There's even use from small businesses and individuals. Here's one from [Gene Liverman](https://twitter.com/technicalissues) who uses [faasd](https://github.com/openfaas/faasd) for social media automation:

> [First Baptist Church Carrollton](https://www.fbcc.us/) - "We use faasd as the backend for a Slack bot connected to our internal Slack workspace. The bot was initially created to facilitate remote question and answer sessions at our church by allowing viewers of our live stream to text or email questions in, have a staff member ask their question in the room, and then allow the staff member to send a response back to the sender. The texting is facilitated by Twilio while the email is done by interacting with a Gmail account via IMAP and SMTP."

You may ask why there are only ~ 110 lines in this file, when there are 26k GitHub Stars on the OpenFaaS organisation.

That would be a valid question. One of the main challenges is that only a small amount of companies using Open Source software are happy to talk about their use-case. At one point we collected end-user logos where permission had been granted and had around 60 logos listed on the OpenFaaS website before moving over to the text file.

The other part of this is where a developer through so-called "bottom-up" adoption deploys OpenFaaS to make his, or his team's life easier and doesn't have permission to mention the company's name. There's actually over 3500 people that have signed up to OpenFaaS Slack for free community support, and most of those said they were planning on or actually using OpenFaaS for work, which is reassuring.

However, we still have a problem of getting those users to submit something and share. But why should that matter?

Sharing use-cases helps demystify the technology. It leads the way and shows how to solve real problems. For that reason David and I met on YouTube to walk through our own personal use-cases and to highlight some from the community.

I hope you'll enjoy the video.

### Catch up with the recording

{% include youtube.html id="mzuXVuccaqI" %}

Here's some of what you'll get from the video:

* 0:30​ - Introduction to our hosts
* 3:55​ - How can you tell if you're "ready for serverless"?
* 07:48​ - What is serverless?
* 10:40​ - Derek and GitHub webhooks
* 11:40​ - Okteto generated changelogs
* 14:03​ - Workflows with Stripe
* 19:08​ - Gumroad automation
* 22:30​ - Webhooks for automation
* 23:45​ - Mixing static pages and functions
* 29:27​ - OpenFaaS end-users (adopters)
* 32:35​ - Rawkode's Pipedream demo
* 36:50​ - Contentful
* 41:19​ - Web scraping
* 43:48​ - Serverless For Everyone Else eBook

You can view the [show notes here](https://gist.github.com/alexellis/c72d7a385f801cc9b8deb7fcaa531b69)

### Where could you start today?

* Do you use a CDN to serve a static webpage, docs or a blog?

    You can get dynamic data and run a function from your app deployed to GitHub Pages or Netlify. You'll learn how in the video. Example: [Leaderboard app](https://alexellis.github.io/docs/)

* Do you have repos on GitHub?

    Connect webhooks, so you can forward star events to your Slack workspace or Discord server. Example: [alexellis/github_gazing](https://github.com/alexellis/github_gazing)

* Do you use a SaaS or a proprietary system and wish it did a bit more?

    You can write functions to do whatever you like. If the product has an API or SDK, write a function to do what you need. Examples: [Gitea bots](https://www.openfaas.com/blog/gitea-faas/) - [Derek, the GitHub bot for maintainers](https://github.com/alexellis/derek)

* Is there a portal or internal website that could save you or your colleagues time by automating something?

    Example: my [Treasure Trove Sponsors Portal](https://twitter.com/alexellisuk/status/1361971003262447623?s=20)

* Do you sell something with Stripe?

    Do something with those events using functions. Example: [Tracking Stripe Payments with Slack and faasd](https://myedes.io/stripe-serverless-webhook-faasd/)

* Do you want to scrape data from a webpage, or to generate social sharing images?

    Learn how to use CSS + HTML to generate images with headless Chrome, example: [Web scraping that just works](https://www.openfaas.com/blog/puppeteer-scraping/)

## Find out more

If you're an OpenFaaS end-user, think about sending us a PR to the [ADOPTERS.md](https://github.com/openfaas/faas/blob/master/ADOPTERS.md).

Read on for a couple of ways to get started, or to support the community's work.

### Figure out Serverless in a weekend

Still not sure what Serverless is, or if it could be of use to you at home or at work?

<a href="https://gumroad.com/l/serverless-for-everyone-else"><img src="https://camo.githubusercontent.com/4e204e93dcfc33679c997c739fbf4f651fdf268d23961bae6f9b4c25ad4ec145/68747470733a2f2f7062732e7477696d672e636f6d2f6d656469612f45735a3372753258634155513451673f666f726d61743d6a7067266e616d653d6d656469756d" alt="Workshop upgrade" width="80%"></a>

> You can run OpenFaaS on a cloud VM, your laptop, or a Raspberry Pi. In the hands-on video I'll show you how to build functions in Node.js.

Until Monday 22nd Feb, you can get the video workshop upgrade for free when you buy the DevOps PRO tier.

You can also see how I wrote an OpenFaaS function to get notifications from [Gumroad](https://gumroad.com/l/serverless-for-everyone-else) for sales, and how the free upgrades work, including the logic for sending emails and the promotion end-date.

* [alexellis/gumroad-sales-forwarder](https://github.com/alexellis/gumroad-sales-forwarder/)

Check it out on Gumroad: [Serverless For Everyone Else](https://gumroad.com/l/serverless-for-everyone-else)

### Already using OpenFaaS?

Join GitHub Sponsors for 25 USD / mo for access to discounts, offers, and updates on OpenFaaS going back to mid-2019. Taking this small step, has a huge collective impact on the sustainability of the project.

[OpenFaaS GitHub Sponsors](https://github.com/sponsors/openfaas/)

