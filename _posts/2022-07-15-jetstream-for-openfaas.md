---
title: "The Next Generation of Queuing: JetStream for OpenFaaS"
description: "Learn why we're building our next generation of queuing with JetStream and what it means for your functions."
date: 2022-07-21
image: /images/2022-07-jetstream-for-openfaas/background.jpg
categories:
- async
- architecture
- queue
- nats
author_staff_member: han
author_staff_member_editor: alex
---

Learn why we're building our next generation of queuing with JetStream and what it means for your functions.

Any OpenFaaS function can be invoked synchronously, for an instant response to the caller, or asynchronously, using a queue. Queued invocations are ideal for long running requests, background jobs, and for batches of requests, where the caller doesn't need a response or can subscribe for the response out of band.

The asynchronous (async) feature has proven popular with many of our community users and customers. They can simply queue up as many invocations as required, and know that they'll be processed as and when there's capacity. In this article, we'll cover the differences between synchronous and asynchronous invocations, then talk about the next generation of system built with NATS JetStream, we're calling it *"JetStream for OpenFaaS"*.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">The new <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> queue-worker for JetStream will have metrics.<br><br>Watching the number of pending messages per queue go down as my queue-workers gradually burn through the work. <a href="https://t.co/vyAnptznIt">pic.twitter.com/vyAnptznIt</a></p>&mdash; Han Verstraete (@welteki) <a href="https://twitter.com/welteki/status/1541715483346567168?ref_src=twsrc%5Etfw">June 28, 2022</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

## When should you use sync or async for your functions?

In OpenFaaS, an asynchronous invocation decouples the HTTP request from the response. When a function is invoked synchronously the caller may wait, being blocked until the whole response is available from the invocation. OpenFaaS also supports streaming responses, however, if the transaction is going to take 5 minutes to stream all its data, the caller still has to wait on the function to finish.

With an asynchronous invocation, the caller simply submits a request via HTTP POST, and carries on, knowing that the work will be processed at some point in the future. A Call ID is generated via the HTTP header `X-Call-Id`, which can be used to correlate any responses or logs in the queuing system. By default, the response from the function call is discarded, unless the caller also submits a `X-Callback-Url`, in which case, the response will be sent to the URL provided.

```bash
faas-cli store deploy inception

curl --data-binary @./image.png \
  http://127.0.0.1:8080/async-function/inception \
  -H "X-Callback-Url: http://127.0.0.1:8080/function/inception-response"
```

In the above example, we want to determine the contents of `image.png` by using the `inception` function in the function store. The `inception-response` function will receive the response, along with the `X-Call-Id` provided back when the above HTTP call completes. Call IDs can be used to correlate requests and responses in OpenFaaS. 

- Synchronous (sync)

    Synchronous invocations are the simplest and easiest to consume. A short example. When a function to generate a PDF is invoked the caller will wait until the function finishes and receive a url to the generated PDF in the response. If the whole process only takes a few seconds this may be the ideal approach. If generating the PDF takes a long time it might be better to invoke the function asynchronously.

    ![Synchronous](https://docs.openfaas.com/images/sync.png)

- Asynchronous (async)

    When the function to generate a PDF is invoked asynchronously, the caller will immediately receive a HTTP 200 response. The request is added to a queue and processed at a later time by the queue-worker. The caller can subscribe for a response via a webhook. This webhook is used to post the result of the function invocation. In this example it will receive the url to the generated PDF.

    ![Asynchronous](https://docs.openfaas.com/images/async.png)

Having the async feature on by default for every function gives you a fire and forget experience. OpenFaaS makes it easy to get started but at the same time gives you the flexibility to scale and tune the system according to your requirements. There is no need to architect your own queue system. Additional features, such as the ability to retry failed invocations or receive invocation results via a webhook as soon as they are available, make it possible to create advanced workflows.

> A detailed description of how this works and all of the features can be found in the [OpenFaaS documentation](https://docs.openfaas.com/reference/async/).

### Async use-cases

You can explore some community and customer use-cases in the [ADOPTERS.md file](https://github.com/openfaas/faas/blob/master/ADOPTERS.md) and in [past conference talks and blog posts](https://github.com/openfaas/faas/blob/master/community.md).

Async can be used for any OpenFaaS function invocation, where the response is not required immediately, but is either discarded or made available at a later time. Here are some common patterns we keep seeing:

- Batch processing and machine learning

    Since async doesn't require a caller to wait for a response, it's ideal for processing large batches of data in Machine Learning pipelines. The pattern can be used to fan out many different requests and process them at scale.

- Resilient data pipelines

    The built-in retry capabilities of the queue system allow you to use a "back pressure" pattern to ensure all of your requests get processed without losing data. In the article, [How to process your data the resilient way with back pressure](https://www.openfaas.com/blog/limits-and-backpressure/), Alex shows you how to use this pattern and how it plays together nicely with other OpenFaaS components and features like the autoscaler.

- Receiving webhooks

    If you need to receive data from a partner's webhook they may need you to send a HTTP 200 OK within 1 second. A failure is assumed and the message retried if you break this contract. This works fine if your function can complete within one second. If there is a risk that it can’t, then you can have the webhook invoke the asynchronous URL of that function. It will reply within several milliseconds whilst processing the data in the background.

- Long running jobs

    OpenFaaS has no hard limits on the time a function may take to complete. This makes it well suited for long running functions. You might want to use functions to run your machine learning model or do some kind of image processing. While it is possible to invoke these long running functions synchronously and have the caller wait for the result we  recommend invoking them asynchronously. They can be given a callback URL to receive a notification with the result when they complete.

## Why are we investing in JetStream for OpenFaaS?

In June 2022, [Synadia](https://synadia.com/), the author of NATS will deprecate NATS Streaming, which we've been using in OpenFaaS since 2016.

> All OpenFaaS users will need to move to NATS JetStream before June 2022, at which point, the vendor will stop providing support and fixes.

When we heard about the deprecation, we started R&D efforts with JetStream. It is very different to NATS Streaming, and required so much rework, that we just started over from the beginning. That gave us an opportunity to review our original design choices and a chance to look at how queueing works with fresh eyes.

Here's a quick overview of differences between JetStream and NATS Streaming:

* It uses the `nats-server` binary instead of the `nats-streaming-server` binary
* It can be installed using the "normal" [NATS Helm Chart](https://docs.nats.io/running-a-nats-service/nats-kubernetes/helm-charts)
* Messages are published on "streams" and received by "consumers" which are similar to consumer groups in other systems
* It's got more flexible message retention periods and policies, for efficient storage and resource consumption
* It supports pub/sub and durable subscriptions, with wildcard subscriptions available
* It's conceptually more complex, requiring a knowledge of Streams, Consumers and Subscriptions
* It can be run in a HA mode - using Gossip to establish peers and cluster membership, and Raft to distribute messages between peers
* [It has much improved documentation](https://docs.nats.io/nats-concepts/jetstream)

> Want to know even more? Our friends at Form3 Tech spoke at Gophercon UK about why they picked JetStream for the next generation of their payments processing product: [GopherCon UK 2021: Adelina Simion - Using NATS](https://www.youtube.com/watch?v=AhnL5addsVo)

The configuration and terminology for NATS JetStream may take some getting used to, but we're here to help.

Here's a quick conceptual diagram of JetStream for OpenFaaS.

![Conceptual Diagram](/images/2022-07-jetstream-for-openfaas/jsof.png)
> 1000 messages are queued up for the inception function, with two queue workers pulling off 100 messages at a time for invocation. The stream maintains all the messages, but the "consumer" is like a group that tracks where the group of queue workers are at in the queue.

In addition to migrating to NATS JetStream concepts and primitives, we also spent time listening to customers and identified a few key areas to improve upon upon our queueing system:

* Add observability through metrics - it was very hard to know how many messages were pending in NATS Streaming, or to determine a queue depth
* Simplify timeouts - NATS Streaming requires an "ack wait" value, which is how long a message can be taken off a queue, before being acknowledged
* Graceful shutdowns - we needed a more graceful shutdown to help customers understand the effect of scaling the queue-worker dynamically, and using spot instance, which are short-lived Kubernetes nodes
* Separates queues - setting up separate queues was hard and manual, users requested a helm chart or Kubernetes CRD for configuring this
* Improve upon logging - whilst we improved logs for OpenFaaS Pro, and removed sensitive information for GDPR, the logs were not "structured", so were hard to ingest in a pipeline

## What's new in JetStream for OpenFaaS?

Here's what one of our customers from Check Point Software Limited had to say:

> We really like the way that we can invoke any of our functions using a queue, getting the result as soon as it's ready through a callback. It helps us scale out our services and move really fast to add new features. The results from the queued invocations are either sent to other functions or to our internal APIs to build workflows.
> 
> For us, the introduction of JetSteam will be a massive improvement to those services. Not only in performance, but the addition of detailed metric features will give us much more insight into how our systems are running.
> 
> Lastly, being able to install/configure/manage JetStream HA as part of the faas-netes helm chart is another big win for us. OpenFaaS has done an excellent job meeting our needs as a customer with additions such as this.
>
> — Billy Forester, Engineering Director

- Detailed metrics

    The new queue-worker comes with the addition of metrics so users can monitor the behaviour of their queues. The metics can help you get insights in things like the number of messages that have been submitted to the queue over a period of time, how many messages are waiting to be completed and the total number of messages that where processed.

    ![demo of the queue-worker dashboard showing the number of pending messages, message ingestion rate and processing rate per queue](/images/2022-07-jetstream-for-openfaas/queue-worker-dashboard.png)
    > A demo of the queue-worker dashboard showing the number of pending messages, message ingestion rate and processing rate per queue

- Extendable timeouts

    We tried to take away some of the sources of confusion and strange behaviour that could be caused by an incorrectly configured `ack_wait` value. The new queue-worker will now automatically extend the ack window for functions that require more time to complete.

- Efficient retries

    Users can specify a list of HTTP codes that should be retried using a exponential back-off algorithm and how many times. By leveraging some of the features provided by JetStream we are able to provide a more robust efficient, and native retrying system.

- Structured JSON logging

    On popular request by our users in the [OpenFaaS Customer Community](https://github.com/openfaas/openfaas-pro) we switched to structured logging using the [Zap](https://github.com/uber-go/zap) framework by Uber. The logs can be formatted for readability, during development, or in JSON for a log aggregator like ELK or Grafana Loki. 

    ![Log excerpt from the queue-worker showing the logs in console format](/images/2022-07-jetstream-for-openfaas/structured-logs.png)
    > Log excerpt from the queue-worker showing the logs in console format.

- Graceful shutdowns

    We improved the shutdown sequence of the queue worker. When it is terminated due to rollout or a node being shut-down it will stop to accept new work and attempt to finish any invocations that are in progress.

- High Availability (HA) with JetStream

    NATS JetStream has much better durability than NATS Streaming, we've provided instructions in the [OpenFaaS Customer Community](https://github.com/openfaas/openfaas-pro) for how we think you should configure OpenFaaS and JetStream to tolerate failures, and be most resilient.

    The new configuration means that the queuing system can keep running, even if a NATS Server should crash, or a spot instance is removed by your cloud provider.

- Dedicated queues through a new helm chart

    OpenFaaS will ship with a "mixed queue", where all invocations run in the same queue. However, if you have special requirements, you can set up your own separate queue and queue-worker using a new helm chart.

    Prior to this, the process was very manual, and didn't have any metrics available. 

## The Path Ahead

The new queueing system is something all OpenFaaS users will need to move to, ideally well ahead of the deprecation date for NATS Streaming, set by Synadia. The new queueing system is HA, scales out much better than before, and integrates other suggestions from customers - like metrics, JSON logs, and more controlled shutdowns.

We've now invested around 4 months of R&D into building JetStream for OpenFaaS, and are looking to customers to help test and validate the new design. We were encouraged by early feedback from Check Point Software Limited, Surge and the Synadia team themselves.

* Customers can get started here: [Testing the new async system with JetStream](https://github.com/openfaas/openfaas-pro/discussions/36)
* Feel free to reach out to us, to [talk to us about anything we covered in this blog post](https://www.openfaas.com/support/)
* Check out OpenFaaS Pro benefits: [Introduction to OpenFaaS Pro](https://docs.openfaas.com/openfaas-pro/introduction/)

Want to learn more about the OpenFaaS async system?

Find out:
- [How to process your data the resilient way with back-pressure](https://www.openfaas.com/blog/limits-and-backpressure/)
- [How to make use of asynchronous invocations](https://docs.openfaas.com/reference/async/)
- [How to implement back-pressure with retries](https://docs.openfaas.com/openfaas-pro/retries/)
