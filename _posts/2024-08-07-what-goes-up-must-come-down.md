---
title: On Autoscaling - What Goes Up Must Come Down
description: 
date: 2024-08-07
categories:
- kubernetes
- faas
- functions
- autoscaling
dark_background: true
image: /images/2024-08-scaling/background.png
author_staff_member: alex
hide_header_image: true
---

This article has two parts, in the first, we'll look at the evolution of autoscaling in OpenFaaS going back to the original version in 2016, along with how and why it changed, and continues to be improved. In the second part we will explain what needs to be considered when scaling up and down to prevent any dropped messages or HTTP errors.

## 1. The story so far

The first version of OpenFaaS was created in 2016 and provided a REST API, UI and CLI for deploying functions using containers. Whilst it was possible to set the amount of replicas for a function, there was no automation for this, no "autoscaling" of the copies of the function. Adding copies of the same function is known as Horizontal Scaling, and increasing the RAM or CPU available to a function is known as Vertical Scaling. For the purposes of this article, you can assume we are only talking about Horizontal Scaling.

If you didn't know, an OpenFaaS Function is a Kubernetes Custom Resource which ends up being transformed into a Deployment and a Service by the OpenFaaS operator. Deployments are the primary way to run containers in Kubernetes, and Services are used to access their various endpoints. When you build a function, you're building a container image that can serve HTTP traffic, OpenFaaS configures Kubernetes to make it accessible via a URL, and also tracks metrics for it. 

**Prometheus and AlertManager**

Shortly after releasing OpenFaaS and integrating Prometheus metrics, Patrick Chanezon (then at Docker) suggested using AlertManager to trigger autoscaling.

This worked by defining a rule that monitored the rate of requests per second (RPS) for a function, and then sent a webhook to the OpenFaaS gateway to increase or calculate the new number of replicas. Once the alert was cleared, the replicas would be scaled back to the minimum amount, usually 1.

What surprised me was how this simple system that shouldn't have really been that useful on paper, was very effective in practice and was loved by users. It worked and it was enough to get started with and to allow us to focus on adding other core features.

**Scale to zero to save on costs**

It was only in 2018 that a large user of OpenFaaS complained of the mounting costs of their various test environments, where the amount of functions deployed meant the cluster size was relatively large and expensive to run. This was the first time that we had to think about when a function is idle, and how to scale it down not to just a single replica, but to zero, and then how to reactivate it again.

You can read about scale to and from zero here: [Docs: Scale to Zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)

**What about long running functions?**

It wasn't until 2019 that we started to work with customers whose functions just couldn't scale based upon Requests Per Second. RPS is a trailing metric that is only counted *after* an invocation, and not before. So if you have a function that takes 60 seconds to execute, the RPS value would be under zero and unlikely to trigger the alert we were using.

We did a few things at this point:

* Combined the Horizontal scaler and scale to zero code into one component
* Made it possible to set the RPS scale target on a per-function basis
* Added a new mode called capacity that scaled on the number of active invocations, not only on completed ones
* Added CPU-based scaling for functions that were primarily I/O bound

The capacity scaling mode transformed the way that OpenFaaS could be used, it was now possible to scale functions that took so long to execute that they wouldn't trigger an RPS rule. That meant that machine-learning, data-processing pipelines, and other long-running functions could be scaled up and down based upon the number of ongoing invocations.

See also: [Improving long-running jobs for OpenFaaS users](https://www.openfaas.com/blog/long-running-jobs/)

Future work may involve queue-based scaling for [asynchronous (async) invocations](https://docs.openfaas.com/reference/async/) queued via NATS JetStream. A queue depth combined with a target number of invocations per Pod makes for a very accurate way to right-size the number of replicas for a function to the amount of pending work. We have also considered RAM-based scaling, however our testing showed it was unlikely to improve on the existing RPS, CPU and Capacity modes for most customers.

**The new stable window for scaling down**

The autoscaler has continued to improve and take inspiration from other projects in the ecosystem such as the Kubernetes Horizontal Pod Autoscaler (HPA).

One of the first things we hear from customers moving from HPA to OpenFaaS is that our autoscaler is much more responsive, and for functions, that's something they welcome. HPA is certainly a masterpiece of engineering, but it is designed to be generic and doesn't know how to scale functions.

We have implemented HPA's *stable window* concept for OpenFaaS, so that when enabled, a function cannot be scaled down to a level lower than the maximum recommendation over the period of the window.

Consider a variable load, which peaks and troughs every 2.5 minutes, without a stable window, the replicas roughly match the input load, but with a stable window, the replicas rise up and are kept high until the end of the load test.

![Stable window example](https://docs.openfaas.com/images/stable-window.png)
> Example of variable load being smoothed out by a stable window

You can learn when and how to configure the stable window in the [OpenFaaS documentation](https://docs.openfaas.com/architecture/autoscaling/) under "Smoothing out scaling down with a stable window".

## 2. What goes up must come down again

If your function is quick to start-up, has no state, and can be restarted without losing any data, then you may just get away with deploying it and being able to autoscale it without any errors. However, in the real world, we tend to find functions may need to load some state before they can serve traffic, and they may also need some time to finish executing before they can be terminated. They may also have a maximum number of concurrent invocations that they can handle at any one time, so could be overwhelmed if not configured to push back at those times.

![Various states of a replica](/images/2024-08-scaling/replicas.png)
> A replica or Pod in Kubernetes can have various states of starting and stopping. In order to make sure all requests execute, we need to consider the lifecycle of a Pod.

**Configuring autoscaling for functions**

OpenFaaS offers detailed load, scaling, CPU/RAM and invocation metrics to help you understand how well your functions are performing. This is essential feedback to understand how well your functions are performing and to know if they are being scaled correctly. 

![Detailed scaling and invocation metrics](https://docs.openfaas.com/images/grafana/overview-dashboard.png)
> Detailed scaling and invocation metrics

* If your function is long running, consider the capacity mode
* If your function is quick to execute, try the RPS mode
* If your function is I/O bound, or doesn't scale well in either of the above, consider CPU-based scaling

With each of the above, you can set:

* A minimum amount of replicas
* A maximum amount of replicas
* Whether to scale to zero, and if so, how long to wait before doing so
* The target value per replica for the metric you are scaling on
* The method of scaling: RPS, CPU, or Capacity
* An optional hard limit on the total number of invocations per Pod (`max_inflight`) before 429s are returned

By default, the autoscaler only emits logs when it changes the replica count for a function, so if you'd like to learn what the autoscaler is doing and why it is making the decisions it is, you can turn on verbose logging via the Helm chart with `verbose: true` under the `autoscaler` section.

We sometimes see the uninitiated turn to tools such as `siege` or `hey` in order to load test their functions, however these tools are not representative of genuine user traffic and more closely resemble a Denial of Service (DoS) attack. So we built and open-sourced our own [set of E2E tests](https://github.com/openfaas/openfaas-autoscaler-tests) which exercise each mode of the autoscaler. These include various scenarios including a ramp-up, variable load, and spikes in traffic.

**Considerations for scaling up**

There are three scenarios when a function scales up:

1. the initial deployment before teh function exists
2. the running version of replaced by a new version with a rolling update
2. the function is already running a stable number of replicas, and the count increases

If the function needs some time before it can accept a request, then you'll need to implement a Ready check. This is configured through an annotation, and you can write code in your handler to look at the HTTP Path.

Consider an example where the function cannot accept data unless it has downloaded a dataset from S3:

```python
set = None

def handle(event, context):
    global set

    if not os.path.exists("/tmp/dataset.csv"):
        set = download_dataset()

    if event.path == "/ready":
        if set is None:
            return {"statusCode": 503}
        else:
            return {"statusCode": 200}

    response_body = apply_dataset(event.body, set)

    return {
        "statusCode": 200,
        "body": response_body
    }
```

Not only can the Readiness path be overridden, but the time until the first check can be configured, which is useful if you know that the dataset can take 10-20s to download for instance.

How do you know if you need a Readiness path? You can use the OpenFaaS Grafana dashboards to monitor the HTTP status codes encountered whilst the function is scaling up to see if the function would benefit from one.

See also:

* [Custom health and readiness checks for your OpenFaaS Functions](https://www.openfaas.com/blog/health-and-readiness-for-functions/)
* Reference on [Workloads and Readiness checks](https://docs.openfaas.com/reference/workloads/)

**Scaling down and to zero**

Scaling down can happen in three scenarios and results in the termination of the Pod running the function:

1. the first is when the autoscaler sets a lower value of replicas to the running value, so 5=>4 or 10=>1 and so forth.
2. The next is when you perform an update on an existing function, the old replicas are slowly removed by Kubernetes whilst the new ones are brought online.
3. And the third example is when a function is scaled to zero due to being idle.

Scaling down involves removing a running Pod, so in order to avoid any loss of data, we must *drain* the work being done by the function by shutting it down gracefully.

In each case, the function will be sent a SIGTERM signal, and it will have a grace period to finish any work and then exit. Most official OpenFaaS templates when combined with the OpenFaaS watchdog will handle a graceful termination for you, you just need to make sure the grace period is long enough.

The default grace period is 30s, but it can be extended by setting the `write_timeout` environment variable. Once set, the function will likely wait for the full period i.e. `write_timeout=5m` before exiting, in this case, you need to set another variable called `healthcheck_interval` to a lower value such as `5s` and the function will drain faster and exit.

**Coldstarts and scaling back up from zero**

The code path for scaling back up from zero replicas and the initial deployment of a function are very similar. The Kubernetes scheduler will find a node with enough resources and then start the Pod. The function will then be sent a HTTP GET request to the Readiness path, once it returns a 200 OK, the function will be added to the Kubernetes endpoint and start to receive traffic.

I've seen cold-starts go as low as 0.5-0.7s in Kubernetes, but they will not get any lower than that without hacks and workarounds that may not be suitable for production. Why is that?

In any case, cold-starts are optional in OpenFaaS and many users run a minimal set of replicas like 1 all the time to handle bursts of traffic, or may run their [invocations asynchronously](https://docs.openfaas.com/reference/async/) to mask the problem.

It helps to understand exactly what is happening when a Pod gets scheduled and starts up, see also: [Dude where's my coldstart?](https://www.openfaas.com/blog/what-serverless-coldstart/)

## A footnote on Cluster Autoscaling

So long as requests and / or limits are set on each Function when you deploy it, the [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler) will be able to calculate how many nodes are required for the amount of functions and replicas requested by the OpenFaaS autoscaler.

You can often save money on AWS and Google Cloud by using Spot instances or [preemptible VMs](https://cloud.google.com/compute/docs/instances/preemptible), in return for the risk of the node being reclaimed at short notice at any time, you can get savings of up to 75% vs on-demand instances. On both cloud platforms you can create dedicated node groups or [node autoscaling groups](https://aws.amazon.com/blogs/compute/cost-optimization-and-resilience-eks-with-spot-instances) to manage the lifecycle of these instances.

An alternative is to use an open source project like [Karpenter](https://karpenter.sh/) which can right-size workloads to nodes and manage spot instances.

As a rule, the core services for OpenFaaS must be run on a stable set of nodes to prevent downtime, but many types of functions can run on spot instances. Just bear in mind that if there's something like a 60s warning until a spot instance gets reclaimed, you will have to accept that functions may not be able to drain gracefully in that time. You can use a mix of on-demand and spot instances to mitigate this risk, or invoke your functions asynchronously to that they get retried if an invocation fails due to a spot instance being reclaimed.

## Wrapping up

In 2016, OpenFaaS started as a proof of concept, and the initial version of autoscaling was added later, in time, customers presented new use-cases like the need to scale long running functions, and to save on compute resources. The autoscaler has grown and developed, with new features like stable window for scaling down, and the ability to scale on CPU usage.

What I wanted to get across in the article was that there isn't one single way to scale functions which is perfect out of the box. Some consideration has to be put into how the function is fed requests, how long it takes to start up, the latency, and how and if it needs to be drained before it can be terminated.

OpenFaaS makes use of all the same Kubernetes primitives such as readiness checks, termination grace periods, and metrics collection, but automates it when possible, or abstracts it behind simple interfaces. Customers can get detailed feedback through Grafana dashboards, and fine-tune the autoscaler through a set of annotations.

But compared to Kubernetes HPA which is a generic tool with many options, the OpenFaaS autoscaler was purpose built to scale functions based upon customer workloads that we had seen. For that reason it's much more responsive, supports scale to zero, and doesn't require any third party add-ons or configuration to work with Prometheus metrics.

With that in mind, and the move from NATS Streaming to NATS JetStream for async invocations, we are looking into ways to scale functions based upon queue-depth, which is another popular approach for autoscalers.

![Monitoring of async messages with NATS JetStream](https://docs.openfaas.com/images/grafana/jetstream-queue-worker-dashboard.png)
> Monitoring of async messages with NATS JetStream

See also:

* [Docs: Auto-scaling your functions](https://docs.openfaas.com/architecture/autoscaling/)
* [Docs: Scale to zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)
* [Docs: Workloads & readiness checks](https://docs.openfaas.com/reference/workloads/)
* [Docs: Grafana metrics & monitoring](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/)
* [Docs: Asynchronous invocations](https://docs.openfaas.com/reference/async/)
