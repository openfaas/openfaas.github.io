---
title: "Staying on topic: trigger your OpenFaaS functions from Kafka"
description: Martin outlines how you can use Kafka and subscribe OpenFaaS function to a topic using kafka-connector plugin.
date: 2019-04-20
image: /images/kafka-connector/aluminium-building.jpg
categories:
  - kafka
  - tutorial
  - examples
author_staff_member: martin
dark_background: true
---

In this post I will show you how to subscribe your OpenFaaS functions to Kafka topics when running your functions via Kubernetes.

OpenFaaS is solving real problems for our end-user community, who are using OpenFaaS in production. 

OpenFaaS functions and microservices are accessible over HTTP endpoints via the Gateway service, but how can other events be used to trigger our functions?

Kafka is stream-processing platform and at a high level the important concepts are Producers, Consumers and Brokers which communicate with each-other via messages attached to Topics. The way it works is that the Producer is sending messages on specific Topics to the Broker, then the Consumers poll all the topics of interest from the Brokers. The approach is fitting for distributed systems, because it decouples the communication between your services.

See also: [Apache Kafka Documentation](https://kafka.apache.org/documentation/).

## Kafka Connector

The kafka-connector can be used to connect Kafka topics to OpenFaaS Functions. After deploying the kafka-connector and pointing it at your broker, you can connect functions to topics by adding a simple annotation via your stack YAML file.

Conceptual architecture diagram:

![Kafka Diagram](/images/kafka-connector/overview-diagram.jpg)

The connector periodically queries the Gateway’s list of functions and then builds a map between each function and topic. This map is then used to invoke functions when messages arrive on a given topic.

## Pre-requisites

For this tutorial we will use Kubernetes, so you should install OpenFaaS using the [getting started guide](https://docs.openfaas.com/deployment/kubernetes/). I have chosen minikube for my own local cluster.

The [faas-cli](https://docs.openfaas.com/cli/install/) binary along with populated `OPENFAAS_URL` environmental variable pointing at your gateway.

## Clone the Kafka Connector

Pull the `kafka-connector` code from github:

 ```bash
$ git clone https://github.com/openfaas-incubator/kafka-connector
```

Inside `kafka-connector` folder navigate to `yaml/kubernetes`:

 ```bash
$ cd kafka-connector/yaml/kubernetes
```

Here we can see the Kafka Zookeeper and Broker which we will be using to send payloads to our functions.

## Deploy the components with configuration

In order to deploy the Zookeeper and Broker apply the `yaml` files while in the `kubernetes` folder.

Apply the Broker files:

```bash
$ kubectl apply -f kafka-broker-dep.yml,kafka-broker-svc.yml
```

Apply the Zookeeper files:

```bash
$ kubectl apply -f zookeeper-dep.yaml,zookeeper-svc.yaml
```

If you don't have the OpenFaaS Charts repository added, use this command:

```
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

Here it is important to note that our Broker resides in a service called `kafka` in the same namespace as our Gateway and Kafka Connector service. If you have the Broker service in another namespace, again called `kafka`, just append the namespace like so `kafka.<your_namespace>` to the `broker_host` environmental variable so the Connector can discover it. The default kafka port `9092` is appended to the service name by default.

We have now deployed the following components:
* Zookeeper
* Broker Host with Producer
* Kafka Connector

Before we proceed, make sure you have all the components running:

```bash
$ kubectl get pods -n openfaas | grep -E 'kafka|zookeeper'
kafka-broker-544fbccd48-p6pgr     1/1     Running            3          3m
kafka-connector-5d9f447f5-5drv7   1/1     Running            0          4m
zookeeper-699f568f6f-6b4n2        1/1     Running            0          3m
```

## Subscribe function

In order to consume topics via the connector we simply need to apply an annotation with a key of `topic` and the chosen value used in the `connector-dep.yml` - in our case it was `payment-received`.

Before we start log in into your Docker Hub account.

We will first create custom function the following way:

```
$ faas-cli new kafka-message --lang=go --prefix=<your_dockerhub_username>
```

Rename the function's YAML file to `stack.yml`:

```
$ mv kafka-message.yml stack.yml
```

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

Voila, your function is now subscribed to the topic and it can be invoked by producing message on that topic.

You can see the response of the function in two places: the function’s logs and, since we set the `print_response_body` to true when deploying the connector, in the connector’s logs too.

## Create messages on the topic

Lets proceed by opening two terminals, one will be used to check the output of the function and the other will create messages on the topic.

In the first terminal get the producer's name:

```bash
$ PRODUCER=$(kubectl get pods -o name -n openfaas |
    grep -m1 kafka-broker |
    cut -d'/' -f 2)
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
