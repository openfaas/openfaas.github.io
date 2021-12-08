---
title: "Event-driven OpenFaaS with Managed Kafka from Aiven"
description: "Learn how to invoke your functions from Kafka events with Aiven's managed service"
date: 2021-08-02
image: /images/2021-06-kubectl-functions/background.jpg
categories:
 - enterprise
 - kafka
 - eventdriven
 - functions
 - kubernetes
author_staff_member: alex
dark_background: true

---

Learn how to invoke your functions from Kafka events with Aiven's managed service

## Introduction

In this post I'll show you how to invoke your functions using [Aiven's](https://aiven.io) managed Kafka service and the OpenFaaS Pro connector. A sample function and setup are included, so you can follow along with a free trial, or your existing [Aiven](https://aiven.io) account.

We've seen demand for an [Apache Kafka](https://kafka.apache.org/) integration from end-user companies of varying size and spend. In some microservice architectures, Kafka is considered the backbone through which all messages can be exchanged, to give a decoupled architecture. If a new client signs up, a message may be published to the "onboarding" topic, causing an email service and provisioning service to detect the event and set up new database records, followed by a welcome email.

![Conceptual Architecture](/images/2021-08-kafka-aiven/kafka-topics.jpg)
> Conceptual architecture: the OpenFaaS Kafka Connector links functions to topics so that they can receive messages from Kafka.

One of the benefits of a serverless approach is being able to focus on writing small chunks of code that can execute and scale independently. The Kafka Connector subscribes to a set list of topics, and then monitors functions for the `topic` annotation and uses it to dispatch messages to functions.

I first learned of [Aiven](https://aiven.io) from [RateHub](https://ratehub.ca), an OpenFaaS Pro customer and [GitHub sponsor](https://github.com/sponsors/openfaas). They provide a set of managed services including Apache Kafka. RateHub's CTO Chris Richards told me that his team prefer managed services so that they can focus on their customers' needs instead of running infrastructure.

![Provision managed services](/images/2021-08-kafka-aiven/provision.png)

My first impressions of Aiven were that its UI was very easy to use, and that they had a wide range of managed services on offer.

When you provision a service like Kafka, Postgresql or Cassandra, they ask you which cloud and region you'd like to provision into, and then use their own accounts to set up the services. The cost did come across a little on the high side, with a "business" plan on AWS coming in around 750 USD / mo, but you have to factor in that they run the entire stack for you in a Highly-available configuration. If you don't mind having your broker running on DigitalOcean with 90 GB of storage instead of 600 GB, then you can get it as low as 200 USD / mo.

## Tutorial: Invoke your functions with Kafka and Aiven

In this section, I'll show you how to configure OpenFaaS and Aiven to trigger functions from messages published to Kafka topics. You can still follow these steps if you self-host Kafka, or use another managed offering, but you'll need to adapt them.

### Provision Kafka on Aiven

You can sign up for a [free trial of Aiven here](https://aiven.io)

Create a Kafka broker in your preferred cloud and region. This will not provision into your own cloud account, but into Aiven's. They just give you the choice and bubble up this information to you, rather than hide it as some SaaS and managed products do.

Once you've created your Kafka broker, you can configure it with an allowed IP range, setup add-ons like Kafka Rest, and configure what kind of authentication you want to use. The default is TLS with Client Certificates, but SASL is also available and is the default for [Confluent Cloud](https://www.confluent.co.uk/confluent-cloud/)'s managed Kafka offering.

Click the "Enable Kafka REST" button, so that we can trigger a test message from the Aiven Console. Alternatively, if you have code that already publishes messages using Aiven's authentication methods, feel free to use that instead.

### Setup OpenFaaS

It is possible to use OpenFaaS Pro features with [faasd](http://github.com/openfaas/faasd), but this tutorial will use Kubernetes - i.e. self-hosted, managed Kubernetes, K3s or OpenShift.

You should already have [OpenFaaS installed](https://docs.openfaas.com/deployment/), and Docker on your system to build new functions.

### Gather your secrets

Download the secrets for your Kafka broker from Aiven's Console.

* Save the Access Key as broker-key.txt
* Save the Access Certificate as broker-cert.txt
* Save the CA Certificate as broker-ca.pem

### Install the Kafka PRO connector

Run the following to create the secrets for the Kafka connector:

```bash
kubectl create secret generic \
    kafka-broker-ca \
    -n openfaas \
    --from-file broker-ca=./broker-ca.pem

When using client certs

kubectl create secret generic \
    kafka-broker-cert \
    -n openfaas \
    --from-file broker-cert=./broker-cert.txt

kubectl create secret generic \
    kafka-broker-key \
    -n openfaas \
    --from-file broker-key=./broker-key.txt
```

And create a secret for your OpenFaaS Pro license:

```bash
kubectl create secret generic \
    -n openfaas \
    openfaas-license \
    --from-file license=~/.openfaas/LICENSE
```

If you do not have a license yet, you can [request a free trial, or purchase one](https://openfaas.com/support/).

Create an `overrides.yaml` file to use with helm:

```yaml
brokerHost: kafka-202504b5-openfaas-910b.aivencloud.com:10905
tls: true
saslAuth: false

caSecret: kafka-broker-ca
certSecret: kafka-broker-cert
keySecret: kafka-broker-key
topics: signup
```

Note that you need to change the `brokerHost` to your own managed instance and port. If you make configuration changes in the Aiven Console, then the port may change, please bear this in mind.

Now install the chart using helm:

```bash
$ helm repo add openfaas https://openfaas.github.io/faas-netes/
$ helm repo update

$ helm upgrade kafka-connector openfaas/kafka-connector \
    --install \
    --namespace openfaas \
    --values ./overrides.yaml
```

You can then check the logs to see if you got everything right:

```bash
$ kubectl logs -n openfaas deploy/kafka-connector -f

OpenFaaS kafka-connector PRO    Version: 0.6.0-rc2      Commit: a54bdb11c1ea923ec13e449311116298e30ce3ae

2021/08/02 10:14:45 Licensed to: Alex Ellis <alex@openfaas.com>, expires: 60 day(s)
2021/08/02 10:14:45 Broker: kafka-202504b5-openfaas-910b.aivencloud.com:10905   Topic: [signup]
Gateway: http://gateway.openfaas:8080
Rebuild interval: 5.000000s
Use TLS: true
Use SASL: false
2021/08/02 10:14:45 Binding to topics: [signup]
2021/08/02 10:14:49 Consumer ready
```

### Write the email function

The email function will be written in Node.js, but you can use your preferred language and template such as Python, C#, Java, or Go. I'll get you as far as echoing the message received from Kafka, so don't worry, we won't be messaging any of your customers today.

```bash
# Set to your Docker Hub account or registry
export OPENFAAS_PREFIX=alexellis2

faas-cli new --lang node14 \
  send-email
```

Edit `send-email.yml` and add the required `topic` annotation so that the connector can link the function to the Kafka `signup` topic. 

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  send-email:
    lang: node14
    handler: ./send-email
    image: alexellis2/send-email:0.1.0
    annotations:
      topic: signup
```

Here's the code for `send-email/handler.js`:

```javascript
'use strict'

module.exports = async (event, context) => {
  let body = JSON.stringify(event.body)
  let contentType = event.headers["content-type"]
  console.log(`Received message ${body}, content-type: ${contentType}`)

  return context
    .status(201)
    .succeed("Message accepted")
}
```

Why don't you customise it later, after you've had a chance to try it out and see it echo the contents of the Kafka message?

Now deploy the function:

```bash
faas-cli up -f send-email.yml
```

### Now trigger the function

If you have code that already publishes messages to Aiven using their TLS Client Certificate approach, feel free to use that.

However, it's much quicker and easier for the tutorial if we just use their UI. In an earlier step we enabled *Kafka REST* which allows us to publish a test message to the `signup` topic.

Add a new topic called `signup`:

![Add a new topic called signup](/images/2021-08-kafka-aiven/add-topic.png)

Then click on the row in the UI for the topic, followed by *"Messages"*, then click *"Produce Message"*:

![Produce a message](/images/2021-08-kafka-aiven/produce-message.png)

The test message that I used was:

```json
{
"customer":"contact@openfaas.com",
"plan":"pro"
}
```

Now you can get the logs from the function and see that it received the message:

```bash
$ faas-cli logs send-email --tail

2021-08-02T10:21:14Z Received message "{\"customer\": \"contact@openfaas.com\", \"plan\": \"pro\"}", content-type: text/plain
2021-08-02T10:21:14Z 2021/08/02 10:21:14 POST / - 201 Created - ContentLength: 16
```

You can parse the message, and take action for "pro" plans, and ignore "free" plans for instance:

Here is an example of how you could invoke a long-running background job to run a credit check on new paid customers:

```javascript
'use strict'

module.exports = async (event, context) => {
  let body = JSON.stringify(event.body)

  if(body.plan == "pro") {
      axios.post('http://gateway.openfaas/async-function/credit-check', {
        plan: body.plan,: body.email
      })
      .then(function (response) {
        console.log("Provisioned customer");
      })
      .catch(function (error) {
        console.log(error);
      });
  }

  return context
    .status(201)
    .succeed("Message accepted")
}
```

Learn how to build functions with JavaScript and Node.js in [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else)

See also: [async functions](https://docs.openfaas.com/reference/async/)

## Wrapping up

We've now set up a managed Kafka broker using Aiven and configured OpenFaaS Pro to dispatch messages on a set topic to our functions. I've written up a short FAQ, but you can also reach out if you would like to talk or get help.

* Is this secure? Aiven uses TLS Client Certificates which is probably the more secure option out of this and SASL authentication.

* What if I want to try this with self-hosted Kafka? We do provide a quick-start for a self-hosted Kafka installation using Confluent's Helm chart: [Self-hosted Kafka quickstart](https://github.com/openfaas/faas-netes/blob/master/chart/kafka-connector/quickstart.md)

* How does this scale? Well you can set up the Kafka connector to listen to multiple topics by changing the `overrides.yaml` file such as: `topics: "signup,churn,quote-requested,quote-completed"` and each function can also subscribe to multiple topics.

* If you have functions which are long-running, you can have them run in the background using the `asyncInvoke` setting for the Kafka connector, with this in place, all messages are dispatched to OpenFaaS' built-in NATS queue for processing when there is capacity available.

* What about retries? If you enable the `asyncInvoke` behaviour of the connector, and are an OpenFaaS Pro customer, then messages can be retried with an exponential back-off.

* What if I use [Confluent Cloud](https://www.confluent.co.uk/confluent-cloud/) or self-hosted Apache Kafka? You can also use SALS authentication if you're a [Confluent Cloud](https://www.confluent.co.uk/confluent-cloud/) customer, or bypass authentication if you run Kafka on a private network and are self-hosting the service.

Do you have questions or comments? You can take OpenFaaS Pro for a spin and find out about [its other features here](https://docs.openfaas.com/openfaas-pro/introduction/).

### Join the community

OpenFaaS is an open source project, you can support it via GitHub as an individual or corporation:

* Become an individual or corporate [Sponsor on GitHub](https://github.com/sponsors/openfaas)

Chat with the community:

* Browse the [OpenFaaS documentation](https://docs.openfaas.com)
* Follow [OpenFaaS on Twitter](https://twitter.com/openfaas)

Do you have questions, comments or suggestions? Tweet to [@openfaas](https://twitter.com/openfaas).

> Want to support our work? You can become a sponsor as an individual or a business via GitHub Sponsors with tiers to suit every budget and benefits for you in return. [Check out our GitHub Sponsors Page](https://github.com/sponsors/openfaas/)
