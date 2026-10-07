---
title: "One Engineer, 200 Functions: How Surge Runs a Financial Data Backbone on OpenFaaS"
description: "We interviewed Kevin at Surge about his experience running OpenFaaS at scale over the past 5 years in a financial data platform."
date: 2026-10-07
author_staff_member: alex
categories:
  - case-study
  - customer
  - finance
dark_background: true
# image: "/images/2026-04-python-sdk/background.png"
hide_header_image: true
---

We interviewed Kevin, an OpenFaaS practitioner who has been building out Surge's financial data platform since 2021 with asynchronous jobs at the core.

He told us that he currently has around 200 functions and counting, loses very little sleep over the platform, and regularly ships requests from the business to production in anywhere between 15 minutes and a couple of hours.

<div class="author">
    <div class="card team member">
        <div class="avatar">
            <img class="team avatar" src="/images/author/kevin.png" alt="Kevin Lindsay" />
        </div>
        <div class="team about">
            <p class="team name">Kevin Lindsay</p>
            <p class="team blurb">Principal Engineer, Surge Solutions</p>
        </div>
    </div>
</div>

### 1. How does Surge make money?

We provide products and consulting to the mortgage and lending industry, which covers things like background checks, data insights that make it easier for a lender and a broker to transact. We service the majority of our customers through Salesforce.

### 2. What did you run on OpenFaaS first and how long ago was it?

We first deployed OpenFaaS around 5 years ago in 2021. It all started with a distributed ETL job that processes hundreds of tables of data in varying levels of quality. The functions that make up that job synchronize financial and lending data across a large number of sources.

It's one of our most complicated systems, necessarily so. The job stress-tests OpenFaaS because it has so much it needs to do - processing 10s of Gigabytes of files with job state, and file offloading. That original implementation has been replaced and refined a few times over the years.

Every day a scheduled invocation kicks off a number of jobs to import data from Snowflake into Salesforce. Since functions are stateless, we use AWS S3 for intermediate state - that means we can go back and inspect or debug imports after the fact.

The flow looks like this:

```
   +-------------+         +-----------+         +-------------+         +-------------+
   |  Snowflake  |-------->|  Ingest   |-------->|  Transform  |-------->|  Aggregate  |
   |   source    |-------->|  chunks   |-------->|             |-------->|    into     |
   +-------------+         +-----------+         +-------------+         +-------------+
          |                      |                      ^
          |                      v                      |
          |               +-------------+               |
          +-------------->|     S3      |---------------+
                          |intermediate |
                          |    state    |
                          +-------------+
```

*High level conceptual diagram showing data flowing from Snowflake, through ingest and transform stages, into Salesforce, with S3 used for intermediate state.*

First of all, chunks are ingested into the system, and then when all chunks are ready, they're transformed into the shape Salesforce needs. From there, the pipeline aggregates the transformed chunks into Salesforce for 50 different data products, every day, for every customer.

### 2.1 How did you decide to use OpenFaaS back then, and what else were you considering?

Back in 2021, our team was prototyping an internal system to run the original version of the ETL job. The team had to rework it most days because we didn't know what features we needed or what the product needed to look like. The job was tied to Kafka streams, with traditional Kubernetes services and Go, but ended up having a 50% failure rate.

Not only did we need to figure out how the code should work, but we had to find all the *platform pieces* too:

* authentication
* which of the many options Kubernetes presents to use for workloads
* how to wrangle Helm charts
* whether to run a database in the cluster, or use a managed one
* a good metric for autoscaling the parts of the job that could run in parallel

Internal and external stakeholders were hounding us daily for when the solution was going to be production ready and we were working really hard. We were moving so rapidly that we decided to work with the OpenFaaS team to bring in an opinionated framework. I volunteered to reimplement the work we had so far.

That's where it really started. I transitioned us from a self-hosted Kubernetes cluster on AWS EC2 to a managed AWS EKS cluster whilst learning Kubernetes primitives myself and researching options for running jobs. At the time, AWS Lambda implemented hard limitations, and we knew that its pricing carried a hidden premium at scale. OpenFaaS brought us an experience that was close to Lambda, where we could iterate and develop in a fast way, without getting bogged down in abstractions.

### 3. What's your stack like now?

We're still running 100% on AWS EKS, however, over the years we've experimented with large nodes, spot instances, and will certainly adopt Arm EC2 instances in time for efficiency and cost savings. After having availability with spot instances, we moved to on demand instances, using the smallest ones we could get away with - think the low end of the T3 family. That keeps our costs very low and means we can scale up and down very quickly.

OpenFaaS is installed through its Helm chart, and I update to the latest versions as soon as they're available. We're at around 200 functions at present and these are packaged and deployed using the Function CRD and Helm.

For function development we generally use Go and rarely test on our own machines. We've found that adding a new function is so risk-free that we can push straight to *staging*, then promote the container image through to Production using our CI pipelines.

### 4. What's the busiest thing you've seen the platform cope with - and how did it do with it?

Every night we export and backup customer data from Salesforce, into S3, synchronizing it with Snowflake. That typically means going to a Salesforce organization, reading definitions, then converting them into something we can replicate into Snowflake. This is the heaviest job we have to date.

We're talking about replicating data for every single customer, including virtual tables created from metadata. There's probably 15 different functions involved in each of these definitions, all of which run in parallel.

> In a normal week we probably handle a few terabytes of data and our error rate is zero on average.

We worked with OpenFaaS as an early tester for queue-based scaling, which works so perfectly, that we were able to override node scaling to deprovision nodes much faster than the default 15 minute grace period set by AWS. Despite the sudden spikes in load, OpenFaaS reacts to scale proportionally with no baked in knowledge.

Previously it took up to two minutes to get a new EKS node online due to the way we were using Datadog's agent. The agent also penalized us for scaling to large numbers of nodes, so we kept more expensive larger nodes around instead. Fortunately, I found that I could write logs to Datadog directly from the functions, that reduced our costs by around 90% alone.

### 5. When something goes wrong - what is it like to fix?

If our code has an error, then 99% of the time, we see a Slack message from a Datadog monitoring alert, and fix it using the provided stack trace. Typically, our functions are very small and non-monolithic, so we can find something like a nil pointer exception and get it patched in production within the time it takes to run the GitLab pipeline - about 3 minutes.

One of the things that has made our system so durable is that functions are designed to be stateless and we run asynchronously where possible. That means that a failed invocation or an interrupted node doesn't result in data loss.

A lot of our jobs are idempotent, so if Salesforce has a compute capacity issue, the next scheduled interval will fill in any data that was missed in that run. This architecture is stress free.

### 5.1 What does the platform handle for you automatically?

OpenFaaS handles transient errors for any asynchronous invocations we have, but the single highest value thing it offers is application layer scaling.

Kubernetes does not offer that out of the box, it focuses on network or infrastructure metrics, and AWS Lambda uses proprietary scaling. So with our current setup, we get the exact amount of Pods we need for synchronous and asynchronous requests.

We've tuned the autoscaling so well now that we see most of our async invocations get scheduled immediately, without backing-off or waiting too long for new nodes to come online.

### 6. What used to be painful to keep running, that now basically looks after itself?

Earlier in my career I saw the short end of the stick with products that were not at all reliable and never got proper fixed.

But everything with this particular OpenFaaS stack looks after itself. If AWS and Snowflake are both up, then we've had something like 5 minutes of downtime within the last 6 years.

> We've had 5 minutes of downtime within the last 6 years. I do not lose a minute of sleep over OpenFaaS, not a single 2AM pager going off or alerts about clusters being down.

### 7. What's the thing that still nags you? What would you change if you had a quiet week?

We've been able to move daemons, scheduled jobs, and web-portals over to OpenFaaS, but we still have some legacy systems that were created before we adopted functions. I'd like to see those moved over too. It's not that they'd be hard, but they are working, and were written by people who no longer own them.

After that, Arm is on the top of my list for efficiency and cost savings, and OpenFaaS was one of the first products to support multi-arch, well before it was mainstream, so we know the support is there.

Other than that, I let the business drive the system. I've automated it so much that my stressors are generally very low - compared to other places I've worked in the past. If the business needs to run a report, they can open up the dashboard and invoke a function, or I can do it from my phone using our secure endpoints.

### 8. What's the between "business wants this" and it's live in production?

Before adopting functions, we used to have to discuss architecture, patterns, scaling, and understand the line between the business requirement and our own DIY platform or template to run it. That meant brokering and decision-making, which created a technical hurdle that needed a significant time investment in the fiddly pieces of raw Kubernetes.

Now, we essentially say "OK" to a stakeholder and start the work.

If we need to integrate with a new vendor, we prototype it in isolation, and when we're happy with it, we deploy it. Our approach is to consider previous functions as utilities that we can re-use and adapt for future requirements, taking what we've learned and combining them into the system.

We used to do things like GraphQL services. Standing one of those up would probably take a couple of days to write, build, and to cover edge-cases. But, now using functions, we just use our template, change a couple of files, and we're in production in between 15 minutes and a couple of hours. And none of that time is about managing the stack, or debugging Kubernetes, it's 100% focused on business workloads.

> Even Lambda couldn't quite give us that level of simplicity.

### 9. What can you ship in a day that used to mean pushing it to "next sprint"?

Every function that we have - and we have about 200 of them now. Each of them could be adjusted within the day, without having to wait until the next sprint. Functions allow me to preempt what may be coming from the business, and I can make a v2 of a function, without impacting the original, and cut over whenever we want, at very low risk - we just change a URL to point at the new version.

### 10. If another engineer asked when they should reach for OpenFaaS, what would you tell them in one sentence?

If it were a team-mate asking me, then I'd say:

> "in the company, we use OpenFaaS".

If it's a prototype for yourself, and it'll be both local and temporary, then use whatever you want. In our experience, OpenFaaS is super battle-hardened and it will 99.5% be superior than DIY because it covers so many Kubernetes concepts with sensible defaults.

There are very few cases when I wouldn't use OpenFaaS. We have a bit of everything:

* ETL pipelines
* GraphQL
* APIs
* internal web portals
* PDF report generation
* background services and daemons
* nightly jobs

... and everything in between.

### 11. If a feature disappeared from OpenFaaS tomorrow, which would you miss the most?

The most critical feature we need is [asynchronous invocations with queue-depth scaling](https://www.openfaas.com/blog/queue-based-scaling/). For anyone looking to start out with OpenFaaS - I would recommend using the async system first for its durability, callbacks, and instant scaling. We have to write way less boilerplate than we would with an alternative solution.

## What we took from the interview

Five years in, Kevin's platform is a study in what happens when you pick a tool that fits the way you actually work. One engineer is responsible for roughly 200 functions that move a few terabytes of data every week across Snowflake, S3 and Salesforce, and it has cost him about 5 minutes of downtime in that time.

The pattern that comes through every answer is the same:

* keep the functions small and stateless
* run them asynchronously where you can
* let the platform handle the scaling and the retries

Kevin doesn't babysit the cluster, he doesn't design the architecture for every new requirement, and he doesn't lose sleep over it. The business asks for a report, a function gets invoked, and the data is there in a short period of time.

That's the outcome we're going for with OpenFaaS: a platform that gets out of the way, so the work you do on it is 100% about the business and not the minutiae.

If you'd like to read more case-studies, see:

* [Case-study: Building a Low Code automation platform with OpenFaaS by Waylay](https://www.openfaas.com/blog/low-code-automation/)
* [Scaling to 15000 functions and beyond](https://www.openfaas.com/blog/large-scale-functions/)

And for getting started, using functions like Kevin does, or as a company or product capability, see the two posts below:

* [How to Build & Integrate with Functions using OpenFaaS](https://www.openfaas.com/blog/integrate-with-openfaas/)
* [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)

If you're running OpenFaaS in production and would like to talk through your setup, [get in touch](https://www.openfaas.com/pricing) or join the [weekly Office Hours call](https://docs.openfaas.com/community/).
