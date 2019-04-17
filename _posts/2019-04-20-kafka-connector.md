---
title: "Staying on topic: trigger your OpenFaaS functions with Apache Kafka"
description: Martin outlines how you can make use of Apache Kafka to trigger your functions in OpenFaaS through the new connector-sdk component.
date: 2019-04-20
image: /images/kafka-connector/aluminium-building.jpg
categories:
  - kafka
  - tutorial
  - examples
author_staff_member: martin
dark_background: true
---

In this post I will show you how you can build subscriptions between your OpenFaaS functions and your Apache Kafka topics. I'll be using Kubernetes to show you around, but the connector-sdk works with any OpenFaaS provider.

OpenFaaS is solving real problems for our [end-user community](https://docs.openfaas.com/#users-of-openfaas), many of whom are now relying on the project to in production and for core services. The kafka-connector was created to help those users integrate their existing systems with their functions.

OpenFaaS functions and microservices are accessible over HTTP endpoints via the Gateway service, but let's explore how other events can be used to trigger our functions.

## Apache Kafka

Apache Kafka is a stream-processing platform. At a high level the important concepts are Producers, Consumers and Brokers which communicate with each-other via messages attached to Topics.

The way it works is that the Producer is sending messages on specific Topics to the Broker, then the Consumers poll all the topics of interest from the Brokers. This approach is popular in distributed systems because it decouples direct communication between services and allows messages to be replayed or redelivered when required from a persistent log.

See also: [Apache Kafka Documentation](https://kafka.apache.org/documentation/).

## Kafka Connector

The [kafka-connector](https://github.com/openfaas-incubator/kafka-connector) is designed to connect Kafka topics to OpenFaaS Functions. After deploying the kafka-connector and pointing it at your broker, you can connect functions to topics by adding a simple annotation via your functions' stack.yml file.

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

A development version of Apache Kafka has been made available so that you can get this tutorial up and running in a few minutes. You can also customise the connector to use your existing Kafka deployment.

* Clone the repository:

 ```bash
$ git clone https://github.com/openfaas-incubator/kafka-connector && \
  kafka-connector/yaml/kubernetes
```

* Apply the Broker files:

```bash
$ kubectl apply -f kafka-broker-dep.yml,kafka-broker-svc.yml
```

* Apply the Zookeeper files:

```bash
$ kubectl apply -f zookeeper-dep.yaml,zookeeper-svc.yaml
```
## Deploy the connector with helm

Add the OpenFaaS charts repository:

```sh
$ helm repo add openfaas https://openfaas.github.io/faas-netes/
```

Install the Kafka Connector with default values:

```bash
$ helm upgrade kafka-connector openfaas/kafka-connector \
    --install \
    --namespace openfaas \
    --set topics="payment-received" \
    --set broker_host="kafka" \
    --set print_response="true" \
    --set print_response_body="true"
```

* Set the `topics` to the topics you want to subscribe to as a comma separated list without separating spaces

* If you deployed Kafka to a remote location or a different namespace or port then just update the `broker_host` value.

> Note: if you do not want to install tiller on your cluster, then you can make use of `helm template` to generate YAML files

We have now deployed the following components:

* Zookeeper
* Broker Host with Producer
* kafka-connector

Before we proceed, make sure you have all the components running:

```bash
$ kubectl get pods -n openfaas | grep -E 'kafka|zookeeper'
kafka-broker-544fbccd48-p6pgr     1/1     Running            3          3m
kafka-connector-5d9f447f5-5drv7   1/1     Running            0          4m
zookeeper-699f568f6f-6b4n2        1/1     Running            0          3m
```

## Subscribe to a topic

In order to consume topics via the connector we need to apply an annotation with a key of `topic`, for example: `topic: payment-received`. This should match at least one of the topics we defined in the earlier step for the connector.

* Create a [Docker Hub](https://hub.docker.com) account if you don't already have one and sign in with `docker login`.

* Create a new function in Go

```sh
$ faas-cli new kafka-message --lang=go --prefix=<your_dockerhub_username>
$ mv kafka-message.yml stack.yml
```

> We also renamed the function's YAML file to  `stack.yml` (the default)

The function is a simple `Hello World` written in Go, you can edit it if you want, but for simplicity in our example we will keep the default message.

Edit the `stack.yml` file by adding `topic` annotation with the value which which we pointed in the Kafka Connector `payment-received`. The file should look like this:

```
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080

functions:
  kafka-message:
    lang: go
    handler: ./kafka-message
    image: <your_dockerhub_username>/kafka-message:latest
    annotations:
      topic: payment-received
```

Build, Push and Deploy the function with single command:

```bash
$ faas-cli up
```

The kafka-connector will now rebuild its topic map and detect that the "kafka-message" function wants to be invoked with messages published on the `payment-received` topic.

You can see the response of the function in two places: the function’s logs and in the connector's logs. This is configurable in the helm chart.

## Produce messages on the topic

Lets proceed by opening two terminals, one will be used to check the output of the function and the other will create messages on the topic.

In the first terminal get the producer's name:

```bash
$ PRODUCER=$(kubectl get pods -l=component=kafka-broker -n openfaas -o jsonpath="{.items[*].metadata.name}")
```

Then open a shell session inside the Broker pod to connect with the producer:

```bash
$ kubectl exec $PRODUCER -ti -n openfaas \
    --tty \
    --stdin \
    -- /opt/kafka_2.12-0.11.0.1/bin/kafka-console-producer.sh \
    --broker-list kafka:9092 \
    --topic payment-received
```

In the second terminal follow the Kafka Connector's logs.

First find the kafka-connector's pod name:

```bash
$ KAFKA_CONNECTOR=$(kubectl get pods -o name -n openfaas |
    grep -m1 kafka-connector |
    cut -d'/' -f 2)
```

Follow the logs with this command:

```bash
$ kubectl logs $KAFKA_CONNECTOR -n openfaas \
    --tail 100 \
    --follow
```

In the first terminal write the message you would like your function to receive and check the output from the logs.

```
...

2019/04/09 18:37:10 Syncing topic map
2019/04/09 18:37:12 Invoke function: kafka-message
[#4] Received on [payment-received,0]: 'Kafka and go'
[200] payment-received => kafka-message
Hello, Go. You said: Kafka and go

2019/04/09 18:37:13 Syncing topic map
2019/04/09 18:37:16 Syncing topic map
...
```

## Real world examples

There are multiple real world examples where Kafka in combination with the Serverless approach provided by OpenFaaS becomes a really powerful tool as Kafka can make even the smallest of systems extensible and OpenFaaS provides us with the quick way to add those extensions.

When a customer creates an account you need to process their information and store it in a database. However, there are a number of other departments also interested in new customers - theres marketing who want to send a welcome pack, there's payments who want to check their credit score. Just create topic, for example `user-creation`, which will be populated with the information and then create OpenFaaS function which handles the processing and updating of that information to the database. Similarly marketing and payments can both implement functions to process the data in a way that makes sense for them.

If we extend on the example above, again you would like to add some quick feature for the user. Attach another function to the same topic to extend the already existing functionality or just add another topic and write the function which handles that feature, it is as simple as that. 

## Wrapping up

Kafka Connector implements the [Connector SDK](https://github.com/openfaas-incubator/connector-sdk) with which you can create your own invoking mechanism.

You can check the existing connectors like the [Cron Connector](https://github.com/zeerorg/cron-connector) or [vCenter Connector](https://github.com/openfaas-incubator/vcenter-connector) or all the existing function [Triggers](https://docs.openfaas.com/reference/triggers/).

Now you already know the basics. It is over to you to deploy the connector with development tools like we did in the blog, or attach it to your existing Kafka deployment and start invoking functions. You can perhaps try attaching your function to another topic and extend the Hello World function with your own language of choice. Serverless with Kafka is all in your hands with the Kafka Connector.

Editor(s): [Alex Ellis](https://www.alexellis.io/) & [Richard Gee](https://twitter.com/rgee0)
