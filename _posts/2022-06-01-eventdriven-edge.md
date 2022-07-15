---
title: "The Event-Driven Edge with OpenFaaS"
description: "Learn how OpenFaaS can be used to deploy event-driven functions at the edge"
date: 2022-06-01
image: /images/2022-06-eventdriven-edge/pi.jpg
categories:
  - edge
  - faasd
  - eventdriven
  - kafka
author_staff_member: han
author_staff_member_editor: alex
---

Learn how OpenFaaS can be used to deploy event-driven functions at the edge.

## OpenFaaS at the edge

OpenFaaS is well known for being able to run on commodity hardware like homelabs, cloud VMs, and on IoT devices, but did you know that we designed a distribution specialised for the edge? 

If you've not heard of it yet, meet [faasd](https://github.com/openfaas/faasd). faasd ships with all the same Core Components that make up the [OpenFaaS Stack](https://docs.openfaas.com/architecture/stack/), but instead of using Kubernetes to deploy them - it uses containerd and CNI directly.

By removing clustering and multi-host networking, faasd can deploy the entire stack including its UI, REST API, Prometheus monitoring and queue-worker on a host with as little as 512MB total RAM. Alex showed us how in [First Impressions with the Raspberry Pi Zero 2 W](https://blog.alexellis.io/raspberry-pi-zero-2/)

Functions deployed to the Community Edition of OpenFaaS can be invoked synchronously or asynchronously through the use of a NATS queue. It also has support for scheduled invocations through the [cron-connector](https://docs.openfaas.com/reference/cron/). 

Whilst this is already a very versatile stack, [we built a set of new features](https://docs.openfaas.com/openfaas-pro/introduction/) to bring event-driven programming to OpenFaaS. This currently includes:

- An event-connector for Apache Kafka
- Triggers for AWS SQS
- Scale to Zero
- Retries for functions
- Single Sign-On with OIDC
- A new dashboard that includes metrics and logs

You can watch an overview of faasd and why we should think about scaling down more in this video from KubeCon:

{% include youtube.html id="ZnZJXI377ak" %}

Watch: [Meet faasd. Look Ma’ No Kubernetes! - Alex Ellis, OpenFaaS Ltd](https://www.youtube.com/watch?v=ZnZJXI377ak)

## OpenFaaS at the edge

You may be familiar with Alex's course: [Kubernetes at the Edge with K3s](https://www.classcentral.com/course/introduction-to-kubernetes-on-edge-with-k3s-40995) which explores the differences between K3s and upstream Kubernetes. K3s is after all, often called an "edge" distribution, but still consumes a significant amount of CPU at idle, and can take multiple seconds to load up a HTTP endpoint.

Whilst OpenFaaS usually talks to K3s or Kubernetes, faasd connects directly to containerd, this means you can get productive without learning how to deploy and operate Kubernetes. By shrinking things down, we get new possibilities for the edge like on IoT devices and in industrial or air gapped environments.

Any CLI or HTTP server that can be packaged in a container can be deployed to OpenFaaS, including bash and powershell. You can find some of the [community templates here](https://docs.openfaas.com/cli/templates/#templates).

What might you want to do at the edge?

- Run a batch job to collect data from other devices
- Act as a gateway to customer appliances
- Orchestrate updates or reboots to other hardware over HTTP
- Process command and control events from Apache Kafka or AWS SQS
- Run a web portal or API for local users, with low latency

## Going on tour

I'll now walk you through some of the features that we think make OpenFaaS even better suited to building your own event-driven edge.

The official guide to faasd is [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) which explains everything you need to know about setting it up with many examples written in Node.js

A common option for edge may be a Raspberry Pi, Nvidia Jetson Nano, an IoT gateway, or a Virtual Machine Hypervisor.

See also: [Deployment tutorials](https://github.com/openfaas/faasd#deployment-tutorials)

### Adding additional services to faasd

By default faasd runs a stack of services that make up the core of OpenFaaS. It uses a subset of directives from the [compose-spec](https://compose-spec.io/) to define these services in a docker-compose.yaml file. You can extend this file to deploy additional services.

The spec lets us define TCP ports, environment variables, custom users, along with files and volumes to mount into the container. These can be stateful like databases or a Grafana dashboard.

> The book, [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else), has a complete chapter on how to add additional services and containers to faasd. It includes examples for running Grafana, PotgresSQL, Influxdb and Redis.

An [OpenFaaS Pro license](https://www.openfaas.com/support/) is required to run the pro components. The license file will have to be created on the faasd host at `/var/lib/faasd/secrets/openfaas-license`. faasd will mount this file into the respective components container.

## The New UI dashboard

At the start of 2022, OpenFaaS released a new UI dashboard. The new dashboard offers you a nice visual way to discover deployed functions. It enables you to see the deployed functions per namespace and shows you the total invocation count and replica count of each function along with some other rich metadata.

![An overview of functions](/images/2022-06-eventdriven-edge/functions-overview.png)
> An overview of functions

By clicking on a function you can access a detailed view displaying the deployment data, runtime data and some metadata for that function. When deployed on Kubernetes the dashboard also displays a functions memory and cpu usage but these metrics are not available yet on faasd. The runtime section shows you the invocation metrics over a period of 1 or 24 hours. It is possible to access the logs of any function in the dashboard.

![Function detail, including metrics, logs and metadata about its deployment](/images/2022-06-eventdriven-edge/function-detail.png)
> Function detail page, including metrics, logs and meta-data about its deployment


To run the dashboard, edit `/var/lib/faasd/docker-compose.yaml` and add:

```yaml
dashboard:
    image: "ghcr.io/openfaasltd/openfaas-dashboard:0.0.8"
    environment:
      - "basic_auth=true"
      - "gateway_url=http://gateway:8080"
      - "secret_mount_path=/run/secrets/"
      - "base_href=/function/dashboard/"
      - "metrics_window=60m"
      - "prometheus_host=prometheus"
      - "prometheus_port=9090"
      - "jwt_mount_path=/run/secrets/"
      - "public_url=https://dashboard.example.com"
      - "port=8083"
    command:
      - "./server"
      - "-license-file=/run/secrets/openfaas-license"
    volumes:
      - type: bind
        source: ./secrets/openfaas-license
        target: /run/secrets/openfaas-license
      - type: bind
        source: ./secrets/key
        target: /run/secrets/key
      - type: bind
        source: ./secrets/key.pub
        target: /run/secrets/key.pub
      - type: bind
        source: ./secrets/basic-auth-password
        target: /run/secrets/basic-auth-password
      - type: bind
        source: ./secrets/basic-auth-user
        target: /run/secrets/basic-auth-user
    ports:
      - "127.0.0.1:8083:8083"
    user: "65534"
    depends_on:
      - gateway
      - prometheus
```

You'll also need to copy `openfaas-license` to `/var/lib/faasd/secrets/` and generate your `key` and `key.pub` file, [instructions are available in the docs](https://docs.openfaas.com/openfaas-pro/dashboard/).

## Scaling down to zero

Functions that are idle most of the time consume memory and CPU resources unnecessarily. This can be problematic on resource constrained devices. So to free up resources, these idle functions can be scaled down to zero replicas.

> Whilst the faas-idler is no longer used with Kubernetes, and is superseded by a new autoscaler, it is still useful for faasd. 

The faas-idler can be deployed to handle scaling functions to zero. If a function is idle for a predefined period, the faas-idler will make an API call to scale the function to zero replicas. The function is scaled back up to the minimum desired amount of replicas upon first use. On faasd this will be a maximum of 1 replica since it does not support multiple replicas at this time.

> Functions are not scaled to zero by default on OpenFaaS. You opt-in on a per function basis by setting the label `com.openfaas.scale.zero: true` on the function and the idle period is set globally for all functions.
> 
> Did you know? For Kubernetes, we wrote a [new autoscaler](https://docs.openfaas.com/architecture/autoscaling/) which now allow functions to have their own individual scale-down timeout.

![Logs from the faas-idler and gateway showing an idle function scaling up and back to zero after an invocation](/images/2022-06-eventdriven-edge/zero-scale.png)
> Logs from the faas-idler and gateway showing an idle function scaling up and back to zero after an invocation.

To deploy the faas-idler add the following config to your `docker-compose.yaml` file:

```yaml
faas-idler:
    image: "ghcr.io/openfaasltd/faas-idler:0.5.0"
    environment:
      - "gateway_url=http://gateway:8080"
      - "secret_mount_path=/run/secrets/"
      - "prometheus_host=prometheus"
      - "prometheus_port=9090"
      # If a function is inactive for x minutes, it may be scaled to zero
      - "inactivity_duration=3m" 
      # The interval between each attempt to scale functions to zero
      - "reconcile_interval=2m" 
      # Write additional debug information
      - "write_debug=false"
    command:
      - "/usr/bin/faas-idler"
      - "-license-file=/run/secrets/openfaas-license"
    volumes:
      - type: bind
        source: "./secrets/openfaas-license"
        target: "/run/secrets/openfaas-license"
      - type: bind
        source: ./secrets/basic-auth-password
        target: /run/secrets/basic-auth-password
      - type: bind
        source: ./secrets/basic-auth-user
        target: /run/secrets/basic-auth-user
    depends_on:
      - gateway
      - prometheus
    cap_add:
      - CAP_NET_RAW
```

One of the strengths of faasd compared to OpenFaaS on Kubernetes is its sub-second cold start time. On Kubernetes, scaling up from zero can take a couple of seconds. In comparison, faasd uses containerd directly, which significantly reduces this cold start period.

We can deploy the figlet function from the OpenFaaS store and add the required label.  
```
faas-cli store deploy figlet \
  --label com.openfaas.scale.zero=true
```

After leaving the function idle for the configured time period it will be scaled to zero replicas.

```
Function                        Invocations     Replicas
figlet                          1               0
nodeinfo                        0               1 
```

When we call the function after it was scaled down the container will be restarted and once it is ready the function will be called. This all happens in under 90ms including the round trip latency.

```
time curl http://127.0.0.1:8080/function/figlet -d "Scale"
 ____            _      
/ ___|  ___ __ _| | ___ 
\___ \ / __/ _` | |/ _ \
 ___) | (_| (_| | |  __/
|____/ \___\__,_|_|\___|
                        

real    0m0.085s
```

## Retrying requests

It is possible to limit the number of concurrent requests that your function can process. This can be useful when you are running memory intensive tasks and want to prevent overloading the function.

You can limit how many concurrent requests a function will accept by setting its `max_inflight` environment variable. When a function cannot accept any more connections it will return a HTTP status code 429. Handling retries for these requests can be a time consuming and tedious process, so the OpenFaaS Pro queue-worker handles this for us, with an exponential back-off algorithm.

You can configure which HTTP Status codes should be retried along with how many times in the queue-worker's deployment.

Alex wrote an in-depth piece on how this works on the blog:

See also: [How to process your data the resilient way with back pressure](https://www.openfaas.com/blog/limits-and-backpressure/)

![Logs form the queue worker showing retries with exponential back-off](/images/2022-06-eventdriven-edge/retries.png)
> Logs form the queue worker showing retries with exponential back-off

To run the pro queue-worker, edit `/var/lib/faasd/docker-compose.yaml` and replace the current queue-worker configuration:
```yaml
queue-worker:
  image: ghcr.io/openfaasltd/queue-worker:0.1.5
  environment:
    - faas_nats_address=nats
    - faas_nats_port=4222
    - gateway_invoke=true
    - faas_gateway_address=gateway
    - ack_wait=5m5s
    - max_inflight=1
    - write_debug=false
    - basic_auth=true
    - secret_mount_path=/run/secrets
    - max_retry_attempts=100
    - max_retry_wait=120s
    - initial_retry_wait=10s
    - retry_http_codes=429,502,500,504,408
    - print_request_body=false
    - print_response_body=false
  command:
    - "/worker"
    - "-license-file=/run/secrets/openfaas-license"
  volumes:
    # we assume cwd == /var/lib/faasd
    - type: bind
      source: ./secrets/basic-auth-password
      target: /run/secrets/basic-auth-password
    - type: bind
      source: ./secrets/basic-auth-user
      target: /run/secrets/basic-auth-user
    - type: bind
      source: "./secrets/openfaas-license"
      target: "/run/secrets/openfaas-license"
  cap_add:
    - CAP_NET_RAW
  depends_on:
    - nats
```

You can customise the various settings like: `retry_http_codes`, `max_retry_attempts` and `initial_retry_wait`.

## The Kafka Connector

OpenFaaS Pro includes multiple event connectors. They allow you to integrate with different event systems. Currently we have a connector for Kafka and AWS SQS next to several open-source connectors for [NATS](https://github.com/openfaas/nats-connector), [cron](https://github.com/openfaas/cron-connector) and [MQTT](https://github.com/openfaas/mqtt-connector). Our documentation on [triggers](https://docs.openfaas.com/reference/triggers/#add-your-own-event-source) has an overview of the different ways to trigger functions and how you can connect to other event sources.

The quickest way I found to try out the Kafka connector was by signing up for an account on [Confluent Cloud](https://www.confluent.io/confluent-cloud/). They offer a fully managed Kafka cluster that can be used for free during development.

Once you have your account setup we recommend you to run through their getting started tutorial. It will show you how to create a cluster, create a topic for your data and produce messages to that topic. The last step of the tutorial will show you how to set up their Datagen Source connector. It will generate mock data that we will process in a function.

> If you want to use the code snippets we provide without modification you will have to create a topic named `user.signup` and configure the Datagen Source connector to produce `Users` data to that topic. Make sure to save the api key and secret you create during the tutorial. We will need them later on.

![The getting started tutorial on Confluent Cloud](/images/2022-06-eventdriven-edge/confluent-cloud.png)
> The getting started tutorial on Confluent Cloud

### Configuring the connector

After you completed the tutorial and have your Kafka cluster setup, we can move on and configure the kafka-connector for faasd.

The kafka-connector will need to authenticate to your cluster. It will need to have access to the api key and secret you created earlier to do this. Save your API key to a file `/var/lib/faasd/secrets/broker-username` and the secret to `/var/lib/faasd/secrets/broker-password`. faasd will mount both files into the container running the kafka-connector. Makes sure you don't leave any whitespace or newlines in the file after creating them.

Edit `/var/lib/faasd/docker-compose.yaml` and add the configuration for the kafka-connector:
```yaml
kafka-connector:
    image: ghcr.io/openfaasltd/kafka-connector:0.6.1
    environment:
      - gateway_url=http://gateway:8080
      - topics=user.signup
      - print_response=true
      - print_response_body=true
      - print_request_body=false
      - asynchronous_invocation=false
      - basic_auth=true
      - secret_mount_path=/run/secrets
      - broker_host=pkc-5r697.europe-west1.gcp.confluent.cloud:9092
      - upstream_timeout=2m
      - rebuild_interval=30s
      - content_type=text/plain
      - group=faas-group-1
      - log_sessions=true
      - max_bytes=1048576
      - initial_offset=oldest
    command:
      - "/usr/bin/kafka-connector"
      - "-license-file=/run/secrets/openfaas-license"
      - "-username-file=/run/secrets/broker-username"
      - "-password-file=/run/secrets/broker-password"
      - "-tls"
    volumes:
      # we assume cwd == /var/lib/faasd
      - type: bind
        source: ./secrets/basic-auth-password
        target: /run/secrets/basic-auth-password
      - type: bind
        source: ./secrets/basic-auth-user
        target: /run/secrets/basic-auth-user
      - type: bind
        source: "./secrets/openfaas-license"
        target: "/run/secrets/openfaas-license"
      - type: bind
        source: "./secrets/broker-username"
        target: "/run/secrets/broker-username"
      - type: bind
        source: "./secrets/broker-password"
        target: "/run/secrets/broker-password"
    depends_on:
      - gateway
    cap_add:
      - CAP_NET_RAW
```

You will have to edit some environment variables. Set the `broker_host` to the url of your bootstrap server and configure the `topics` you want to subscribe to. If you created the same topic as we recommended in the previous section this should be `user.signup`, otherwise set it to whatever you named your topic while running through the Confluent Cloud tutorial.

### Consuming messages in a function

Now that we have both the cluster and the connector running we can deploy a function to start consuming messages from our topic.

We will create a new function using Python called user-fn. This function will parse the json data that is generated by the Datagen Source connector and published on the `user.signup` topic.

```
export OPENFAAS_URL=""
export DOCKER_USER=""

faas-cli new --lang python3 user-fn
```

Our function has some third party python dependencies that we will need to add to the requirements file.

Edit `./user-fn/requirements.txt` and add this line:
```
Jinja2
```

Now we can edit the function handler `./user-fn/handler.py`:

{% raw %} 
```python
from jinja2 import Template
import json
import sys

def handle(req):
    input = json.loads(req) 

    t = Template("User: {{id}} Time: {{time}} Gender: {{gender}}")
    res = t.render(id=input["userid"], time=input["registertime"], gender=input["gender"])
    return res 
```
{% endraw %} 

Before we deploy our function we will add an annotation for the `user.signup` topic so that the function is invoked for any message received.

Edit `./user-fn.yml`: 
```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  user-fn:
    annotations:
      topic: user.signup
    lang: python3
    handler: ./user-fn
    image: user-fn:latest
```

We can now build and deploy the function.

```
faas-cli up -f user-fn.yml
```

When you look at the function detail of the user-fn in the dashboard you should see that the function is being invoked successfully. The logs of the kafka-connector can also help to see if the function is consuming messages.

![Logs of the kafka connector that show messages being consumed by the user-fn function](/images/2022-06-eventdriven-edge/kafka-connector-logs.png)
> Logs of the kafka connector that show messages being consumed by the user-fn function.

![Dashboard view of user-fn showing a rising invocation count](/images/2022-06-eventdriven-edge/kafka-connector-dashboard.png)
> Dashboard view of user-fn showing a rising invocation count.

# Wrapping up

I wanted to show you that whether you pick [K3s](https://k3s.io/), [Kubernetes](https://kubernetes.io), or [faasd](https://github.com/openfaas/faasd), what we've built offers you the same experience and features.

We looked at some of the OpenFaaS Pro components and how they can be used at the edge with faasd. I showed you how to set up the kafka-connector on faasd and how to use functions to consume messages from Kafka topics. While [OpenFaaS Pro](https://www.openfaas.com/support/) comes with a lot of features you might want when running in production, the base version of faasd is a great way to get started. You can use it to deploy microservices, long-running tasks in the background with async functions or trigger functions from any kind of event. For more insights and tutorials on what you can do with faasd take a look at the following resources:

- [Video: Meet faasd. Look Ma’ No Kubernetes! - Alex Ellis, OpenFaaS Ltd](https://www.youtube.com/watch?v=ZnZJXI377ak)
- [Video: Exploring Serverless use-cases with David McKay (Rawkode) and Alex Ellis](https://www.youtube.com/watch?v=mzuXVuccaqI)
- [Build at the Edge with OpenFaaS and GitHub Actions](https://www.openfaas.com/blog/edge-actions/)
- [Build a Serverless appliance with faasd](https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/)

Using faasd to run OpenFaaS can be useful if you want to avoid the complexity of running and managing Kubernetes or when you just don't need clustering capabilities. However, running Kubernetes at the edge is now also a possibility with [K3s](https://k3s.io). Alex wrote a course for [The LinuxFoundation](https://www.linuxfoundation.org/) called [Introduction to Kubernetes on Edge with k3s](https://training.linuxfoundation.org/training/introduction-to-kubernetes-on-edge-with-k3s-lfs156x/).

![Raspberry Pi](/images/2022-06-eventdriven-edge/pi.jpg)

> Raspberry Pi board with [K3sup](https://k3sup.dev/) being used to set up a cluster

If you'd like to talk to us about anything we covered in this blog post: [feel free to reach out at](https://www.openfaas.com/support/)

We also run a [Weekly Office Hours call](https://docs.openfaas.com/community/) that you're welcome to join.

See also:

* [OpenFaaS Pro documentation](https://docs.openfaas.com/openfaas-pro/introduction/)
* [Comparison: OpenFaaS CE vs Pro](https://docs.openfaas.com/openfaas-pro/introduction/#comparison)
