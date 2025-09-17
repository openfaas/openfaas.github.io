---
title: "Optimise OpenFaaS costs on AWS"
description: "Whilst OpenFaaS comes with predictable, flat-rate pricing, AWS is charged based upon consumption. We'll explore how to save money."
date: 2025-09-17
author_staff_member: alex
categories:
- costs
- optimisation
- kubernetes
- serverless
dark_background: true
image: "/images/2025-09-reduce-costs/background.png"
hide_header_image: true
---

Whilst OpenFaaS comes with predictable, flat-rate pricing, AWS is charged based upon consumption. We'll explore how to save money and optimise our costs.

## Introduction

There are a few common reasons why customers may decide to pay for OpenFaaS, and deploy it to AWS instead of using AWS Lambda, a serverless product that's offered by AWS.

* Control over limits - many settings that are restricted on AWS Lambda are configurable with OpenFaaS - from timeouts, to container runtimes, to CPU/memory limits.
* Portability - customers often start with an easy and convenient option like Lambda before obtaining an enterprise customer that requires an additional deployment on-premises or into another cloud provider. Lambda is locked into AWS.
* Cost savings - whilst Lambda starts within a free tier allowance, it can quickly get out of hand, and the cross-over point for a paid OpenFaaS license can be met quite quickly.
* No need for cold starts - OpenFaaS functions maintain 1/1 replicas by default, unless you configure scale to zero on them. So there's no need for any cold start, for critical functions.
* No false economy - in order to keep Lambda costs reasonable, users will often under-provision the resources for their functions, or worse, over-provision them in order to get more vCPU.
* Kubernetes all the way - if your team already deploys to Kubernetes, then Lambda is orthogonal and means your developers have to build and operate code in two different systems.

Of course there are other reasons, but these points stand out across customers.

| Aspect                        | AWS Lambda          | OpenFaaS on EKS|
|------------------------------|-------------------|----------------|
| Free Tier                    | Yes (limited)                    | Free for personal use. Commercial use has predictable flat-rate licensing. |
| Scaling Cost                 | Per invocation + duration        | EC2 - can optimise with autoscaling, spot instances, and scale to zero |
| Cold Starts                  | Unavoidable unless kept "warm"   | No cold-start by default |
| Speed up the runtime         | Add more RAM to get a bit more vCPU | Pick any amount of vCPU or RAM, or allocate NVMe for super fast storage |
| Access to GPUs               | Not available | Yes, available using a node group with GPU instances |
| Total Cost at Scale          | Can spike with traffic or increased product adoption/function execution time  | Stable costs. Spot instances can reduce EC2 by up to 90% |
| Plays nicely with your Kubernetes deployments? | No, orthogonal tooling and development | Uses native Kubernetes objects including a CRD |
| Customise the limits/environment for functions | No | Yes, most settings can be changed easily |
| Time to deploy | Can take minutes to rollout a new version via CloudFormation | New version can be live in single-digit seconds |
| Portability | None | Run the same functions on any Kubernetes cluster in the cloud or on-premises |

## Knobs and dials for controlling cost

**Kubernetes control-plane**

Typically, you'll deploy OpenFaaS to Kubernetes on AWS using their managed product [Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/). EKS has a running cost per cluster of around $75 USD per month.

You can also self-manage Kubernetes with a tool like [K3s](https://k3s.io/) for more flexibility. But bear in mind, if you're staying on AWS, the cost per control plane is not going to add up to a lot.

**The unwritten costs of AWS**

This is beyond the scope of our article that focuses on AWS EKS, [EC2](https://aws.amazon.com/ec2/) and OpenFaaS, but take all the usual advice in hand on optimising or reducing the use of CloudWatch, S3, NAT gateways, and other AWS services.

* Use VPC endpoints for AWS services (e.g., S3, DynamoDB) to avoid public internet fees—savings of $0.01/GB or more.
* Minimize cross-AZ traffic by pinning functions to single-AZ nodes if latency allows.

Take a detailed look at your monthly AWS bill and identify any hot spots for improvements.

Avoid [EKS Extended Support fees](https://cloudgov.ai/resources/blog/how-to-save-money-on-amazon-eks-clusters-with-extended-support-version-updates/). EKS charges $0.60/hr per cluster if you linger on an unsupported Kubernetes version. Keep a quarterly upgrade policy (N-2 policy) to stay on the standard $0.10/hr control-plane price.

**Kubernetes nodes**

Kubernetes reqquires nodes to run your Pods, which are usually provided by AWS EC2 (virtual machines). AWS also offers products like Fargate, but Fargate tends to be more expensive, and slower to start up.

The cost of nodes can be optimised in three ways:

1. Right-size your nodes to match the functions.

    By default, nodes can only run 100 Pods, so if you have many many Pods for your functions, using larger nodes could be a false economy.

2. Use autoscaling to scale nodes up and down based on demand.

    One of our customers runs a separate production and staging EKS cluster, but the staging cluster costs them very little. With scale to zero enabled on all their functions, they can get away with a single node that just runs the control-plane, at a very low cost. As soon as a function is started, it'll either load up on the existing node, or a new one will be added and removed after the function scales back down to zero again.

    You're likely aware of the benefits of AWS Savings Plans or Reserved Instances (RIs) for baseline nodes. If you are expecting your product to be in business for the next year or three, you can commit to purchase a certain amount of EC2 from AWS and get decent savings in return without any disk of the instances being terminated.

3. Use spot instances to save up to 90% of your costs.

    Spot instances are the most obvious way to save money on AWS, cutting EC2 bills by up to 90%, however they do have some downsides. Spot instances can be terminated at any time, with just two minutes' notice. The open-source node-autoscaler built by AWS for EC2 called [Karpenter](https://karpenter.sh/) can help you out here, but we also need to remember that a spot instance can take 1-2 minutes to start up, register, and start running a Pod. We created the [Headroom Controller](https://openfaas.com/blog/headroom-controller/) to help reduce this delay, and the impact of instances being terminated.

**Check yourself**

We often see teams using nodes that are far too large, due to RAM/vCPU sizing that was taken from AWS Lambda, where you have to allocate more RAM to get additional vCPU quota. In one instance, a team needed to keep 300 functions "warm" and had historically allocated 3GB of RAM to each function. Why did they do that? When asked, they had no idea why that number was picked or how much RAM they actually needed.

Kubernetes doesn't play by these rules, you can simply ask for what is required. The [metrics built-into](https://docs.openfaas.com/architecture/metrics/) OpenFaaS can be used to monitor the resource usage of your functions and adjust the node size accordingly.

**Open your Arms**

In 2015, I had to recompile Docker from source to be able to run it on a Raspberry Pi. In fact I even had to recompile Go first as a prerequisite.

These days, Kubernetes and core tooling like ArgoCD, Helm, cert-manager, Istio, NATS, Prometheus, and Grafana all work flawlessly on the Arm architecture.

If you're an AWS user, you should absolutely consider and experiment with running functions on Graviton instances. Whether that's the whole collection, or just specific functions.

In return you'll get fast performance and cost savings, whilst helping to reduce your carbon footprint since Arm chips tend to use way less energy.

The following page entitled [Use Graviton instances and containers](https://docs.aws.amazon.com/prescriptive-guidance/latest/optimize-costs-microsoft-workloads/net-graviton.html) shows a 19.20% - 14.99% reduction in costs from using Graviton.

AWS Case study: [Performance gains with AWS Graviton4 – a DevitoPRO case study](https://aws.amazon.com/blogs/hpc/performance-gains-with-aws-graviton4-a-devitopro-case-study/)

**OpenFaaS licensing**

Each installation of OpenFaaS requires a separate license key.

If you have environments that sound like this: Dev, QA, UAT, Staging, Pre-Prod, DR, Prod, then OpenFaaS could work out quite expensive.

To optimise your costs, you may want to reevaluate whether you *really need* as many as 7 different Kubernetes clusters to test your functions in before finally rolling them out to production. For OpenFaaS for Enterprises, we can sometimes offer custom package for this type of secenario, so definitely reach out to us for a call.

An alternative option when you have many environments is to use OpenFaaS for Enterprises and its multiple-namespace support. In this way, the various environments become Kubernetes namespaces that are isolated from one another. It's also ideal for centrally managed IT, FaaS offered as a service to employees, and for multi-tenant environments.

**Scale to Zero for functions**

[Scale to Zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/) for functions is a feature that allows your functions to scale down to zero when they are not being used. This can help you save money on your AWS costs by reducing the number of EC2 instances that are running at any given time.

The idle timeout can be set on a per-function basis, and unlike AWS Lambda, it's opt-in. No need to keep a background process invoking your function wastefully, just in case.

You can learn how autoscaling and scale to zero work together in this blog post: [On Autoscaling - What Goes Up Must Come Down](https://www.openfaas.com/blog/what-goes-up-must-come-down/)

**Delete old/unused functions**

If you are running a large installation of OpenFaaS and have accumulated a large number of functions, you can review the metrics to understand which are no longer being used.

There are two approaches:

1. Use the built-in [Prometheus](https://prometheus.io/) metrics (defaults to 14 days of retention) to identify functions which can be removed. Or use your own long-term storage i.e. DataDog to search back even further.
2. If you're using a multi-tenant installation of OpenFaaS for Enterprises, you can enable [Billing Webhooks](https://docs.openfaas.com/openfaas-pro/billing-metrics/) and track invocations over time in a database. You can then use this data to run a clean-up via Cron.

**Do you really need Kubernetes?**

We built another version of OpenFaaS called [OpenFaaS Edge](https://docs.openfaas.com/deployment/edge/). It's designed to run on a single VM or bare-metal host and can run up to 1000 functions.

OpenFaaS Edge is perfect for automations, background jobs, and other tasks that do not need to scale beyond a single machine or a single replica.

If you're willing to do some legwork, it can also be installed on different hosts to shard functions across multiple machines.

**Consider other compute providers than AWS**

AWS EKS is probably the most platform that our customers use to deploy and manage OpenFaaS, but it's not the only game in town.

For one, other compute providers may offer a better baseline cost for their VMs, or larger instances for similar pricing.

If you really want to crush costs, then moving to bare-metal is a great option - it can enable much more density at a lower cost per function. Bare-metal doesn't have to mean buying a datacenter, or installing OpenStack on a few racks.

Providers such as [Hetzner](https://www.hetzner.com/) offer ridiculous value in comparison to AWS:

For x86_64:
* EX44 (52 USD / mo ) - 20 vCPU, 64GB RAM, 2x 512 NVMe SSD
* A102 (139 USD / mo) - 32vCPU, 128GB RAM, 2x 1.92TB NVMe SSD
* AX162-R (256 USD / mo) - 96 vCPU, 256GB RAM, 2x 1.92TB NVMe SSD

For ARM:
* RX220 (292 USD / mo) - 80 vCPU, 256GB RAM, 2x 3.84 TB NVMe SSD

| Provider   | Instance / host | Storage | vCPU | RAM | Monthly cost | Notes |
|------------|-----------------|---------|------|-----|--------------|---------|
| AWS        | m5.4xlarge      | EBS     | 16   | 64GB| ~$300        | EBS is much slower than a local NVMe. Bandwidth costs extra. CPU is slower. |
| Hetzner    | EX44            | NVMe  | 20 | 64GB | $52 | Fast local NVMe, bare-metal density. Bandwidth is unmetered and included in cost. |

Now once you have that bare-metal that may be capable of running well over 100 Pods, you're still going to be limited by the default limit of Kubernetes of 100 Pods per node.

The solution is to use a lightweight Firecracker microVM and we have a well supported solution that works with OpenFaaS and Kubernetes.

Using [SlicerVM.com](https://slicervm.com), you can densely pack in as many nodes as you can fit by slicing up each server, and installing Highly Available Kubernetes using [K3sup](https://k3sup.dev/), or a similar Kubernetes distribution of your choice. SlicerVM.com can run over multiple machines, so you can retain high-availability without introducing a single point of failure.

Slicer can also autoscale Kubernetes nodes, meaning you can recycle them instead of having to manage them like pets. That means no need to worry about OS patching and updates.

Hetzner's prices are remarkable, but [other companies](https://docs.actuated.com/provision-server/) offer bare-metal in the cloud too.

What if you simply cannot move off AWS? You're half way through a SOC II audit, and can't take on any new vendors? Perhaps do some initial research and experimentation, so that when you are in a position to review costs, you can make an accurate comparison.

Here's how quick and easy it is to setup HA Kubernetes with SlicerVM

{% include youtube.html id="YMPyNrYEVLA" %}

[Click here to view the documentation](https://docs.slicervm.com/examples/ha-k3s/).

## Wrapping up

Most OpenFaaS customers enable a few sane defaults and largely don't mention the cost of their hosting provider. Why? I think typically, the below is well understood by many customers. Maybe there's something new below that could help you and your team? Maybe there's something we didn't mention, reach out and let us know!

From the top:

* Do consider Arm and Graviton for a clear cost reduction and performance increase.
* Do use autoscaling nodes with something like Karpenter or an AWS-managed nodepool.
* Do consider whether spot instances can fit into your workflow.
* Do enable scale to zero where a modest coldstart is acceptable, or where functions run mainly asynchronously.
* Don't overprovision CPU/RAM just because that's what you had for a cloud function in the past.

We realise that many teams have made a firm committment to stay on AWS and cannot consider another vendor, or self-hosting. But, if you can, do consider bare-metal, or on-premises infrastructure. Maybe you could run part of your product on a different cloud provider, if it meant getting the 5-6x cost reductions we outlined in the example with Hetzner?

Finally, if you are in need of help, reach out to us using your existing communication channels with us. Or if you're new here via our [Pricing page](https://www.openfaas.com/pricing/).

Related links:

* [On Autoscaling - What Goes Up Must Come Down](https://www.openfaas.com/blog/what-goes-up-must-come-down/)
* [Save costs on AWS EKS with OpenFaaS and Karpenter](https://www.openfaas.com/blog/eks-openfaas-karpenter/)
* [Scale to zero GPUs with OpenFaaS, Karpenter and AWS EKS](https://www.openfaas.com/blog/scale-to-zero-gpus/)
* [Scale Up Pods Faster in Kubernetes with Added Headroom](https://www.openfaas.com/blog/headroom-controller/)
