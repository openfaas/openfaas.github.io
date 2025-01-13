---
title: "How to Build & Integrate with Functions using OpenFaaS"
description: "OpenFaaS is a developer-friendly platform for creating portable functions that can run on any cloud. Learn the use-cases and how you can integrate functions into your product."
date: 2025-01-13
author_staff_member: alex
categories:
  - openfaas
  - serverless
  - event-driven
  - automation
  - integration
  - kubernetes
dark_background: true
image: "/images/2025-01-integrate/background.png"
hide_header_image: true
---

OpenFaaS is a developer-friendly platform for creating portable functions that can run on any cloud through Kubernetes. In this blog post, you will learn about use-cases, language templates, differences from traditional applications and cloud-based functions, how functions can be triggered, scaled and observed, and how to get started with OpenFaaS.

## Introduction

Functions provide a quick and easy way to build functionality for both new and existing applications. Rather than having to think about boiler-plate code like Dockerfiles, HTTP servers, metrics collection, and scaling, these things are built-in, and the Function and its event sources become your new focus.

We'll enumerate various common use-cases that we've seen from customers over the years. This is not an exhaustive list, but if you see something that resonates with your workloads, then you may be in the right place.

Everyone uses functions differently, so to explore OpenFaaS further for your own needs, you can browse the [OpenFaaS documentation](https://docs.openfaas.com/), and read [past articles on the blog](https://openfaas.com/blog).

![OpenFaaS at a glance](/images/2025-01-integrate/conceptual-of.png)
> There are various ways to integrate with OpenFaaS - directly from your team's UI or API, from a third party sending HTTP requests, or uploading data to S3 buckets, to cron, to a Kafka trigger from another part of your organisation.

### Use-cases for Functions

What kinds of use-cases suit Functions?

Functions in OpenFaaS are simply pieces of code written in a language of your choice, that run in response to an event or a trigger, so they suit many kinds of use-cases.

Below is a simplified function which accepts an MP3 file via a HTTP body, transcodes the audio to text using OpenAI's Whisper, and returns the text as a response. This function could be used to transcribe podcasts, or to generate subtitles for videos:

```python
import tempfile
from urllib.request import urlretrieve

import whisper

def handle(event, context):
    models_cache = '/tmp/models'
    model_size = "tiny.en"

    url = str(event.body, "UTF-8")
    audio = tempfile.NamedTemporaryFile(suffix=".mp3", delete=True)
    urlretrieve(url, audio.name)

    model = whisper.load_model(name=model_size, download_root=models_cache)
    result = model.transcribe(audio.name)
    
    return (result["text"], 200, {'Content-Type': 'text/plain'})
```

Here are some common examples from our customers:

Transformation and processing

* Extract, Transform, Load (ETL) - e.g. updating customer data, importing datasets from partners, encrypting/decrypting customer data
* Security and analysis - e.g. scanning for vulnerabilities, detecting fraud, filtering spam
* Data processing - categorising, summarising, filtering, and transforming data - perhaps with a Large Language Model (LLM) like LLama or OpenAI
* Transcoding of audio and video - e.g. Run ffmpeg to extract metadata, create thumbnails, or OpenAI Whisper to produce transcripts and subtitles
* Converting file formats and PDF generation - Convert between different file formats and generate PDFs for reports or invoices

Automation and integration

* Event-driven automation - responding to events from a queue, database, or an API
* Third-party data integration / imports - importing data from third parties or partners, or exporting datasets
* Managing cloud infrastructure - e.g. creating, updating, or deleting resources in the cloud in response to events or support tickets
* Email/SMS integration - responding to inbound messages, sending out notifications and alerts
* Web scraping - e.g. extracting data from websites, or monitoring for changes using a headless browser or an HTML parser

DevOps and Support

* Providing customer support - through the use of LLMs, chatbots, and by automating common user requests
* Monitoring and alerting - e.g. sending alerts to Slack, PagerDuty, or OpsGenie, and taking remedial action if applicable
* Internal portals / User interfaces - build internal user interfaces or portals for your team to interact with your services and internal APIs
* Maintenance and back-office operations - e.g. triggering backups, cleaning up database indexes, running scheduled reports, etc

We'll explore this more below, but OpenFaaS also provides a built-in asynchronous invocation mechanism and queue-worker. It's great for long-running tasks, or tasks that may need to be retried a number of times. You can use it to fan out requests to process massive amounts of data in parallel and to chain functions together to build pipelines.

Here's an example: every day you receive a CSV with up to 1000 rows of data, each row is the URL of a podcast episode, which you need to download, and then transcribe using a GPU and OpenAI's Whisper. One asynchronous invocation can be fanned out per row, running in parallel with the amount of GPUs available, then the results will be stored in a relational database for later retrieval through your customer portal.

**Hear from a customer**

Kevin Lindsay is a Principal Engineer at [Surge](https://workwithsurge.com). Surge provides mortgage industry data and financial information on applicants for loans via Salesforce.

> "We first adopted OpenFaaS Pro in 2021 because we wanted a way to write code without having to think about Kubernetes. The initial set of functions that we wrote needed to import mortgage data from various sources, transform it, then store it in AWS S3, ready for ingestion via Snowflake. It needed for run for an hour or more, which made OpenFaaS with its asynchronous queue-worker an obvious choice for us. What would have taken a week or so, was tested and promoted to production within a few hours.
> 
> Several years later and we're still using OpenFaaS for much of our application and internal tools, where possible we've moved services and containers off Kubernetes and to OpenFaaS to make it easier to iterate on our platform."

Kevin can often be found at the [weekly Office Hours call](https://docs.openfaas.com/community/#weekly-office-hours), where he shares feedback and helps other users.

### Differences to traditional applications

Functions make it possible to extend your own application without risking the stability of the core system. They can be written in a different language, and they can be scaled independently of the rest of your application.

This means that if your team writes mainly in a traditional language like Java, you can use Python, Node.js, or Go when it's most appropriate for instance, Python is often coupled with data processing and machine learning, Go is often used for cloud-native APIs like Kubernetes, and Node.js is often used with React for building web applications and portals.

**Portability**

Unlike cloud-based functions like AWS Lambda, or Google Cloud Functions, When you write a function with OpenFaaS, it doesn't just run on that one cloud, but it can run on any cloud, or your own hardware without any changes to the code or its configuration. Functions get built into container images, and are deployed to a Kubernetes cluster, which can be on-premises, in the cloud, or at the edge - wherever you need it.

Customers have told us that portability was a key factor in choosing OpenFaaS:

* Their application is run as a central SaaS, however certain customers needed a dedicated installation within an airgap or private datacenter
* They enjoyed a large amount of credits from a single cloud vendor, but when they ran out they wanted to move to another cloud
* The cloud they picked originally did not meet their evolving needs with certain aspects such as availability, support, or in managed services
* They had an immediate need to run on-premises or in custom datacenters, meaning cloud functions were not an option

Some fear getting locked-in to a single cloud vendor, for others there are other driving factors like the developer experience, or being able to set custom timeouts. For instance, many OpenFaaS customers run on AWS Elastic Kubernetes Service (EKS) despite AWS Lambda being available to them.

**Cost & configuration**

Cloud based functions are very convenient, and have very little cost until you start to use them regularly, but there are some common complaints about their lack of configuration. Whilst some platforms have added more options and increased limits, it is not consistent, and every platform is different.

* There is often a hard limit on the maximum timeout, which cannot be changed
* There may be a maximum size of the payload that can be accepted for synchronous or asynchronous invocations
* There can be limits on concurrency
* Functions often scale to zero and are expensive when kept warm, or provisioned with static concurrency
* It can be tricky to install custom packages, especially ones which are compiled natively
* Some platforms limit the runtimes or templates that you can use
* The cost of the function increases depending on the amount of RAM required
* Most cloud-based functions platforms do not support GPUs or faster hardware
* Teams that are already using Kubernetes want to keep consistency with tooling like ArgoCD or Helm for both their applications and their functions

Over the past few years we've added most of the configuration options that users have wanted to exist in cloud-based functions, whilst trying to keep the amount of things you need to change to get started to an absolute minimum. As for the cost of running OpenFaaS, this is a static cost per Kubernetes cluster, so you can use as much RAM, CPU, many replicas, and invocations as you like without worrying about incurring additional cost. 

**Developer Experience**

The earliest focus for OpenFaaS was on Developer Experience, and we've worked hard to keep that as a central theme.

We want the product to be easy to install, simple to operate, and to provide a great experience for developers. This means that if you have a Kubernetes cluster set up, there is no reason why you cannot have a production-ready function deployed and running within a few minutes.

Code can be written with your familiar IDE such as VSCode, making use of plugins like GitHub's Co-pilot to help you write the code faster, and to scaffold repetitive tasks, then you can test your code locally with the same OpenFaaS code that will run in production. You can run the same OpenFaaS code directly on your laptop through a local Kubernetes distribution like KinD, Docker Desktop, MiniKube, or K3d, etc.

When we first started OpenFaaS, we wrote language templates for anyone who asked, and community users could write their own as required. These days we have reduced the set of formally supported languages, to make sure we have enough time to document, support, and test them, however if you see something missing - you can adapt an existing template, or write your own in a short period of time. If you're not sure how, we can provide help and direction.

A template consists of parts users do not see, and are not changed:

* A Dockerfile - with either one base image, or starting off with a larger build time image, switching to a smaller runtime image for production
* An entrypoint - the code that is run when the container starts - main.py, index.js, main.go, etc. This is responsible for setting up a HTTP server on a known port

And parts users see when they run `faas-cli new`:

* A handler - the code that is run when a request comes in, this is where you write your business logic. 
* A dependency manifest - a requirements.txt, package.json, or go.mod file that lists the dependencies for your function

The Dockerfile should invoke the tool of choice to install the packages, and then copy the handler and dependencies into the image. The entrypoint should then import and run the handler.

Templates can be obtained via the `faas-cli template store pull` command, providing a name of a function in the built-in store, or a URL to a Git repository. You can also create your own [Function Store JSON manifest file](https://github.com/openfaas/store/blob/master/templates.json), like the official one.

View the [Official templates here](https://docs.openfaas.com/languages/overview/).

**Calling Functions via HTTP**

Whenever you deploy a function to OpenFaaS, it will get its own HTTP endpoint via a new Path available on the OpenFaaS Gateway of `/function/NAME`.

![Example invocation through Ingress and the OpenFaaS gateway](/images/2025-01-integrate/invocation.png)
> Example invocation through Ingress and the OpenFaaS gateway

Within the Kubernetes cluster, the path will be as follows:

`http://gateway.openfaas:8080/function/NAME`

For asynchronous invocations, the path changes slightly, and the required HTTP method is a HTTP POST:

`http://gateway.openfaas:8080/async-function/NAME`

You can retrieve the HTTP request details like the Header, Path, Query string, and Body within the handler of your function, and then you can set the HTTP response status code, headers, and body for the response.

Every template is different, and you'll find instructions in the documentation, but here's a sample handler for the Python HTTP function.

It examines the HTTP method, and returns a 405 status code if the method is not a GET:

```python
def handle(event, context):
    if event.method == 'GET':
        return {
            "statusCode": 200,
            "body": "GET request"
        }
    else:
        return {
            "statusCode": 405,
            "body": "Method not allowed"
        }
```

Both synchronous and [asynchronous invocations](https://docs.openfaas.com/reference/async/) will return a unique identifier that can be tied into access and error logs, and consumed by the function via the `X-Call-Id` header.

In addition, asynchronous functions can register a one-time callback URL, which will receive a webhook when the invocation is complete: i.e. `http://example.com/webhook` or `http://gateway.openfaas:8080/function/RECEIVER_FUNCTION`.

Asynchronous functions are invoked through a queue, and are retried a number of times until they succeed, or the maximum number of [retries](https://docs.openfaas.com/openfaas-pro/retries/) is reached. This is useful for long-running tasks, or tasks that may fail due to transient errors.

During setup, the OpenFaaS gateway can be kept internal [or made to be Internet facing with a HTTPs certificate](https://docs.openfaas.com/reference/tls-openfaas/) and Kubernetes Ingress. If you don't want to expose all of your functions, you can be more selective and [only expose certain functions with a custom path or custom domain](https://docs.openfaas.com/reference/tls-functions/).

In terms of event-sources, the direct HTTP call is the easiest way to integrate with OpenFaaS. If you need the result immediately, you can use a synchronous invocation, if you need the result later, you can use the `X-Callback-Url` header and correlate the result with the original `X-Call-Id` that was returned.

**Triggering Functions from events**

Functions can also be invoked on a schedule using the OpenFaaS Cron connector, for instance if a certain function needs to be invoked once every 30 minutes to check the price of a stock, or once per week to send reports to customers. The cron connector sends a null body to the function, so the function could read its parameters from a database, or some external API.

Let's say you wanted to invoke a function called `customer-checker` once every 30 minutes, but you had to run it for 3 customers, you could use Kubernetes Cron to pass in some additional data like a HTTP body, or an extra HTTP header, this could then be used in the function's handler to determine which customer to check.

If you used the Cron Connector, you'd perhaps look up the list of customers from a database, or a configuration file then iterate over them in the function.

After HTTP, Async and Cron, the next set of event sources become very specific to your company and team, and what they may already be using or have experience with.

* AWS SNS / AWS SQS - ideal for existing events or automating AWS infrastructure, i.e. handle the event of when an EC2 instance is created or a new object is Put into an S3 bucket
* Apache Kafka - a very common enterprise event-source, often used to consume events from other parts of the organisation, or to publish events for integration purposes
* Postgresql - a database trigger, or a change data capture (CDC) event, i.e. when a new row is inserted into a table, or when a row is updated
* RabbitMQ - a message queue, often used for internal communication between services, or to decouple parts of the system
* Webhooks - a common way to integrate with third-party services, or to receive events from a partner, i.e. when a new order is placed, or when a new user signs up. Webhooks simply use the existing HTTP endpoints, and often include their own authentication and security mechanisms

If you need to trigger your functions by another even source, let us know and we can provide it for you, or you can write your own.

See also:

* [Async vs sync invocations](https://docs.openfaas.com/reference/async/)
* [Triggers](https://docs.openfaas.com/reference/triggers/)

**Scaling and lifecycle**

People often ask about the lifecycle of a function in OpenFaaS. Does it spin up a Pod for every invocation? Is there a cold-start? Does it integrate with Helm and ArgoCD? Is my programming language supported?

When you deploy an [OpenFaaS Function, a Custom Resource Definition (CRD)](https://www.openfaas.com/blog/howto-package-functions-with-helm/) is created in Kubernetes, which in turn creates a Deployment and a Service. We chose to use primitive Kubernetes objects such as Deployments because they create normal Pods, that every Kubernetes user will be familiar with. It's as easy to troubleshoot a function as it is a normal application in Kubernetes, `kubectl logs`, `kubectl describe`, `kubectl get -o yaml` and so forth all work exactly the same.

Functions start off life with at least one replica or Pod available at all times. You can increase the minimum availability if you wish, and additional Pods will be added as the autoscaler detects more load on the function.

Whilst replicas or Pods tied to a Deployment will come and go over time if autoscaled, or moved to another node by Kubernetes, you'll find they're usually very stable and long lived. So when a function is not scaled to zero, that means there's a replica ready to serve traffic immediately, without overheads or latency added in. As we mentioned in the template section of this post, functions host a HTTP server, so rather than only being able to process one HTTP request at a time, they can potentially run hundreds or thousands concurrently.

There are no set combinations of RAM and CPU, so you can leave your functions without any resource configuration, or configure a minimum that you think makes sense.

![Load graph from the OpenFaaS Dashboard UI](https://docs.openfaas.com/images/dashboard/load-graphs.png)
> Load graph from the OpenFaaS Dashboard UI

Scale to zero is optional and can help you to pack in functions more densely than if you were using vanilla Kubernetes, and as a result means you can run smaller or fewer nodes, saving money on your infrastructure costs.

For functions where latency is of the upmost importance, keep some minimum availability, for those that can run asynchronously, via cron, or where the latency is not critical, it's worth scaling them to zero.

The amount of replicas of each function will be determined by whatever scaling strategy you've requested - Requests Per Second, CPU consumption, Inflight requests, or a [custom scaling rule](https://www.openfaas.com/blog/custom-metrics-scaling/). You can also set a maximum number of replicas, and a maximum number of concurrent requests per replica.

Learn more: [OpenFaaS Autoscaling](https://docs.openfaas.com/architecture/autoscaling/)

**Observability**

Most cloud platforms provide some form of observability through an optional paid add-on. OpenFaaS provides Prometheus metrics, which you can use to understand the performance, availability, and error rates of your functions.

You can use the OpenFaaS UI or pre-built Grafana dashboards to view the metrics. For logs, you can view them directly via kubectl or the OpenFaaS UI, however some customers also like to use a solution like Grafana Loki, Datadog, or ElasticSearch to store and query logs. 

* [Grafana dashboards](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/) - pre-built dashboards for OpenFaaS, including function performance, gateway performance, and function invocation rates
* [OpenFaaS UI Dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/) - a built-in dashboard for OpenFaaS, showing the status of your functions, invoking them, viewing the logs, and graphs of the metrics
* [Metrics reference page](https://docs.openfaas.com/architecture/metrics/) - understand which metrics are available from each component and what the retention period is

![A Grafana dashboard showing an overview of load, autoscaling and RED metrics](https://docs.openfaas.com/images/grafana/overview-dashboard.png)
> A Grafana dashboard showing an overview of load, autoscaling and Rate, Error, Duration (RED) metrics

## What's next?

This blog post focused on a single team or product that wanted to integrate functions into their existing application, or to build a new product with functions at its core. We covered some common use-cases, and how functions differ from traditional applications, and how they can be integrated into your product. We also covered differences vs traditional applications, and cloud-based functions, and why portability and developer experience are important for many of our customers.

Some OpenFaaS customers don't build their own application with OpenFaaS, but allow others to extend their platform by providing source code for custom functions. These functions are sandboxed in containers in tenant namespaces, and are usually accepted through a cloud IDE built into your customer portal. If that's what you were looking for, take a look at this post: [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)

Now how can you get started?

The easiest way to get started with OpenFaaS is to follow a blog post such as [How to Build and Scale Python Functions with OpenFaaS](https://www.openfaas.com/blog/build-and-scale-python-function/). Even if your preferred language is something else like C# or Java, the principles, configuration, and commands are all the same. This is one of the benefits of using an opinionated platform vs. a DIY approach where every project or component can end up being subtly different.

I've also written a complete eBook with everything you need to get started with writing functions in Node.js called [Serverless For Everyone Else, which you can purchase on Gumroad](https://store.openfaas.com/l/serverless-for-everyone-else?layout=profile).

The Community Edition (CE) of OpenFaaS is free to use for personal use and for initial exploration, it does have some limits, so when you've had an initial exploration, you may want to try out OpenFaaS Standard on a monthly basis. You can find out more about the editions [on the comparison page](https://openfaas.com/pricing/).

The following blog posts may also be of interest to you, and relate to some of the things we covered in this post:

* [Import leads from Google Forms into your CRM with functions](https://www.openfaas.com/blog/import-leads-from-google-forms-to-crm/)
* [How to migrate Python functions from AWS Lambda to OpenFaaS and Kubernetes](https://www.openfaas.com/blog/migrate-aws-lambda-to-openfaas-python/)
* [How to check for price drops with Functions, Cron & LLMs](https://www.openfaas.com/blog/checking-stock-price-drops/)
* [How to transcribe audio with OpenAI Whisper and OpenFaaS](https://www.openfaas.com/blog/transcribe-audio-with-openai-whisper/)
* [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)
* [A Deep Dive into Golang for OpenFaaS Functions](https://www.openfaas.com/blog/golang-deep-dive/)
* [Finding Raspberry Pis with Raspberry Pis](https://www.openfaas.com/blog/searching-for-raspberrypi/)
* [Generate PDFs at scale on Kubernetes using OpenFaaS and Puppeteer](https://www.openfaas.com/blog/pdf-generation-at-scale-on-kubernetes/)

For anything else, please get in touch via the [Talk to us about OpenFaaS for your team](https://docs.google.com/forms/d/e/1FAIpQLSf7lE8kGEElYdvQ5KEYduM6oLybSCozmvrJ8Yk7GHO2RR5Cwg/viewform) form.

