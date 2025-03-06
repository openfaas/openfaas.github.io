---
title: "Staying on topic: trigger your OpenFaaS functions with Apache Kafka"
description: Martin outlines how you can make use of Apache Kafka to trigger your functions in OpenFaaS through the new connector-sdk component.
date: 2019-04-17
image: /images/kafka-connector/aluminium-building.jpg
categories:
  - kafka
  - tutorial
  - examples
author_staff_member: martin
dark_background: true
---

In this post I will show you how you can build subscriptions between your OpenFaaS functions and your Apache Kafka topics. I'll be using Kubernetes to show you around, but the connector-sdk works with any OpenFaaS provider.

OpenFaaS is solving real problems for our [end-user community](https://docs.openfaas.com/#users-of-openfaas), many of whom are now relying on the project to in production and for core services. The OpenFaaS Pro kafka-connector was created to help commercial users integrate functions into their existing systems.

OpenFaaS functions and microservices are accessible over HTTP endpoints via the Gateway service, but let's explore how other events can be used to trigger our functions.

This tutorial describes the Kafka connector which is part of the OpenFaaS Pro bundle. [Find out more](https://openfaas.com/support/)

## Apache Kafka

According to [Datadog](https://www.datadoghq.com/blog/monitoring-kafka-performance-metrics/):

> [Apache Kafka](https://kafka.apache.org) is an open-source stream-processing software platform. The project aims to provide a unified, high-throughput, low-latency platform for handling real-time data feeds. Its storage layer is essentially a "massively scalable pub/sub message queue designed as a distributed transaction log".

![](https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/Overview_of_Apache_Kafka.svg/1280px-Overview_of_Apache_Kafka.svg.png)

At a high level the important concepts are Producers, Consumers and Brokers which communicate with each-other via messages attached to Topics.

The way it works is that the Producer is sending messages on specific Topics to the Broker, then the Consumers poll all the topics of interest from the Brokers. This approach is popular in distributed systems because it decouples direct communication between services and allows messages to be replayed or redelivered when required from a persistent log.

See also: [Apache Kafka Documentation](https://kafka.apache.org/documentation/).

## Kafka Connector

The [kafka-connector](https://github.com/openfaas-incubator/kafka-connector) is designed to connect Kafka topics to OpenFaaS Functions. After deploying the kafka-connector and pointing it at your broker, you can connect functions to topics by adding a simple annotation via your functions' stack.yaml file.

Conceptual architecture diagram:

![Kafka Diagram](/images/kafka-connector/overview-diagram.jpg)

The connector makes use of the connector-sdk, a Golang library which periodically queries the Gateway’s list of functions and then builds a map between each function and a topic. This map is then used to invoke functions when messages arrive on a given topic.

Each OpenFaaS connector that the community develops can take advantage of this shared functionality and its only responsibility is to read from a data source or queue and forward the message on.

> See also: [Triggers & Events in OpenFaaS](https://docs.openfaas.com/reference/triggers/)

## Pre-requisites

For this tutorial we will use Kubernetes. I have chosen minikube for my own local cluster, but alternatives are available.

* Install OpenFaaS using the [getting started guide](https://docs.openfaas.com/deployment/kubernetes/).

* Install the [faas-cli](https://docs.openfaas.com/cli/install/)

* Set your`OPENFAAS_URL` environmental variable so that it points at your gateway.

## Deploy Apache Kafka

A development version of Apache Kafka has been made available so that you can get this tutorial up and running in a few minutes. You can also customise the connector to use your existing deployment of Kafka or to use a managed provider.

For a self-hosted version, you can use Confluent's chart:

```bash
arkade install kafka
```

## Deploy the connector with helm

Create the required secret with your OpenFaaS Pro license code:

```bash
$ kubectl create secret generic \
    -n openfaas \
    openfaas-license \
    --from-file license=$HOME/.openfaas/LICENSE
```
Add the OpenFaaS charts repository:

```sh
$ helm repo add openfaas https://openfaas.github.io/faas-netes/
$ helm repo update
```

Install the Kafka Connector with default values:

```bash
$ export BROKER_HOST=cp-helm-charts-cp-kafka-headless.default:9092

$ helm upgrade kafka-connector openfaas/kafka-connector \
    --install \
    --namespace openfaas \
    --set topics="payment-received" \
    --set brokerHost="$BROKER_HOST" \
    --set printResponse="true" \
    --set printResponseBody="true"
```

* Set the `topics` to the topics you want to subscribe to as a comma separated list without separating spaces

* If you deployed Kafka to a remote location or a different namespace or port then just update the `brokerHost` value.

We have now deployed the following components:

* Zookeeper
* Broker Host with Producer
* kafka-connector

## Subscribe to a topic

In order to consume topics via the connector we need to apply an annotation with a key of `topic`, for example: `topic: payment-received`. This should match at least one of the topics we defined in the earlier step for the connector.

* Create a [Docker Hub](https://hub.docker.com) account if you don't already have one and sign in with `docker login`.

* Create a new function in Go

```sh
# Replace with your container registry or Docker Hub account:
$ export OPENFAAS_PREFIX=docker.io/alexellis2

# Create a function in Go
$ faas-cli new email-receipt \
  --lang=go
$ mv email-receipt.yml stack.yaml
```

> We also renamed the function's YAML file to  `stack.yaml` (the default)

The function is a simple `Hello World` written in Go, you can edit it if you want, but for simplicity in our example we will keep the default message.

Edit the `stack.yaml` file by adding `topic` annotation with the value which which we pointed in the Kafka Connector `payment-received`. The file should look like this:

```yaml
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080

functions:
  email-receipt:
    lang: go
    handler: ./email-receipt
# ...
    annotations:
      topic: payment-received
```

Edit the handler.go file:

```go
package function

import (
	"fmt"
)

// Handle a serverless request
func Handle(req []byte) string {
	return fmt.Sprintf("Email customer in response to event: %s", string(req))
}
```

Build, Push and Deploy the function with single command:

```bash
$ faas-cli up
```

The kafka-connector will now rebuild its topic map and detect that the "email-receipt" function wants to be invoked with messages published on the `payment-received` topic.

You can see the response of the function in two places: the function’s logs and in the connector's logs. This is configurable in the helm chart.

## Produce messages on the topic

Lets proceed by opening two terminals, one will be used to check the output of the function and the other will create messages on the topic.

In the first terminal follow the Kafka Connector's logs:

```bash
$ kubectl logs deploy/kafka-broker -n openfaas \
    --tail 100 \
    --follow
```

In the second terminal, deploy a client for Kafka to produce messages:

```bash
$ kubectl apply -f - <<EOF
    apiVersion: v1
    kind: Pod
    metadata:
      name: kafka-client
      namespace: default
    spec:
      containers:
      - name: kafka-client
        image: confluentinc/cp-enterprise-kafka:6.1.0
        command:
          - sh
          - -c
          - "exec tail -f /dev/null"
EOF

pod/kafka-client created
```

Connect to the pod and produce messages on the topic:

```bash
# Connect to a shell within the pod:

kubectl exec -it kafka-client -- /bin/bash

# Create the topic
kafka-topics \
  --zookeeper cp-helm-charts-cp-zookeeper-headless:2181 \
  --topic payment-received \
  --create --partitions 1 \
  --replication-factor 1 --if-not-exists

# Create a message
MESSAGE="`date -u`"

# Produce a test message to the topic
echo "$MESSAGE" | kafka-console-producer --broker-list \
  cp-helm-charts-cp-kafka-headless:9092 \
  --topic payment-received
```

You'll now see your messages being sent to the payment-received topic and then the function being invoked.

```
OpenFaaS kafka-connector PRO    Version: 0.6.0-rc3      Commit: 3784d5f35d1b6e090e37f211d6af1e51136ff9d6

2021/12/15 09:56:34 Licensed to: alex <alex@openfaas.com>, expires: 77 day(s)
2021/12/15 09:56:34 Broker: cp-helm-charts-cp-kafka-headless.default:9092       Topic: [payment-received]
Gateway: http://gateway.openfaas:8080
Rebuild interval: 30.000000s
Use TLS: false
Use SASL: false
2021/12/15 09:56:34 Binding to topics: [payment-received]


2019/04/09 18:37:10 Syncing topic map
2019/04/09 18:37:12 Invoke function: email-receipt
[#4] Received on [payment-received,0]: 'Kafka and go'
[200] payment-received => email-receipt
Hello, Go. You said: Kafka and go

2019/04/09 18:37:13 Syncing topic map
2019/04/09 18:37:16 Syncing topic map
...
```

## Dealing with high-load / long-running functions

If you're either dealing with very high-load or long-running functions, there is a way to release pressure and defer the executions of your functions. This uses OpenFaaS' built-in asynchronous invocation mode.

Just install the chart again, but this time add:

```
--set asyncInvocation=true
```

In this mode, work is consumed immediately from Kafka, and then buffered in the built-in NATS queue in OpenFaaS, to be executed by the queue-worker.

See the logs of the queue worker as it executes your requests:

```bash
kubectl logs -n openfaas deploy/queue-worker
```

Alternatively, you can update the `upstreamTimeout` value to something longer than the default and keep the existing behaviour:

```
--set upstreamTimeout=1m
```

## Wrapping up

There are multiple real world examples where an event-driven approach with Apache Kafka can help integrate your existing tools and applications, and to extend functionality of existing systems without risking any regression.

Let me give you an example. Suppose that whenever a new customers signs-up and creates an account we may need to process their information in various ways in addition to just storing it in a SQL table.

We could publish their data on a topic such as: `customer-signup`. With an event-driven approach using OpenFaaS and the kafka-connector we can now broadcast a message on the `customer-signup` topic and then process it in a number of ways by using different functions. I.e. to check their credit score, update a lead in SalesForce and or even schedule a welcome pack in the post. So at any time you can extend the workflow of tasks for a `customer-signup` message by just defining a new function and giving it an annotation of `topic: customer-signup`.

Now that I've shown you how to connect to Kafka and explored a real-world use-case, it's over to you to try it.

You can use your existing OpenFaaS Pro license, or apply for a 14-day trial: [Find out more](https://openfaas.com/support/)

If you would like to remove the Kafka-connector, use helm to delete it:

```bash
$ helm delete --purge kafka-connector
```

## Going further

The kafka-connector implements the [Connector SDK](https://github.com/openfaas-incubator/connector-sdk), checkout the SDK written in Go for how you can start connecting your own events and triggers.

Other examples include the [Cron Connector](https://github.com/zeerorg/cron-connector) and the [vCenter Connector](https://github.com/openfaas-incubator/vcenter-connector). You can view the other [triggers here](https://docs.openfaas.com/reference/triggers/).

Editor(s): [Alex Ellis](https://www.alexellis.io/)
