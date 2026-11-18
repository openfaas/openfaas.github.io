---
title: "How to make events durable with OpenFaaS Async"
description: "Learn how event connectors can invoke functions asynchronously for added durability and retries."
date: 2025-01-14
author_staff_member: han
categories:
  - event-connector
  - openfaas
  - serverless
  - event-driven
  - automation
dark_background: true
image: "/images/2025-01-event-connector-backpressure/background.png"
hide_header_image: true
---

Learn how event connectors can invoke functions asynchronously for added durability and retries.

## Introduction

OpenFaaS supports event-driven architectures through the built-in asynchronous function concept and event connectors. With the connector pattern, you can trigger functions from any event-source or messaging system, without having to add SDKs or subscription code to each of your functions.

In this post we will see how asynchronous function invocations and event connectors can be used together to process events in a resilient way.

We will also highlight recent changes to the connector SDK, which is used by all connectors, to improve support for async invocations. By introducing back pressure through a configurable limit on the number of inflight async invocations, we've solved an issue where events from a source system could overwhelm the OpenFaaS async queue by submitting all events without restraint.

## The event connector pattern

All OpenFaaS connectors operate in the same way, they listen or subscribe to events on the source system like Kafka, RabbitMQ or AWS SNS. When a new event is received the connector maps the event payload to an HTTP request and invokes all functions that have registered interest for the event. Events are mapped to functions by setting the topic annotation on a function.

![Diagram of the event-connector pattern.](/images/2025-01-event-connector-backpressure/connector-pattern.png)

> Event-connector pattern. Each topic, subject or queue can be broadcast to one or many functions.

There are many connectors available for event sources like Apache Kafka, PostgreSQL, Cron, RabbitMQ, AWS SQS etc. Check out the [complete list of event triggers](https://docs.openfaas.com/reference/triggers/#openfaas-pro-triggers) in the docs.

By default connectors invoke functions synchronously. When a connector receives a new event from the source it invokes all functions that have registered interest for the event. If one of the invocations fails due to for example a network issue or an unreliable upstream API there is no way to retry the invocation.

If you need events to be processed in a resilient way, the OpenFaaS event connectors can be configured to invoke functions asynchronously. By invoking the function through [the OpenFaaS async system](https://docs.openfaas.com/reference/async/) you get to use all the benefits that come with it, like automatic retries.

## What invocation type should you choose?

- **Synchronous invocations** are great for short-running functions where immediate processing is required. If functions run for to long, events may back-up creating a large backlog of events that cannot be handled.
- **Asynchronous invocations** are recommended for long-running function or when resilience is critical. Async function invocations support configurable retries to ensure events get process successfully.
- **Async invocations with backpressure** should be used if you need to control the rate of event submission to the OpenFaaS async queue. Use this to avoid overwhelming the OpenFaaS queue and keep messages in the source queue until capacity is available.

## Limit inflight async invocations for better back pressure control

Without any form of back pressure a connector might start consuming messages too quickly and submit messages from the source queue to the OpenFaaS async queue all at once. To prevent this we added a new feature to our connector-SDK to limit the number of async invocations that can be ongoing for a connector deployment at once.

To keep track of the number of inflight invocations we use a counter. The counter is incremented when the connector starts an asynchronous invocation and it is decremented when the queue-worker has completed the invocation. Because different instances of a connector need to be able to increment or decrement the counter, the counter needs to be distributed and safe to be updated by multiple processes.

![Inflight limit counter architectural diagram](/images/2025-01-event-connector-backpressure/inflight-counter.png)
> This conceptual diagram shows how a connector keeps track of async invocation count to limit the number of inflight invocations. The counter has to be in shared storage because there can be more than one replica of the event connector and any one of them can receive the callback from the queue-worker.

Several options for storing the counter were considered, a simple database row or a key value entry in [Valkey](https://valkey.io/) or Redis. They all support atomic increments and decrements of counters. Adding a database or Valkey would mean adding a new dependency to the OpenFaaS stack, which is something we like to avoid to keep the deployment and operation of OpenFaaS simple.

NATS is already part of the stack and has support for [Key/Value store](https://docs.nats.io/nats-concepts/jetstream/key-value-store) functionality. Unfortunately NATS KV does not support distributed atomic counters. [The feature has been requested](https://github.com/nats-io/nats-server/issues/2656) and it might become part of the next NATS 2.11 release.
Instead of using the key value store we tried using a [JetStream Stream](https://docs.nats.io/nats-concepts/jetstream/streams) with stream limits to implement a counter. It turned out to work great for our purpose.

### How to implement an atomic counter using a NATS Stream

A new stream is created for each counter with the following Stream configuration options.

`MaxMsgs` is set to the maximum value of the counter. In our case this will be the maximum number of inflight async requests. The `DiscardPolicy` is set to `DiscardNew`, this ensures new messages are refused from being added to the stream if the `MaxMsg` limit is exceeded.

To increment the counter we try to publish a new message to the stream. If the publish returns an error indicating the maximum message count is exceeded we know the counter has reached its maximum value. This means we can't do any more work and the next invocation is delayed until the counter is decremented.

The retention Policy of the stream is set to an `InterestPolicy`. This ensures messages are deleted from the stream when they are ack'ed. To decrement the counter when an async function invocation is finished we simply pull the next message from the stream and acknowledge it. Because the stream is configured with an interest retention policy the message will be removed from the stream.

To get the current value of the counter you can simply get the count of messages in the stream.

## Conclusion

We saw how event connectors can make use of [retries](https://docs.openfaas.com/openfaas-pro/retries/) to process events in a resilient way, by configuring them to invoke functions asynchronously.

In addition we discussed recent changes that allow you to limit the number of inflight async invocations for a connector deployment. This can be required for certain event sources, like Kafka, if you want to prevent draining all events from the source system into the OpenFaaS async queue too quickly.

The [Kafka connector](https://docs.openfaas.com/openfaas-pro/kafka-events/) is the first connector that supports limiting inflight async invocations, other connectors will follow soon.

You might want to try out these walk though post to deploy one of the OpenFaaS connectors:

- [Trigger Your OpenFaaS Functions from RabbitMQ Queues](https://www.openfaas.com/blog/rabbitmq-connector/)
- [Staying on topic: trigger your OpenFaaS functions with Apache Kafka ](https://www.openfaas.com/blog/kafka-connector/)
- [Trigger OpenFaaS functions from PostgreSQL with AWS Aurora](https://www.openfaas.com/blog/trigger-functions-from-postgres/)
- [How to integrate OpenFaaS functions with managed AWS services](https://www.openfaas.com/blog/integrate-openfaas-with-managed-aws-services/)

[Reach out to us](https://openfaas.com/pricing) if you have any questions about the event connectors, or OpenFaaS in general.

See also:

* [Overview of OpenFaaS event connectors](https://docs.openfaas.com/reference/triggers/)
* [Asynchronous vs. synchronous invocations](https://docs.openfaas.com/reference/async/)