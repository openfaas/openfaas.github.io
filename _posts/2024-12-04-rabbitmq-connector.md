---
title: "Trigger Your OpenFaaS Functions from RabbitMQ Queues"
description: "Learn how to connect RabbitMQ to OpenFaaS to trigger functions from new and existing message queues."
date: 2024-12-04
author_staff_member: alex
categories:
  - rabbitmq
  - openfaas
  - serverless
  - event-driven
  - automation
dark_background: true
image: "/images/2024-12-rabbit/background.png"
hide_header_image: true
---

Learn how to connect RabbitMQ to OpenFaaS to trigger functions from new and existing message queues.

### Introduction

When distributed systems need to run work in the background, developers often turn to message brokers like RabbitMQ, commit-logs like Kafka, or pub/sub systems like NATS. These components decouple the request from the response, allowing for asynchronous processing and scaling out to handle huge amounts of work.

OpenFaaS supports event-driven architectures through the built-in asynchronous function concept, and through event connectors, to import events from external systems. In this post, we'll explore how to use the RabbitMQ connector for OpenFaaS to trigger functions from RabbitMQ queues.

Whether you're automating tasks, processing high-volume streams, or orchestrating microservices, this connector is designed to provide flexibility, security, and simplicity. It supports both standard RabbitMQ features and enhanced options like TLS authentication and custom Certificate Authorities (CAs).

In this post, we’ll explore:

- Why RabbitMQ is a great fit for OpenFaaS.
- How to set up the connector for secure, event-driven workflows.
- Practical examples and best practices for integration.

This connector is available for [OpenFaaS Standard and Enterprise editions](https://openfaas.com/pricing/), with commercial support making it suitable for production.

![Conceptual diagram](/images/2024-12-rabbit/conceptual.png)
> Above: example architecture.

The diagram above shows an example interaction between an existing system and a new OpenFaaS function. The role of the function is to provision a new customer record in the database, taking a JSON input containing a customer email as its input.

It gets triggered by the RabbitMQ connector, when a message is published to the *activate* topic, then when it has completed its work, publishes a response to the *activated* topic. The existing system would then consume this response and take further action such as sending a welcome email to the customer, or this could be handled by another function as part of a chain.

---

### Why Choose RabbitMQ for OpenFaaS?

RabbitMQ is not the only option for OpenFaaS, but it is one of the most widely-used message brokers, trusted for its:

- **Reliability**: Persistent queues and fault tolerance.
- **Flexibility**: Broad protocol support and rich feature set.
- **Scalability**: High throughput for real-time workloads.

By pairing RabbitMQ with OpenFaaS, you can:

1. Decouple producers and consumers for modular architectures.
2. Handle bursty workloads with RabbitMQ's queuing capabilities.
3. Build workflows triggered by real-time events.

You can also get most of these benefits from using the built-in asynchronous system in OpenFaaS with [NATS JetStream](https://docs.openfaas.com/openfaas-pro/jetstream/) which supports persistence, at-least-once delivery, and retries.

When you configure a event-connector, you can decide whether you want the connector to make synchronous requests, or whether it should enqueue messages into NATS JetStream for asynchronous processing.

### Getting Started with the RabbitMQ Connector

#### **1. Install the Connector**

Deploy the RabbitMQ connector using its Helm chart. Create a `values.yaml` file to define your RabbitMQ connection and queue subscriptions:

```yaml
rabbitmqURL: "amqps://rabbitmq.rabbitmq.svc.cluster.local:5671"

queues:
  - name: queue1
    durable: true
    autodelete: false
```

Key configurations:
- **`rabbitmqURL`**: Use `amqps://` for TLS-secured connections, ensuring encrypted communication with the RabbitMQ broker.
- **`queues`**: Define queues to subscribe to, including options like durability and auto-delete.
- **`asyncInvocation`**: Set to `true` to enqueue all messages into NATS JetStream for asynchronous processing.

For advanced security, the connector supports:
- **Authentication**: RabbitMQ credentials can be securely provided through Kubernetes secrets.
- **Custom Certificate Authorities (CAs)**: Use your internal CA for trusted communication between the connector and RabbitMQ.

You can find more details in [the docs](https://docs.openfaas.com/openfaas-pro/rabbitmq-events/) and the [helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/rabbitmq-connector).

#### **2. Annotate a Function**

Just like any other connector for OpenFaaS, you can connect a function to your RabbitMQ queue by setting the `topic` annotation, with the name of the queue:

```bash
faas-cli store deploy printer \
  --annotation topic=queue1
```

The connector invokes this function whenever a message is published to `queue1`.

If you want a function to be invoked by more than one queue, then you can add them as a comma-separated list: `--annotation topic=queue1,queue2`.

#### **3. Trigger an invocation from a queue**

To publish a test message, you can use your existing infrastructure, an OpenFaaS function, or the [RabbitMQ management CLI](https://www.rabbitmq.com/docs/management-cli):

```bash
./rabbitmqadmin publish \
  routing_key="queue1" payload='Hello, Task Queue!' properties='{"message_id":"42"}'
```

Check the function logs to confirm message processing:

```bash
faas-cli logs printer
```

Example output:

```plaintext
faas-cli logs printer

2024-12-03T14:36:03Z X-Connector=[connector-sdk openfaasltd/rabbitmq-connector]
2024-12-03T14:36:03Z X-Topic=[queue1]
2024-12-03T14:36:03Z Accept-Encoding=[gzip]
2024-12-03T14:36:03Z Content-Type=[text/plain]
2024-12-03T14:36:03Z X-Call-Id=[d0ab9f9e-0c93-46b1-a4dd-695a037acb38]
2024-12-03T14:36:03Z 2024/12/03 14:36:03 POST / - 202 Accepted - ContentLength: 0B (0.0003s)
2024-12-03T14:36:03Z X-Forwarded-Host=[gateway.openfaas:8080]
2024-12-03T14:36:03Z X-Rabbitmq-Msg-Id=[1]
2024-12-03T14:36:03Z X-Start-Time=[1733236563468386644]
2024-12-03T14:36:03Z X-Forwarded-For=[10.42.0.13:55796]
2024-12-03T14:36:03Z X-Rabbitmq-Routing-Key=[queue1]
2024-12-03T14:36:03Z User-Agent=[openfaas-gateway/0.4.34]
2024-12-03T14:36:03Z 
2024-12-03T14:36:03Z Hello, Task Queue!
2024-12-03T14:36:03Z 
```

The connector passes RabbitMQ message metadata as HTTP headers to your function, including:
* `X-Topic` The queue name that triggered the function.
* `X-Rabbitmq-Msg-Id` - the message identifier.
* `X-Rabbitmq-Routing-Key` - the routing key of the message.

### Real-World Use Cases

Many of the tasks for RabbitMQ can be handled by NATS JetStream, so we'd recommend that you primarily use RabbitMQ to enqueue messages into NATS JetStream from existing systems, and applications with your company.

However, RabbitMQ, can be used for a variety of use-cases, including:

1. **Task Orchestration**:
   Automatically process and dispatch tasks, such as image resizing or video encoding, by publishing jobs to RabbitMQ queues.

2. **IoT Data Pipelines**:
   Collect and process high-frequency sensor data with functions triggered from RabbitMQ queues.

3. **Order Processing**:
   Integrate with e-commerce platforms to process and respond to customer orders in real-time.


### Advanced Features and Best Practices

- **Custom Content Types**:
  The default helm chart sets a Content-type header of `text/plain` to functions, but you can change this to `application/json` or other formats, in the values.yaml file.

- **Scaling**:
  The RabbitMQ connector can be scaled by adjusting the amount of replicas running. You can do this manually as required, or by using Kubernetes' built-in Horizontal Pod Autoscaler (HPA) to dynamically adjust connector capacity based on CPU/RAM, or queue activity.

- **Security**:
  For environments with strict compliance requirements, ensure all communication with RabbitMQ is encrypted using TLS and trusted with a custom CA.

### Conclusion

We released the RabbitMQ connector for teams and companies that already use RabbitMQ, and wish to trigger their OpenFaaS functions from these existing systems. If you're approaching OpenFaaS and have no existing message broker in use such as AWS SQS, Apache Kafka, then we strongly recommend using the built-in [NATS JetStream support for asynchronous processing](https://docs.openfaas.com/openfaas-pro/jetstream/), it provides a convenient HTTP API, and is built into every OpenFaaS installation.

[Reach out to us](https://openfaas.com/pricing) if you'd like a demo, or if you have any questions about the RabbitMQ connector, or OpenFaaS in general.

See also:

* [View other event connectors](https://docs.openfaas.com/reference/triggers/)
* [NATS JetStream for OpenFaaS](https://docs.openfaas.com/openfaas-pro/jetstream/)
* [Asynchronous vs. synchronous invocations](https://docs.openfaas.com/reference/async/)