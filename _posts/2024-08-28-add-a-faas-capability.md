---
title: Integrate FaaS Capabilities into Your Platform with OpenFaaS
description: Learn how to integrate Function-as-a-Service (FaaS) into your platform with OpenFaaS. Discover real-world examples and practical insights.
date: 2024-08-29
categories:
- kubernetes
- chargeback
- faas
- cloud
- saas
dark_background: true
image: /images/2024-08-faas-capability/background.png
author_staff_member: alex
hide_header_image: true
---

Learn how a Functions as a Service or (FaaS) capability can be integrated into your platform. With a FaaS capability, customers can provide their own code to execute, and your own staff can extend your product without going through release cycles. OpenFaaS provides a turnkey solution with modular components and REST APIs that are easy to integrate and adapt to your own needs. 

**A quick overview of Functions as a Service**

Functions have become an industry standard for cloud computing, and are available on all major cloud providers. They are often used for background tasks, event-driven processing, and for extending products with custom code. Functions can be written by developers, or people with less traditional development roles alike, because they are often short, and focused on a single task, such as transforming an input into an output, storing data, or calling an API.

The use-cases for functions are broad, these are some of the examples we've seen from customers over the years:

* Transforming data from one format to another such as eCommerce payloads
* Applying rules to security alerts on DNS, network traffic, HTTP requests, or logs, etc
* Encrypting or decrypting data for long-term storage
* Running a machine learning model to predict the next best action for a user
* Enhancing or enriching data with additional information from a third-party API
* Sending notifications or alerts based on a trigger
* Performing maintenance tasks on a scheduled basis
* Data-science and analytics tasks

Invocations can be run directly by users, can be triggered by an event source such as AWS SNS/SQS/S3, Apache Kafka, MQTT, cron, or can be executed in the background, and scaled up or down based on demand.

OpenFaaS runs on Kubernetes and makes use of native objects such as Deployments, Services, Secrets, Namespaces, and Ingress to provide a secure and scalable platform for running functions. The platform is language-agnostic, and functions can be written in any language that can be packaged into a container image.

**In this article**

In this article, we begin by looking at two types of users we generally hear from who want to integrate a FaaS capability, then we we'll see three customer case-studies, showing how they have integrated OpenFaaS for Enterprises into their applications.

![E2E Networks Functions Tab](/images/2024-08-faas-capability/e2e-functions-tab.png)
> Above: The customer dashboard for E2E Networks Limited, a publicly traded cloud provider based in India.

## Is this you?

Let's look at three potential use-cases or personas who may be thinking about functions.

**1. You work in a small team valuing agility & control**

If you're part of a small team and want to use functions, there are a few reasons you may be considering this option.

You'd like:

* increased velocity
* to abstract away the painful details of Kubernetes such as Pod lifecycle and autoscaling
* a built-in way to scale background tasks
* to ship code to production faster
* more control vs a cloud option
* portability between environments

The above reasons are why Kevin Lindsay, Principal Engineer at Surge chose OpenFaaS.

Kevin said:

> When we first adopted OpenFaaS, it was primarily to handle ETL tasks, but it has since become integral to our entire product architecture. We’ve migrated older code into OpenFaaS and now develop everything new—whether it's internal tools or static websites—as functions. This has significantly improved our development speed and scalability, freeing us from worrying about the intricacies of Kubernetes. The asynchronous queue-worker pattern has been particularly impactful, enabling reliable background job processing, with built-in retries and flexible scaling options like spot instances to keep our costs in check.

For teams with this kind of use-case, where you want to use functions directly as part of the product, [OpenFaaS Standard](https://openfaas.com/pricing) would be a good fit.

The other two use-cases we'll explore are where a team wants to offer a FaaS capability to its own users and/or staff.

**2. You need to extend your product**

Your product needs to be extended without redeploying the whole thing, this should be dynamic and easy to achieve, within seconds of providing some custom code. Your staff, or your users, or both will provide code in a set number of languages, and you need to build, deploy, and manage it.

This code may execute in response to events, a schedule, or a third-party API call.

You've considered building your own solution, and may have explored options like the V8 JavaScript isolates, but found that you couldn't support Python, and that the sandboxing was insufficient.

Your development team already works on a product, and is quite capable of front-end and back-end development, so when given well documented APIs and occasional guidance, you believe that they can integrate them into the product within a relatively short period of time. 

The team at Cognite integrated OpenFaaS to create an offering for data-scientists at oil mining companies. Their users provide functions in Python or JavaScript which run simulations and fault prediction models using huge sets of data from the oil rigs. We discuss Waylay and Patchworks later in this article, both of whom also fit this profile.

**3. Your business provides cloud computing**

If your business provides cloud computing, you may have a dashboard for your customers, and you're looking to add a "Functions" tab to it. Your core offering may be built upon a hypervisor such as: VMware, OpenStack, Apache Cloud Stack, a self-built solution, or a repackaging of another cloud's APIs.

Your dashboard has a tab for "VMs", "Block storage", "VPCs, "Load Balancers", "Object Storage", "Databases", and you even added a tab for "Kubernetes" some time ago.

What's missing from the above? Functions. You have customers who are used to seeing Functions on AWS, Google Cloud, and Azure, and they are wondering what you're going to provide them with. Your competition may have added Functions to their platform already, and you'd like to catch up as quickly as possible.

We discuss E2E Networks Limited later in the article that fits into this category.

**In either case**

You may not have the appetite to build your own solution from scratch. You know that when you use an Open Source project, that there's no certain future for it, it's likely severely overstretched and underfunded, if it's even actively maintained anymore. You'd have to do a complex evaluation of every popular option and weigh up the risks and benefits.

One option you may have considered is to build a proxy to an existing cloud functions service, but you find the pricing doesn't scale, or the service is too opinionated, or doesn't support the languages you need.

## What's in the turnkey solution for FaaS?

[OpenFaaS for Enterprises](https://openfaas.com/pricing) is a turnkey solution that contains the APIs, documentation, language support, and building-blocks you need to integrate "FaaS" into your product or cloud offering.

So what's included?

* [A Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/)

    Allows code to be submitted, built, and deployed seamlessly.

    This REST API accepts a Docker build context and publishes a container image to a remote registry. It can be run without root privileges, and can be used to build and deploy functions in a multi-tenant environment.

    The most popular way customers use this is to provide a UI with a code editor such as ACE, Cloud9, or Monaco, and to let customers provide code in a set number of languages.

* [The OpenFaaS REST API](https://docs.openfaas.com/reference/rest-api/)

    APIs for managing and invoking functions, with built-in security features.

    The OpenFaaS REST API has endpoints to create and manage tenant namespaces, to deploy new functions, list and query existing ones, and to invoke them.

    The API has RBAC and IAM built-in, so you can define fine-grained permissions for users, teams, and customers. You can also create roles for your existing microservices that may integrate with the FaaS platform.

* [Billing webhooks & chargeback](https://docs.openfaas.com/openfaas-pro/billing-metrics/)

    Monetization is straightforward with billing hooks.

    Monetization and billing are not an afterthought here. You can provide a webhook URL and will receive batches of events in JSON format whenever a function is invoked for a tenant. The events include the namespace, function name, memory allocated, and the duration of the invocation. The documentation also has a sample Postgresql schema for storing this data.

* [Identity Management and Single Sign-On (SSO)](https://docs.openfaas.com/openfaas-pro/iam/)

    Multi-tenancy and role-based access control to maintain security and segregation of functions.

    The REST API, CLI and Dashboard are all multi-tenant segregating functions by namespace. IAM can be used to define roles with specific permissions for different resources and actions. Single Sign-On supports compliant OAuth2 and OpenID Connect providers, meaning the components can be exposed directly to users if you wish.

* [Monitoring & metrics](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/)

    Prometheus metrics and Grafana dashboards for insights and performance monitoring.

    Detailed Prometheus metrics are available for tenant functions, and the Function Builder API. You can deploy the included Grafana dashboards to monitor the platform and can query this metrics using HTTP to provide customers with their own dashboards.

* [Documentation & support](https://www.openfaas.com/support/)

    Guidance, reference documentation, and weekly office hours.

    When you buy OpenFaaS for Enterprises, you get access to the engineering team on a weekly office hours call to talk about your integration, to ask questions and to get direction. You can email the team at any time with questions, and you'll find comprehensive documentation on the website.

[There's more available](https://docs.openfaas.com/openfaas-pro/introduction/), but these are the core building blocks to take code from customers, to build it, deploy it, and to integrate the new endpoints into your product.

## What it looks like

Let's look at three different customer implementation, walking through their public documentation.

Each customer calls "Functions" something slightly different, for example: "Webscripts", "Custom Scripts", or "Functions". In each case, code is accepted via a web editor, built with the Function Builder API and managed via the OpenFaaS REST API, and deployed to a Kubernetes cluster.

### Patchworks & OpenFaaS

[Patchworks](https://www.wearepatchworks.com/) is an iPaaS platform that helps businesses transform and connect data between retail systems such as e-commerce, ERP, Warehouse management and marketplaces. They have a pre-built library of [*Connectors*](https://doc.wearepatchworks.com/product-documentation/connectors-and-instances/connectors-and-instances-introduction#connectors) to sync to/from associated applications, a pre-built library of OpenFaaS hosted scripts, and also allow customers to supply their own code using *[Custom Scripting](https://doc.wearepatchworks.com/product-documentation/developer-hub/custom-scripting)* which supports 6 programming languages via OpenFaaS with others able to be configured in if needed. 

Whether the *Custom Script* is pre-supplied by the Patchworks team, or created by a customer, it is built and deployed using the same approach by making a HTTP call to the Function Builder API. The resulting container image is published to a registry, and then gets deployed as an OpenFaaS function. Whenever a script is needed by a user's workflow, it is invoked over HTTP via the OpenFaaS gateway.

For an example of the user-experience Patchworks created for their users, see: [Patchworks docs: Adding & testing custom scripts](https://doc.wearepatchworks.com/product-documentation/developer-hub/custom-scripting/adding-and-testing-custom-scripts#creating-a-new-script)

The first thing you do when you create a new script with Patchworks, is to select from one of the languages supported. It's up to you to decide which languages you want your users to be able to use, and you can add more by using the Official Templates, or by writing your own.

![Patchworks language selection](/images/2024-08-faas-capability/patchworks-lang.png)
> Patchworks language selection

Then, you provide the code using a web IDE:

![Patchworks code editor](/images/2024-08-faas-capability/patchworks-code.png)
> Patchworks code editor

Finally, you can enter a test payload, run the invocation and see the output, along with the logs from the function:

![Patchworks test payload](/images/2024-08-faas-capability/patchworks-run.png)
> Patchworks test payload

Next up, let's have a look at a more direct cloud-vendor type of integration with E2E Networks Limited.

### E2E Networks Limited & OpenFaaS

[E2E Networks Limited](https://www.e2enetworks.com/) is an NSE-listed, infrastructure company headquartered in India. They turned to OpenFaaS to offer customers a Function As A Service (FaaS) offering alongside their more traditional VPC, Compute, Object Storage, and Kubernetes services, with a goal to help customers migrate from existing cloud vendors. Users can supply code using predefined OpenFaaS templates, invoke their functions, and monitor the results in one place. E2E Networks also supply a CLI and GitHub Actions integration.

See also: [E2E networks: Function as a Service (FaaS)](https://docs.e2enetworks.com/faas_doc/faas.html)

The team currently provide: Python 3.x, NodeJS and csharp/.NET and are looking to add more languages in the future.

![E2E Networks Functions Tab](/images/2024-08-faas-capability/e2e-functions-tab.png)
> E2E Networks Functions Tab

In a similar way to Patchworks, the user can then select a language, provide code, and test the function.

![E2E Networks Language selector](/images/2024-08-faas-capability/e2e-template.png)
> E2E Networks Language selector

Certain languages such as Python offer a way to provide additional dependencies in a `requirements.txt` file.

![E2E Networks Python requirements](/images/2024-08-faas-capability/e2e-requirements.png)

Then once deployed, users can manage the function, assign a public URL, secrets, view logs, and invoke it.

![E2E Networks Function details](/images/2024-08-faas-capability/e2e-detail.png)

Here's what the logs may look like for a function:

![E2E Networks Function logs](/images/2024-08-faas-capability/e2e-logs.png)

Logs are a convenient way to debug and monitor functions.

### Waylay & OpenFaaS

> The Waylay Enterprise is an all-in-one, low-code automation platform that easily and rapidly helps enterprise-level companies with their digital transformation journey. Everyday people can build automation and optimize ROIs whilst bridging the gap between OT and IT worlds. Thus, allowing your subject matter experts focus on the areas that really matter, reducing bottlenecks and saving millions in the process.

Waylay present OpenFaaS functions to customers as "Webscripts", these are built with the Function Builder API and deployed to a Kubernetes cluster in tenant namespaces. When certain neural networks fire, when a user interacts with the platform, or an IoT action is triggered, the functions are invoked.

![Waylay: Create a New Webscript](/images/2024-08-faas-capability/waylay-new.png)
> Waylay: Create a New Webscript

Once you've selected a language, you can provide the code, and then test the function.

The editor supports syntax highlighting, and you can provide a payload to test the function with.

![Waylay: Edit a Webscript](/images/2024-08-faas-capability/waylay-editor.png)

You can list functions, and copy a secret allocated which protects unauthorized access to the function.

![Waylay: List Webscripts](/images/2024-08-faas-capability/waylay-list.png)

Finally, you can also check the logs of the functions, which could have been invoked by a user directly, or by an event trigger.

![Waylay: See a Webscript's Logs](/images/2024-08-faas-capability/waylay-logs.png)

Waylay's CTO Veselin Pizurica wrote about why they chose OpenFaaS over JavaScript V8 isolates, or writing a wrapper for managed cloud functions back in 2021: [Case-study: Building a Low Code automation platform with OpenFaaS](https://www.openfaas.com/blog/low-code-automation/)

## How do we get started?

Let's say that you have an IaaS-type of offering, and want to add a "Functions" tab.

First, create a new page in your dashboard and call it "Functions" or "FaaS". Whenever users land on that page, invoke the List Functions endpoint on the OpenFaaS gateway, which returns JSON. Render the JSON in a table.

![A sample design: listing deployed functions](/images/2024-08-faas-capability/sample-list-functions.png)
> A sample design: listing deployed functions

For each function, show a link for a "details" page, you can then query the "Query Status" endpoint to get details about the function such as the invocation count, the image reference, how many replicas it is scaled to, how much memory is allocated, and so forth.

When a customer wants to add a new function, pick a cloud IDE of your choice such as: ACE, Monaco, or Cloud9, and provide a code editor. When the user is ready to deploy, make a POST request to the Function Builder API with the code, and then deploy the function using the OpenFaaS REST API. Include the URL of your container registry.

![A sample design: creating a new function](/images/2024-08-faas-capability/sample-create-function.png)
> A sample design: creating a new function

Once the builder has completed, you can POST to the OpenFaaS REST API to create a new function or a PUT to update an existing function.

You can then give the user an invoke button, where your UI will make a HTTP request to the function's URL on the OpenFaaS gateway, and return the result in a text box.

![A sample design: invoking a function](/images/2024-08-faas-capability/sample-invoke-function.png)
> A sample design: invoking a function

That's the basic workflow, but there's lots more you can do once you get the basic workflows working, including:

* Secret management
* Environment variables
* Autoscaling
* Scale to zero
* Monitoring
* Cron schedules, and event triggers from Object Storage, a message queue, or Apache Kafka, etc

## Conclusion

There are multiple types of personas and users for OpenFaaS. Single teams who want to use functions to publish parts or all of their own product are best suited to OpenFaaS Standard. Teams who want to offer a FaaS service as a service or to offer a sandbox for customer code are best suited to OpenFaaS for Enterprises which provides turnkey APIs and components for a quick integration.

In summary, whether you're looking to speed up your development process, extend your product with dynamic capabilities, or offer FaaS to your customers, OpenFaaS provides the tools and support you need to succeed. 

I asked Artyom Sivkov, Engineering Director at Waylay about his long term experiences with OpenFaaS for Enterprises:

> At Waylay.io, OpenFaaS is our default choice when it comes to building robust, performant and scalable solutions for both SaaS and on-premises deployments. We especially value the constant evolution of OpenFaaS that brings more and more added value to our products and attention of OpenFaaS team to our requests and feedback.

If you're interested in learning more, or would like to see a demo of anything we've talked about, please [get in touch](https://www.openfaas.com/pricing).

See also:

* [Building Blocks for Source to URL with OpenFaaS](https://www.openfaas.com/blog/source-to-url/)
* [Bill your users for their usage with chargeback for OpenFaaS](https://www.openfaas.com/blog/chargeback-billing/)
* [How to Build Functions with the Go SDK for OpenFaaS](https://www.openfaas.com/blog/building-functions-via-api-golang/)
* [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)
* [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/)