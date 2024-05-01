---
title: Bill your users for their usage with chargeback for OpenFaaS
description: 
date: 2024-05-01
categories:
- kubernetes
- faas
- functions
- chargeback
- saas
dark_background: true
image: "/images/2024-05-01-chargeback/background.png"
author_staff_member: alex
hide_header_image: true
---

With the new billing webhooks feature for OpenFaaS for Enterprises, you can now charge your users for their OpenFaaS usage.

> OpenFaaS is a developer-friendly platform for building and operating serverless functions using Kubernetes. You can run the same cloud in the cloud, or on-premises, or locally on your own machine without changes.

## What is chargeback?

> In 2017, just after I'd announced and demoed OpenFaaS to several thousand people on stage at Dockercon, I was approached by a principal developer at VMware. He asked me whether OpenFaaS supported "IT chargeback".
> 
> What's chargeback? I asked.
> 
> Well, you run a service centrally and charge departments for the resources they use, he said.
> 
> I said: "How could you possibly create an accurate bill for something running on your own servers?"
>
> "It doesn't matter, it just needs to be good enough", he replied.

Back then, I didn't want to add features to OpenFaaS that I didn't fully understand or need myself, and at the time I wanted to keep the project unencumbered by enterprise features.

![Splitting the bill for internal infrastructure between departments](/images/2024-05-01-chargeback/split-the-bill.png)
> Splitting the bill for internal infrastructure between departments

Fast forward 7 years, and we're in a very different place. So when the CEO of E2E Networks Ltd approach us wanting to add a "FaaS" tab to their cloud hosting service, along with "Kubernetes", "VMs" and "Object storage", it suddenly made sense. There was a good reason to add chargeback for the way they were re-selling OpenFaaS hosting to their customers. The existing Prometheus data was great for monitoring, but the project documentation explicitly states it should not be used for billing, because it's considered "sampled".

We see two potential users for this new feature:

1) You host custom code for customers so that they can integrate with your platform and extend its featureset.

Two other customers that do this today would be Waylay.io who offer an automation product, where customers supply JavaScript to be executed in response to events, and Patchworks Integration Ltd, who offer a large range of e-commerce integrations.

2) You run a platform internally and want to charge departments for their usage.

Two customers that fit this profile would be Mnemonic where an expert DevOps team operate a centralised OpenFaaS installation so their developers can deploy functions, and a global 500 investment company in the US Northwest who run a large datalake and need to charge departments for their usage.

If you'd like to learn more about running OpenFaaS as a multi-tenant platform, see the following:

* [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)
* [Building Blocks for Source to URL with OpenFaaS](https://www.openfaas.com/blog/source-to-url/)
* [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/)

## How does chargeback work?

From telemetry data we knew that some customers had several invocations per hour, whilst others had up to 100,000 per hour, so making a database write or webhook per invocation would quickly grow to be a burden, and need to be scaled out.

Since webhooks are common-place for so many different kinds of events, we decided to use them as the mechanism for chargeback. This way, the code you write to integrate with Stripe, or GitHub, will resemble the code you write to integrate with OpenFaaS.

Each webhook will contain one to many events within a JSON array, so you can parse this efficiently and do a batch insert to your database or storage system of choice. We provide a sample schema in the documentation for Postgresql.

If you experience downtime in your receiver endpoint, or need to perform maintenance, durable retries will be used until the event can be delivered through a system similar to the OpenFaaS async system.

![Conceptual architecture of chargeback in OpenFaaS](/images/2024-05-01-chargeback/chargeback.png)
> Conceptual architecture of chargeback in OpenFaaS

## How do I get started?

First, find your values.yaml that you used to install the OpenFaaS helm chart. You'll need a license for OpenFaaS for Enterprises, if you don't have one yet, reach out for a trial key.

Next, create a webhook secret that the your endpoint will use to validate the webhooks:

```bash
# openssl is preferred to generate a random secret:
openssl rand -base64 32 > billing-endpoint-secret.txt

kubectl create secret generic \
    -n openfaas \
    webhook-secret \
    --from-file webhook-secret=./billing-endpoint-secret.txt
```

Update values.yaml with the following:

```yaml
eventSubscription:
  endpoint: "https://example.com/openfaas-events"
  endpointSecret: webhook-secret

  metering:
    enabled: true
    defaultRAM: 512Mi
```

You should update two things:

* The `defaultRAM` is the default memory limit for functions that don't have a limit set. This is used to calculate the cost of each invocation.
* The `endpoint` is the HTTPS URL where you will receive the webhooks.

If you want to use an OpenFaaS function to receive the webhooks, then you'll need to create a new namespace and have it excluded from the metering to avoid a loop.

```yaml
metering:
+  excludeNamespaces: "openfaas-system"
```

Then create the new namespace and annotate for use within OpenFaaS:

```bash
kubectl create namespace openfaas-system
kubectl annotate namespace openfaas-system openfaas="1"
```

Alternatively, if you have an admin account you can run `faas-cli namespace create openfaas-system`.

Then, update the chart in the usual way.

## Example webhook payload

A HTTP Post will be delivered to i.e. the following URL: https://example.com/function/chargeback.openfaas-system

```bash
X-OpenFaas-Event: function_usage
X-OpenFaas-Signature-256: sha256=d57c68ca6f92289e6987922ff26938930f6e66a2d161ef06abdf1859230aa23c
X-OpenFaas-Delivery: fe0f677c-c431-498e-8ace-9ba857434334
Content-Type: application/json
```

```
[
   {
     "event": "function_usage",
     "namespace": "openfaas-fn",
     "function_name": "env",
     "started": "2023-11-14T15:01:20.349527036Z",
     "duration": 3798742,
     "memory_bytes": 20971520
   }
]
```

* `event` - the type of event
* `namespace` - the namespace of the function that triggered the event
* `function_name` - the function name that triggered the event
* `started` - the timestamp the function invocation was started
* `duration` - the duration of the function invocation
* `memory_bytes` - the memory limit configured for the function in bytes

You'll need to validate that the webhooks came from OpenFaaS, and not from an external source.

You can do this by calculating the HMAC signature of the payload and comparing it to the `X-OpenFaaS-Signature` header.

See also: [How to validate the webhook is genuine](https://docs.openfaas.com/openfaas-pro/billing-metrics/#how-to-validate-the-webhook-is-genuine)

## Wrapping up

Whilst the batching, signing, and retries were all relatively complex components to develop, they can now be enabled by turning on a few extra lines in your Helm chart's values.yaml file.

A simple HTTP microservice or an OpenFaaS function can be written to receive, validate and store billing webhooks. We've left the system open like this so that you can store or handle the events however you like, with a relational/NoSQL database, time-series, or even object storage.

For examples of different function templates, you can see the docs here: [Languages overview](https://docs.openfaas.com/languages/overview/), and if what you need isn't listed like Julia or Rust, you can create your own template, or [leverage an existing container](https://www.openfaas.com/blog/porting-existing-containers-to-openfaas/).

To get you started, the documentation includes a sample Postresql schema and a query you can run monthly to calculate customer usage.

![Conceptual architecture using functions to generate monthly invoices and emails for external customers](/images/2024-05-01-chargeback/store-and-charge.png)
> You could even use OpenFaaS functions to generate invoices and emails for external customers, on a monthly basis.

For information on the feature including Q&A, see the OpenFaaS documentation: [Billing metrics](https://docs.openfaas.com/openfaas-pro/billing-metrics/)

Would you like to talk to our team about this feature? [Schedule a call by clicking the button on our pricing page](/pricing)