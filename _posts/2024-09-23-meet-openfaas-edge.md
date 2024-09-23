---
title: Introducing OpenFaaS Edge
description: OpenFaaS Edge is a commercial distribution of faasd fuse together with OpenFaaS Pro, for commercial use, with support and new features. 
date: 2024-09-23
categories:
- edge
- industrial
- iot
- redistribution
- arm
dark_background: true
image: /images/2024-09-openfaas-edge/background.png
author_staff_member: alex
hide_header_image: true
---

Meet OpenFaaS Edge, a commercial distribution of faasd fused together with OpenFaaS Pro, for commercial use, with support and new features.

![faasd logo](/images/2024-09-openfaas-edge/faasd.png)

If you've not yet heard of [faasd](https://github.com/openfaas/faasd), it was created in 2020 as an antidote to the complexity, cost, and rate of change of Kubernetes. Its founding goals were to be lightweight, fast, simple to operate, and to rarely have a reason to change.

We heard from users who were still using docker-compose in production to avoid the Kubernetes tax. Compose is well known for running stateful services, and for making it easy to get started.

With faasd, we wanted to combine stateful services, with persistent volume mounts like Postgresql, Grafana, InfluxDB, Redis, Minio, and MongoDB, and to have them run directly next to your functions, without having to stray far from the familiar Docker Compose YAML syntax.

Details of how to add additional stateful services are available in my eBook [Serverless For Everyone Else](https://store.openfaas.com/l/serverless-for-everyone-else?layout=profile).

Instead of Docker, or even compose, faasd was built from the ground up to integrate directly with systemd for deployment, containerd as a compute runtime, and the Container Networking Interface (CNI) for networking. This means that it can run on a wide range of Linux distributions, and on a variety of platforms, including Intel/AMD and Arm, whilst retaining the simplicity of containers.

## What is OpenFaaS Edge and faasd CE?

faasd CE is the original version of faasd, it's free to use under the [faasd CE EULA](https://github.com/openfaas/faasd/blob/master/pro/EULA.md) for personal use and within a Small Business Environment, with up to 15 functions, but it doesn't come with support, and is limited to the same set of features and capabilities of OpenFaaS CE on Kubernetes.

## New features from OpenFaaS Pro

OpenFaaS Edge comes with support, plus new features from OpenFaaS Pro:

* Upgraded Pro components from OpenFaaS Standard: Gateway, Cron Connector, JetStream Queue Worker and Classic Scale to Zero
* Deploy up to 250 functions per installation
* Configure private DNS servers
* Airgap-friendly with installation bundled in an OCI image
* Multiple namespace support

The upgraded components support structured logs in JSON format for better observability. We'll cover some of the new features below. 

## New installation experience

We redesigned the installation experience, so that rather than having all the prerequisites downloaded one by one from the Internet, a single OCI image bundles everything you need into one simple package.

The new experience makes OpenFaaS edge easier to install into an airgap, on-premises where you may not have access to the Internet, and into VM images to delivery to customers.

Both versions of faasd and their container images support the Intel/AMD and 64-Arm platforms. This means OpenFaaS Edge can be run on Linux on industrial and edge devices, as well as on traditional hypervisors, and bare-metal.

## Simple activation

For individual use, OpenFaaS Edge can be activated during installation with:

```bash
# Verify sponsorship status for @openfaas
faasd-pro github login

# Activate OpenFaaS Edge via API call
faasd-pro activate
```

For commercial redistribution, a HTTP REST API is available to activate installations using your API token.

This can be done during delivery to a customer, or on a self-service basis through your existing back-office or onboarding operations.

## Pre-configured for production

The docker-compose.yaml file that ships with OpenFaaS Edge has been pre-configured to use the additional OpenFaaS Pro components and with extended timeouts.

A popular request from commercial users was to be able to configure DNS servers, this is now available during installation or via the `faasd` and `faasd-provider` systemd unit file after installation.

Here's how you can switch from Google's default domain servers, over to a local network DNS Server, with Cloudflare serving as a backup:

```bash
faasd-pro install --dns-server 192.168.1.1 --dns-server 1.1.1.1
```

## Classic scale to zero

OpenFaaS Edge comes with the Classic experience for [Scale to Zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/), you can configure a single timeout for the installation, and any functions with the `com.openfaas.scale.zero` label will be scaled to zero after that timeout. OpenFaaS Standard, for Kubernetes adds further support to override the timeout of each function individually.

There will be a default value configured under `faas-idler` in your docker-compose.yaml file at: `/var/lib/faasd/docker-compose.yaml`, you can adjust it and then restart the faasd service.

```yaml
  faas-idler:
    image: "ghcr.io/openfaasltd/faas-idler:0.5.5"
    environment:
      # If a function is inactive for x minutes, it may be scaled to zero
      - "inactivity_duration=10m"
      # The interval between each attempt to scale functions to zero
      - "reconcile_interval=5m" 
```

Here's how it works:

```yaml
functions:
  import-customer-data:
    labels:
      com.openfaas.scale.zero: "true"
  jira-webhook-processor:
    labels:
      com.openfaas.scale.zero: "false"
```

In the above example, the `import-customer-data` function will be scaled to zero after the configured inactivity period, and the `jira-webhook-processor` function will remain running at all times with 1/1 replicas.

## JetStream Queue Worker

The [JetStream Queue Worker](https://docs.openfaas.com/openfaas-pro/jetstream/) replaced the original queue-worker in OpenFaaS CE when the Synadia team unfortunately deprecated their popular NATS Streaming Server project. The new queue worker is based on the JetStream feature of NATS, and is more performant, reliable, and allows for monitoring and better data retention.

By default, the new queue-worker will retry any failed invocations up to a configured number of times. You can configure the glboal setting for retries in the `docker-compose.yaml` file.

Retries are also configurable on a per function basis, and you can set a backoff period between each retry.

```yaml
functions:
  chaos:
    image: alexellis2/chaos-fn:0.1.1
    skip_build: true
    annotations:
      com.openfaas.retry.attempts: "30"
      com.openfaas.retry.codes: "429"
      com.openfaas.retry.min_wait: "5s"
      com.openfaas.retry.max_wait: "1m"
```

The above function will only be retried for a 429 status code, and will retry up to 30 times with a minimum wait of 5 seconds and a maximum wait of 1 minute between each retry.

See also: [Docs: JetStream Queue Worker](https://docs.openfaas.com/openfaas-pro/retries/)

## Example architecture

On a conceptual level, OpenFaaS Edge is designed to be bundled as part of a broader application or solution.

OpenFaaS Edge can run the whole application including any APIs, LLMs, or front-end UIs that may be required, or they can be run separately and integrate with the functions over HTTP.

Vendors write their own functions and store them in their own registry, then make them available for customers, or allow them to write their own.

![Conceptual architecture](/images/2024-09-openfaas-edge/redist-openfaas-edge.png)

Examples of where OpenFaaS Edge could be used include:

* Local processing of data from cameras, sensors, or other devices
* Inference with pre-built Machine Learning Models or Large Language Models (LLMs)
* Pre-processing or summarisation of data at the edge without incurring ingress/egress costs
* A local API or appliance for a customer to use locally, or connected to the cloud
* A local processing engine for a SaaS application

### Remote monitoring and support

Monitoring and support can be achieved using the OpenFaaS REST API, with a logging agent to forward logs from the systemd journal to a centralised logging system, and with Prometheus which contains detailed RAM/CPU usage metrics, and [HTTP invocation metrics from the OpenFaaS Pro gateway and JetStream Queue Worker](https://docs.openfaas.com/architecture/metrics/).

For remote access to the OpenFaaS REST API and Prometheus metrics, you can use a solution like our inlets uplink product, which does not require a VPN, firewall rule, or port forwarding. It makes an outbound TLS connection to your Kubernetes cluster. Your internal applications can then interact with the two HTTP endpoints as if they were local within the cluster.

![Inlets Uplink example](/images/2024-09-openfaas-edge/remote-management.png)

> Only services within your own Kubernetes cluster can access each tenant's tunnel. The tunnel can expose multiple HTTP and TCP services, such as Prometheus and OpenFaaS. If you run a Postgresql database via faasd, you could also expose that in the same way.

[Learn about inlets uplink](https://inlets.dev/blog/2022/11/16/service-provider-uplinks.html)

## Q&A

Q: Are there any limitations of OpenFaaS Edge over OpenFaaS Pro on Kubernetes?
A: Each function can have a maximum of 1 replica.

Q: Is scale to zero supported?
A: A classic experience of scale to zero is supported, with a single timeout for all functions.

Q: Can I use OpenFaaS Edge for commercial redistribution?
A: OpenFaaS Edge is designed for commercial redistribution, and can be activated via an API call. Send us an email for more information.

Q: How does pricing for OpenFaaS Edge compare to OpenFaaS Standard/for Enterprises?
A: OpenFaaS Edge is designed for edge distribution, and is available at a lower price point than OpenFaaS Standard/for Enterprises from OpenFaaS Ltd.

Q: Is the OpenFaaS Pro Dashboard included?
A: OpenFaaS Edge is designed for headless use, and for commercial redistribution as part of a white-box/OEM solution, so this user-facing component is not included at present.

Q: Can I use OpenFaaS Edge for individual use?
A: Yes, with a GitHub Sponsorship for OpenFaaS at the 25 USD / mo tier or higher. We have included this option for developers to explore the technology and to make use of the additional features in their own projects.

Q: Can I still use faasd CE at work for internal use?
A: If the environment qualifies as a Small Business Environment, then yes, however you may want to consider the benefits of OpenFaaS Edge.

Q: Is the Small Business Environment relevant for OpenFaaS Edge?
A: Apart from personal/individual usage, commercial usage of OpenFaaS Edge will require the purchase of a license from OpenFaaS Ltd.

Q: What level of support is included with OpenFaaS Edge?
A: OpenFaaS Edge comes with standard support via email.

## Get started with faasd

If you want to use faasd for Personal use, or [qualify as a Small Business Environment](https://github.com/openfaas/faasd/blob/master/pro/EULA.md), then you can [get started with faasd CE for free](https://github.com/openfaas/faasd) for up to 15 functions, including the use of private registries.

Individuals who [sponsor OpenFaaS via GitHub](https://github.com/sponsors/openfaas) on the 25 USD / mo tier or greater, can deploy the [full version of OpenFaaS Edge for personal use](https://github.com/openfaas/faasd).

For teams who want the additional flexibility of OpenFaaS Edge and commercial usage, reach out to us at [contact@openfaas.com](mailto:contact@openfaas.com) to learn more.
