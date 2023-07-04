---
title: "Build a Multi-Tenant Functions Platform with OpenFaaS"
description: "Learn what it takes to build a functions platform for multiple tenants based upon our experience and insights from customers"
date: 2023-07-04
categories:
- multi-tenancy
- platform
- saas
- hosting
- kubernetes
dark_background: true
author_staff_member: alex
image: /images/2023-07-multi-tenancy/background.png
hide_header_image: true
---

Learn what it takes to build a functions platform for multiple tenants based upon our experience and insights from customers.

## Introduction

The OpenFaaS project has been around since late 2016, and since then it's seen many different kinds of users. Some are hobbyists, others are independent consultants who want to get the job done, some sneak it into a corporate stack without getting approval from their managers (they know what they need!), others make a conscious decision to adopt functions for more flexibility than cloud functions can offer. Some VPs and CTOs just know that a function-based approach will help their team to move faster. The list of [ADOPTERS.md](https://github.com/openfaas/faas/blob/master/ADOPTERS.md) is long and varied, and unfortunately only a small subset of users make it into that list.

One particular type of user that we've seen from the very early days is the "Platform team" and the "SaaS team". Let me briefly introduce you to both:

* Platform team - they're tasked with providing a way for internal developers and teams to run functions, without having to deal with the complexity of Kubernetes.
* SaaS team - they want to extend their own product with code, and OpenFaaS provides a cost-effective and scalable way to do that.
* A mixture of both.

Examples of the Platform team include: mnemonic AS, who provide a vanilla OpenFaaS for Enterprises experience with IAM, users can deploy via GitLab or faas-cli using their identity. Citrix (based in the UK) built a web portal where automation engineers can input Python and PowerShell into a form, which is saved into a database, built as a function, and deployed into a white-labelled OpenFaaS called "CAP Lambda". 

SaaS teams look like: Cognite, Waylay.io, Kubiya and Patchworks.

* Cognite wrapped OpenFaaS and white-labelled it as "Cognite Functions", they offer it to data-scientists at oil mining companies in order to run their own simulations and models against huge data-sets.
* Waylay.io built a platform for industrial IoT and automation, with very clever use of bayesian networks for running workflows. Each part of the workflow is an OpenFaaS function, built with our Function Builder and deployed into their Kubernetes cluster. Customers can provide the function via a UI.
* Kubiya is building a conversational AI for DevOps teams, think of saying something like "Provision a 3x node EKS cluster in us-east-1 with 2x t3.large and 1x t3.medium" and having it just work. They use the Function Builder to build Python functions dynamically and to deploy them to customer clusters, instead of to a central cluster.
* Patchworks offers e-commerce integrations and transformations - their product is a kind of glue. Customers provide PHP code via a web UI, then the Function Builder is used to build and deploy the function into their Kubernetes cluster, they're then scaled to zero until a customer integration runs and needs to be executed.

Sometimes we see a mix of both, LivePerson for instance built a functions platform around OpenFaaS which means their customers get to inject custom code into chat workflows. Their VP of engineering also told me that it's become an essential way for their own developers to build new features and services - quickly, and easily without affecting the core product.

We've just signed a deal with E2E Networks Limited, an ISP based in India to white-label OpenFaaS so that they can offer a "functions capability" for customers, think of it like AWS Lambda, but run with OpenFaaS. The popularity of OpenFaaS along with the flat-rate cost of our enterprise licensing was particularly attractive to them.

## Core components

In each of these multi-tenant use-cases, the customers have a Kubernetes cluster, this could be self-hosted (Rancher, K3s, Kubespray, Ansible, on-prem or cloud-based) or a managed offering like AKS, GKE or EKS.

![Network and namespace segmentation per tenant](/images/2023-07-multi-tenancy/network-segments.png)
> Network and namespace segmentation per tenant

Next, they install OpenFaaS for Enterprises using [the Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas):

* Function Builder - build and publish a function image from source code
* OpenFaaS for Enterprises - OpenFaaS with added IAM, scale to zero, multiple namespaces, multi-user dashboard and runtimeClass support
* Network segmentation - they segment and isolate customer functions by namespace, using network policies or Istio to prevent cross-talk between tenants
* Non-root policy - they configure the OpenFaaS controller to only run functions under a restrictive runtime policy with non-root and a read-only root filesystem
* Runtime Class - in the case of Cognite, they used a Profile to make sure that functions can only run using gVisor, Google's sandboxed runtime for containers. On AWS EKS, Fargate can provide a similar level of isolation
* Node pool isolation - some customers want to have their code run on a dedicated node-pool, that's supported through the Profile concept
* Ingress - each customer gets a route to their own namespaces - whether that's a HTTP path, a subdomain, or a wildcard subdomain
* Monitoring - Prometheus and Grafana are used to monitor the functions by the team operating the platform

Chargeback is a common requirement, and was one of the selling points for E2E Networks Limited. We explained how for every function we have metrics for:

* Number of replicas
* CPU seconds used per function
* RAM consumed per function
* Invocations per function - duration and count

Egress could also be added to this mix by deploying Cilium or Istio to collect Pod metrics, they then need to be correlated by namespace and Pod name to the function name.

## Provision a namespace per tenant

You'll need to create a namespace per tenant using kubectl or the Kubernetes API. The OpenFaaS REST API doesn't have an endpoint to manage namespaces, however we will be adding it soon due to popular demand.

Imagine we have a tenant called `tenant1`, create an annotate a namespace for them:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    openfaas: "1"
  labels:
    kubernetes.io/metadata.name: tenant1
  name: tenant1
spec: {}
```

If your customers are entering code into linked git repositories, or are using a code editor hosted within your own product, then you probably won't need to create individual Policies and Roles for each customer.

However, for the Platform team, this is probably essential.

Create a Policy so that tenant1 can read and write to their own namespace:

```yaml
apiVersion: iam.openfaas.com/v1
kind: Policy
metadata:
  name: tenant1-rw
  namespace: openfaas
spec:
  statement:
  - sid: rw
    action:
    - Function:Read
    - Function:Admin
    - Secret:Read
    effect: Allow
    resource: ["tenant1:*"]
```

Next, you'll need the tenant's unique identity as seen in your OpenID Connect provider. For example, in Keycloak, this is the `sub` claim:

```yaml
apiVersion: iam.openfaas.com/v1
kind: Role
metadata:
  name: tenant1-admin
  namespace: openfaas
spec:
  policy:
  - tenant1-rw
  principal:
    jwt:sub:
     - aa544816-e4e9-4ea0-b4cf-dd70db159d2e
  condition:
    StringEqual:
      jwt:iss: [ "https://keycloak.example.com/realms/openfaas" ]
```

Learn in: [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/)

## Accepting code from your end users

There are a few options here:

1. Enable IAM for OpenFaaS and create a Policy and Role so that customers can deploy directly to their own namespaces
2. Write a web portal with a code editor like ACE or Monaco, then use the Function Builder API to build and deploy the function
3. Integrate with GitHub or GitLab webhooks, so customers just commit their code to linked repositories, and your platform checks out the code and uses the Function Builder to do the rest

Where should you store images for customers?

In every managed functions service we've ever seen from AWS Lambda, to Google Cloud Run to hosted OpenFaaS, the answer is always the same: a registry that you own, control and operate.

Why? By having images in your own registry you can:

* decrease the cold-start latency by having fast access to images
* increase security continually scan and monitor images for exploits and vulnerabilities
* reduce the complexity of managing the many non-standard and complex approaches for registry authentication
* reduce costs by having images pulled from a registry operated in the same network or region as the OpenFaaS cluster

## The Function Builder

The Function Builder is a REST API that builds and publishes containers when it's provided with a Dockerfile and context. The task it performs is very similar to running `docker build -t registry/image:tag . && docker push registry/image:tag`.

![A conceptual diagram of going from source code, and a template to a container ready to deploy to OpenFaaS](https://www.openfaas.com/images/2022-06-how-to-build-via-api/builder-api-flow.png)
> A conceptual diagram of going from source code, and a template to a container ready to deploy to OpenFaaS

It comes with:

* Rootless mode - the builder runs as a non-root user, and builds images as a non-root user
* Monitoring and metrics an a Grafana dashboard
* Single replica or multiple replicas to load-balance builds
* Concurrency limiting to prevent overloading the cluster
* Layer caching to speed up builds
* Mutual TLS generation to prevent builds from being hijacked

![Monitoring the builder - throughput, duration and concurrency](https://docs.openfaas.com/images/grafana/builder-dashboard.png)
> Monitoring the builder for throughput, duration and concurrency

We have documentation and examples for various languages:

* [Tutorial: How to build functions from source code with the Function Builder API](https://www.openfaas.com/blog/how-to-build-via-api/)
* [Function Builder API Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder)
* [Function Builder API Examples - Node.js, Go, PHP and Python](https://github.com/openfaas/function-builder-examples)
* [Docs: Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/)

## Manage customer functions via API

The following API endpoints are available for managing functions:

Functions:

* Create, update, delete, list, query status
* Query logs

Secrets:

* Create, Update, Delete, List

An invocation count and RAM/CPU consumption are included in the list functions endpoint, however Prometheus provides a separate API endpoint for running queries.

Useful links:

* [OpenAPI specification for OpenFaaS](https://github.com/openfaas/faas/blob/master/api-docs/spec.openapi.yml)
* [Go structs in faas-provider](https://github.com/openfaas/faas-provider/tree/master/types) are also very useful.
* [Go SDK for OpenFaaS](https://github.com/openfaas/go-sdk)

Deploying an image via the OpenFaaS REST API can be as simple as the following `curl` command:

```bash
export HOST=http://127.0.0.1:8080
export PASSWORD="" # OpenFaaS REST API password
export FUNCTION="hello-world"
export NAMESPACE="tenant1"

export IMAGE=ttl.sh/openfaas-image:1h 

curl -s \
  --data-binary \
  '{"image":"'"$IMAGE"'", "service": "'"$FUNCTION"'", "namespace": "'$NAMESPACE'"}' \
  http://admin:$PASSWORD@$HOST/system/functions
```

The above example uses the root account and basic authentication, however you can also use a JWT token and a specific Role and Policy linked to a trusted identity provider.

You can also add labels, environment variables, annotations, secrets, CPU/RAM requests and limits, scheduling constraints and more by adding them to the JSON payload.

Learn all the options by studying the [FunctionDeployment struct in faas-provider](https://github.com/openfaas/faas-provider/blob/master/types/function_deployment.go)

Of course, in addition to creating a function, you can also query, update, delete and list functions using the REST API.

At times, your customers may also need a number of secrets, these can also be created by an API call to the OpenFaaS gateway.

Create a secret called `minio-access-key` within the `tenant1` namespace:

```bash
export HOST=http://127.0.0.1:8080
export PASSWORD="" # OpenFaaS REST API password
export NAMESPACE="tenant1"
export SECRET_NAME="minio-access-key"
export SECRET_VALUE="API KEY VALUE"

curl -s \
  --data-binary \
  '{"name":"'"$SECRET_NAME"'", "value": "'"$SECRET_VALUE"'", "namespace": "'$NAMESPACE'"}' \
  http://admin:$PASSWORD@$HOST/system/secrets
```

* `value` - is used to pass a string as the value of the secret
* `rawValue` - can be used to pass binary data as a secret

See also: [the struct that represents an OpenFaaS Secret](https://github.com/openfaas/faas-provider/blob/master/types/secret.go)

To show a list of functions for a customer's namespace run:

```bash
export HOST=http://127.0.0.1:8080
export PASSWORD="" # OpenFaaS REST API password
export NAMESPACE="tenant1"

curl -s \
  http://admin:$PASSWORD@$HOST/system/functions?namespace=$NAMESPACE
```

To get the status for a specific function run:

```bash
export HOST=http://127.0.0.1:8080
export PASSWORD="" # OpenFaaS REST API password
export NAMESPACE="tenant1"
export FUNCTION="hello-world"

curl -s \
  http://admin:$PASSWORD@$HOST/system/function/$FUNCTION?namespace=$NAMESPACE
```

In each API example, it may be useful to pipe the output to `jq`.

The `faas-cli` is an official client for the OpenFaaS REST API, and you can use it to get insights into different API calls.

```
FAAS_DEBUG=1 faas-cli list

GET http://127.0.0.1:8080/system/functions
User-Agent: [faas-cli/dev]
Authorization: [Bearer REDACTED]
Function                      	Invocations    	Replicas
custom                        	5              	0    
echo                          	10             	1  
```

Here's another example showing labels:

```
FAAS_DEBUG=1 faas-cli store deploy figlet --label com.openfaas.scale.zero=true --label com.openfaas.scale.zero-duration=2m
PUT http://127.0.0.1:8080/system/functions
User-Agent: [faas-cli/dev]
Authorization: [Bearer REDACTED]
Content-Type: [application/json]
{"service":"figlet","image":"ghcr.io/openfaas/figlet:latest","envProcess":"figlet","labels":{"com.openfaas.scale.zero":"true","com.openfaas.scale.zero-duration":"2m"},"annotations":{}}

Deployed. 202 Accepted.
URL: http://127.0.0.1:8080/function/figlet
```

Customers can write logs to stdout and stderr, these will be picked up by OpenFaaS and printed out to the function's logs:

See also: [Function Logs](https://docs.openfaas.com/cli/logs/)

## Scale to Zero

Whenever a function is deployed, you can control how it scales by setting various labels.

For a multi-tenant platform, we often see customers enabling scale to zero by default, but it is optional.

* `com.openfaas.scale.zero` - `true` or `false` - default is false
* `com.openfaas.scale.zero-duration` - the time in a Go duration where there are no requests incoming before scaling a function down i.e. `20m`, `1h`

Scale to Zero is also included in OpenFaaS Standard.

See also:

* [Docs: Scale to Zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)
* [Fine-tuning the cold-start in OpenFaaS](https://www.openfaas.com/blog/fine-tuning-the-cold-start/)

## Profiles

The Profiles concept was our way of keeping the OpenFaaS function specification concise, whilst allowing for more complex Kubernetes configurations to be applied to functions.

Profiles are created in the `openfaas` namespace by an administrator.

Functions can adopt a pre-defined profile by setting an annotation: `com.openfaas.profile: <profile_name>`, or by specifying a comma-separated list of profiles: `com.openfaas.profile: <profile_name>,<profile_name2>`.

This includes: `podSecurityContext`, `affinity`, `tolerations`, `topologySpreadConstraints` and `runtimeClassName`.

A note on 
This example makes a function adopt the `gvisor` profile for sandboxing the container using Google's gVisor project:

```yaml
kind: Profile
apiVersion: openfaas.com/v1
metadata:
    name: gvisor
    namespace: openfaas
spec:
    runtimeClassName: gvisor
```

Learn more about gVisor here: [What is gVisor?](https://gvisor.dev/docs/)

[Kata Containers](https://katacontainers.io/) also offer Kubernetes integration using lightweight VMs such as Cloud Hypervisor (an alternative to Firecracker).

You will need to consider all of these within your platform, so read up how to use them in the docs.

See also:

* [OpenFaaS profiles](https://docs.openfaas.com/reference/profiles/)

## Charge your customers

If you're running a business, you'll likely have to charge your customers for the resources they use. If you're building an internal service, and you don't need to charge, you may want to report and monitor usage.

* Rate, Error and Duration aka RED metrics are available for every function
* Pod RAM and CPU consumption metrics are also available, grouped by function

There are many metrics, but for a couple of brief examples:

* `gateway_functions_seconds` contains all the seconds of execution time per function, so you could query: `gateway_functions_seconds{namespace="tenant1"}`.
* `gateway_service_count` shows the amount of replicas of a function, so by combining this with the RAM request or limit, you could calculate GB-seconds of RAM used `gateway_service_count{namespace="tenant1", name="hello-world"}`.
* `pod_cpu_usage_seconds_total` shows seconds of CPU consumed per function, which includes time between invocations and may be more accurate so, you'd query `pod_cpu_usage_seconds_total{namespace="tenant1", name="hello-world"}`.

There are more metrics available to you than these, so have a look through them to decide how you want to measure and report back to your customers or the rest of the business.

Read about the various metrics included here: [Docs: Monitoring Functions](https://docs.openfaas.com/architecture/metrics/)

Learn how to query Prometheus via API: [Docs: Prometheus HTTP API](https://prometheus.io/docs/prometheus/latest/querying/api/)

Make sure you have long-term retention of metrics if you're using them for billing.

Don't edit the OpenFaaS Prometheus configuration directly, but instead, run a separate Prometheus/Thanos/Cortex/Grafana Mimir instance and scrape the OpenFaaS Prometheus instance using [Prometheus federation](https://prometheus.io/docs/prometheus/latest/federation/)

## A note on function configuration

In the Helm chart, set:

* `functions.setNonRootUser` - force every function deployed to run as a non-root user, even if the Dockerfile uses root

When you deploy functions you can enforce additional constraints:

* Set a specific Profile to have functions only run on certain nodes
* Set a profile to force the use of gVisor or Kata container sandboxing using a runtimeClass
* Set CPU/RAM requests or limits to prevent resource exhaustion
* Set `readOnlyRootFilesystem` to prevent functions from writing to the root filesystem, they'll still be able to write temporary data to /tmp/

Auto-scaling limits including scale to zero are controlled through labels at deployment time.

The readOnlyRootFilesystem setting, CPU/RAM requests and limits are controlled through additional fields in the function's spec. See the [OpenFaaS YAML reference as a guide](https://docs.openfaas.com/architecture/stack/).

You can define a custom PodSecurityContext for functions using a Profile too, here's an example:

```yaml
kind: Profile
apiVersion: openfaas.com/v1
metadata:
    name: gvisor
    namespace: openfaas
spec:
    podSecurityContext:
        runAsUser: 1000
        runAsGroup: 3000
        fsGroup: 2000
        runAsNonRoot: true
```

In addition in both OpenFaaS Standard and OpenFaaS for Enterprises, `AllowPrivilegeEscalation` is set to false by default and cannot be changed on functions.

We also disable the EnableServiceLinks feature in Kubernetes which can expose information about other services and endpoints to functions.

Remember to create network policies with your Container Networking Interface (CNI) driver of choice to prevent functions from accessing the Kubernetes API or other services.

Various CNI drivers and service meshes offer encryption of traffic between pods, so you may want to introduce this in addition to network policies. For an example of how to do this with Istio, see: [Learn how Istio can provide a service mesh for your functions](https://www.openfaas.com/blog/istio-functions/)

For the namespace, you may also wish to add a [Limit Range](https://kubernetes.io/docs/concepts/policy/limit-range/). A Limit Range may restrict a customer to using a maximum of 5 vCPU and 5 GBP of RAM for instance, across all replicas of his or her functions.

## Wrapping up

I wanted to introduce you to a some customers and their use-cases for multi-tenancy. I also wanted to introduce some of the core ideas and concepts that you'll need to consider when building a multi-tenant platform with OpenFaaS.

Whilst this is not an exhaustive guide, it is built from real-world experience and feedback from customers, and I think it'll help you get started.

There's a lot more to OpenFaaS that we could have talked about like giving direct access to `faas-cli` and the multi-tenant dashboard, integration with GitHub Actions or GitLab, event-triggers like Cron, Kafka and asynchronous function invocations with NATS JetStream.

Remember, we're always here and happy to help you check and fine-tune your OpenFaaS for Enterprises setup for multi-tenancy.

* [Join the free Office Hours call for community users and customers](https://docs.openfaas.com/community/)
* Make a suggestion or ask a question in the [Customer Community](https://github.com/openfaas/customers)
