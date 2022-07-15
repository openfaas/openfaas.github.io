---
title: "The Next Generation of Queuing for OpenFaaS"
description: "Learn why we're investing in a new queuing system for OpenFaaS and what that means for your functions."
date: 2022-07-20
image: /images/2022-07-next-gen-queueing/background.jpg
categories:
- architecture
- queue
- nats
author_staff_member: han
---

Learn why we're investing in a new queuing system for OpenFaaS and what that means for your functions.

OpenFaaS has a feature that lets users call their functions asynchronously. Asynchronous function invocations are added to a queue and will be processed in the background by the OpenFaaS queue system.

This has proven to be a powerful feature and one of the reasons our customers and community choose OpenFaaS to run their functions. That’s why we are heavily investing in the creation of its successor. In this article we will take a look at why asynchronous invocations can be useful for you and what changes we made to the OpenFaaS async system to make it even better.

## When should you use synchronous or asynchronous invocations?
OpenFaaS asynchronous functions decouple the HTTP transaction between the caller and the function. When a function is invoked synchronously the caller waits until it is done. With asynchronous invocations the caller does’t have to wait. An “accepted” response is returned immediately and the invocation will be processed in the background by the OpenFaaS queue system.

- Sync

    Synchronous invocations are the simplest and easiest to consume. A short example. When a function to generate a PDF is invoked the caller will wait until the function finishes and receive a url to the generated PDF in the response. If the whole process only takes a few seconds this may be the ideal approach. If generating the PDF takes a long time it might be better to invoke the function asynchronously.

    ![Synchronous](/images/2022-07-next-gen-queueing/sync.png)

- Async

    When the function to generate a PDF is invoked asynchronously, the caller will immediately receive a HTTP 200 response. The request is added to a queue and processed at a later time by the queue-worker. The caller can subscribe for a response via a webhook. This webhook is used to post the result of the function invocation. In this example it will receive the url to the generated PDF.

    ![Asynchronous](/images/2022-07-next-gen-queueing/async.png)

Having the async feature on by default for every function gives you a fire and forget experience. OpenFaaS makes it easy to get started but at the same time gives you the flexibility to scale and tune the system according to your requirements. There is no need to architect your own queue system. Additional features, such as the ability to retry failed invocations or receive invocation results via a webhook as soon as they are available, make it possible to create advanced workflows.

> A detailed description of how this works and all of the features can be found in the [OpenFaaS documentation](https://docs.openfaas.com/reference/async/).

### Use-cases
- Receiving webhooks

    If you need to receive data from a partner’s webhook they may need you to send a HTTP 200 OK within 1 second. A failure is assumed and the message retried if you break this contract. This works fine if your function can complete within one second. If there is a risk that it can’t, then you can have the webhook invoke the asynchronous URL of that function. It will reply within several milliseconds whilst processing the data in the background.

- Long running jobs

    OpenFaaS has no hard limits on the time a function may take to complete. This makes it well suited for long running functions. You might want to use functions to run your machine learning model or do some kind of image processing. While it is possible to invoke these long running functions synchronously and have the caller wait for the result we  recommend invoking them asynchronously. They can be given a callback URL to receive a notification with the result when they complete.

- Resilient data processing

    The built-in retry capabilities of the queue system allow you to use a “back pressure” pattern to ensure all of your requests get processed without losing data. In the article, [How to process your data the resilient way with back pressure](https://www.openfaas.com/blog/limits-and-backpressure/), Alex shows you how to use this pattern and how it plays together nicely with other OpenFaaS components and features like the autoscaler.

## Why are we making this investment?
There were a couple of factors that led us to create a new queuing subsystem for OpenFaaS. For one thing, the current async workflow uses NATS Streaming to run function invocations in the background. The NATS Streaming server is being deprecated and will not receive any more critical bug fixes and security fixes as of June 2023. It is replaced by a new distributed persistence system called JetStream. This meant we had to migrate all of our queuing components over to NATS JetStream.

We took this opportunity to add new features and improve our queuing subsystem as a whole to solve some of the pains and limitations our customers and the community ran into.

Our goals:
- Improve observability of the system by introducing a structured log format and adding metrics
- Allow for graceful shutdown
- Simplify the system configuration

## What is new?
- Retries

    We kept the same user experience for function retries. User can specify a list of http codes that will be retried a number of times using an exponential back-off algorithm. By leveraging some of the features provided by JetStream we are able to provide a more robust and reliable retry mechanism.

- Metrics

    The new queue-worker comes with the addition of metrics so users can monitor the behaviour of their queues. The metics can help you get insights in things like the number of messages that have been submitted to the queue over a period of time, how many messages are waiting to be completed and the total number of messages that where processed.

    ![demo of the queue-worker dashboard showing the number of pending messages, message ingestion rate and processing rate per queue](/images/2022-07-next-gen-queueing/queue-worker-dashboard.png)
    > A demo of the queue-worker dashboard showing the number of pending messages, message ingestion rate and processing rate per queue

- Configuration

    We tried to take away some of the sources of confusion and strange behaviour that could be caused by an incorrectly configured `ack_wait` value. The new queue-worker will now automatically extend the ack window for functions that require more time to complete.

- Structured logs

    On popular request by our users we added support for structured logging. This is especially useful if you are using some kind of log monitoring system. The log level is configurable and it is possible to output json formatted logs.

    ![Log excerpt from the queue-worker showing the logs in console format](/images/2022-07-next-gen-queueing/structured-logs.png)
    > Log excerpt from the queue-worker showing the logs in console format.

- Graceful shutdown

    We improved the shutdown sequence of the queue worker. When it is terminated due to rollout or a node being shut-down it will stop to accept new work and attempt to finish any invocations that are in progress.

- Migration to JetStream

    Moving over to JetStream means that we can rely on its clustering capabilities for a highly available and scalable system. This improves the durability of the OpenFaaS queue system and allows it to survive a crash or loss of a node. 

## Next steps
The new queuing subsystem for OpenFaaS comes with a lot of improvements. The most significant one moving away from the soon to be deprecated NATS Streaming server. On top of that, new features like metrics and support for structured logging in json format improve the observability of the system. The redesigned async system with NATS JetStream will be available for our [OpenFaaS Pro](https://www.openfaas.com/support/) customers soon.

This is what our customers have to say about this upcoming release:

> We really like the way you can invoke any function via a queue - getting the result as soon as it's ready through a callback. The result can get sent to another function to construct a workflow, or to another part of your system via a HTTP call. The introduction of JetSteam will be a massive improvement to those services. Not only in performance but the addition of detailed metric features will give us much more insight. Lastly, being able to install/configure/manage JetStream HA as part of the Faasnetes helm chart is another big win for us. OpenFaaS has done an excellent job meeting our needs as a customer with additions such as this.
>
> — Billy Forester (Check Point)

Checkout all the [features OpenFaaS Pro](https://docs.openfaas.com/openfaas-pro/introduction/) gives you to run in production.

Want to learn more about the OpenFaaS async system?

Find out:
- [How to make use of asynchronous invocations](https://docs.openfaas.com/reference/async/)
- [How to implement back-pressure with retries](https://docs.openfaas.com/openfaas-pro/retries/)

You may also like:
- [How to process your data the resilient way with back-pressure](https://www.openfaas.com/blog/limits-and-backpressure/)


If you’d like to talk to us about anything we covered in this blog post: [feel free to reach out](https://www.openfaas.com/support/)
