---
title: "The Event-driven Edge with OpenFaaS"
description: "Learn how OpenFaaS can be used to deploy event-driven applications at the edge"
date: 2022-05-27
categories:
  - edge
  - faasd
  - configuration
  - kafka
author_staff_member: han
---

Learn how OpenFaaS can be used to deploy event-driven applications at the edge.


## What is faasd?
faasd is the lightweight option to run OpenFaaS. It does not require Kubernetes but uses containerd and runc instead. Beacause of this you can run faasd almost anywhere.

faasd comes with all the core components from the OpenFaaS stack. It has a REST management api and ui dashboard. It comes with a queue system built around NATS for asynchronous invocations and has built in Prometheus monitoring.

While this is already a strong set of features, if you are using faasd in production you might want to extend its feature set with some of the OpenFaaS Pro components. These features include:
- An extended UI dashboard
- Event connectors to trigger functions from Kafka or AWS SQS events
- Scale to zero
- Retries
- Single Sign-On

## Why faasd?
faasd uses containerd directly, this eliminates the need to learn and operate Kubernetes. Leaving out Kubernetes also has the advantage that faasd can be deployed on devices that have limited resources. This makes it ideal for use at the edge, on IoT devices and in industrial or airgapped environments.

faasd works well for the same kind of use-cases as OpenFaaS on Kubernetes. It gives you a universal API to deploy microservices or functions written in any language [using our templates or by creating your own](https://docs.openfaas.com/cli/templates/#templates). Some of these use-cases may include:

- An integration for a data-feed from third-parties.
- An API written in go, Python, Dot net Core, Node.js or any other language.
- Running batch jobs.
- Receiving webhooks.

## Getting started
The official guide to faasd, [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) is the best way to learn about faasd and OpenFaaS.

There are also some tutorials that show you how to deploy faasd on different platforms:

- [Deploy faasd to DigitalOcean with Terraform](https://www.openfaas.com/blog/faasd-tls-terraform/)
- [Deploy faasd to your laptop with Multipass](https://github.com/openfaas/faasd/blob/master/docs/MULTIPASS.md)

## Deploying additional services on faasd
By default faasd runs a stack of services that make up the core of OpenFaaS. It uses a subset of directives from the [compose-spec](https://compose-spec.io/) to define these services in a docker-compose.yaml file. You can extend this file to deploy additional services.

> The book, [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else), has a complete chapter on how to add additional services and containers to faasd. It includes examples for running Grafana, PotgresSQL, Influxdb and Redis.

In order to run the pro components, an [OpenFaaS Pro license](https://www.openfaas.com/support/) is required. This license file will have to be created on the faasd host at `/var/lib/faasd/secrets/openfaas-license`.

## The dashboard
OpenFaaS recently released a new UI Dashboard. The dashboard offers you a nice visual way to discover deployed functions. It enables you to see the deployed functions per namespace and shows you the total invocation count and replica count of each function along with some other rich metadata.

![An overview of functions](/images/2022-05-faasd-pro/functions-overview.png)
> An overview of functions

By clicking on a function you can access a detailed view displaying the deployment data, runtime data and some metadata for that function. When deployed on kubernetes the dashboard also displays a functions memory and cpu usage but these metrics are not available yet on faasd. The runtime section shows you the invocation metrics over a period of 1 or 24 hours. It is possible to access the logs of any function in the dashboard.

![Function detail, including metrics, logs and metadata about its deployment](/images/2022-05-faasd-pro/function-detail.png)
> Function detail page, including metrics, logs and metadate about its deployment


To run the dashboard, edit `/var/lib/faasd/docker-compose.yaml` and add:
```yaml
dashboard:
    image: "ghcr.io/openfaasltd/openfaas-dashboard:0.0.7"
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

## Scaling down to zero
Functions that are idle most of the time consume memory and cpu resources unnecessarily. This can be problematic on resource constrained devices. To free up resources, these idle functions can be scaled down to zero replicas. The faas-idler can be deployed to handle scaling functions to zero. If a function is idle for a pre defined period, the faas-idler will call the gateways scale-function endpoint and the function will be scaled down. The function is scaled back up to the minimum desired amount of replicas upon first use. On faasd this will be a maximum of 1 replica since it does not support horizontal scaling.

> Functions are not scaled to zero by default on OpenFaaS. It can be opted into on a per function basis by setting the label `com.openfaas.scale.zero=true` on the function.

![ Logs from the faas-idler and gateway showing an idle function scaling up and back to zero after an invocation](/images/2022-05-faasd-pro/zero-scale.png)
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

One of the strengths of faasd compared to OpenFaaS on Kubernetes is its sub-second cold start time. On Kubernetes scaling up from zero can take a couple of seconds. In comparison, faasd uses containerd directly, which significantly reduces this cold start period.

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

When we call the function after it was scaled down the container will be restarted and once it is ready the function will be called. This all happens in under 90ms indluding the round trip latency.

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
It is possible to limit the number of concurrent requests that your function can process. This can be useful when you are running memory intensive tasks and want to prevent overloading the function. Limiting requests can be done by setting `max_inflight` on the function. When a function cannot accept any more connections it will return a http status code 429. You could handle these types of errors by implementing your own retry mechanism which but that would probably be a time consuming and tedious process. OpenFaaS Pro offers an upgraded queue-worker that will retry messages a number of times using an exponential back-off algorithm. The pro queue-worker will retry messages a set number of times before dropping them. 

The queue-worker can be configured to retry requests for different http status codes. That way it is not only useful for retrying 429 codes but can also be used to retry failed requests to downstream APIs.

> Take a look at: [How to process your data the resilient way with back pressure](https://www.openfaas.com/blog/limits-and-backpressure/) for an in depth overview of this topic.

![Logs form the queue worker showing retries with exponential back-off](/images/2022-05-faasd-pro/retries.png)
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
    - max_retry_attempts=10
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

## The Kafka connector
OpenFaaS Pro includes multiple event connectors. They allow you to integrate with different event systems. Currently we have a connector for Kafka and AWS SQS next to several open-source connectors for [NATS](https://github.com/openfaas/nats-connector), [cron](https://github.com/openfaas/cron-connector) and [MQTT](https://github.com/openfaas/mqtt-connector).

The quickest way to try out the Kafka connector is by signing up for an account on [Confluent Cloud](https://www.confluent.io/confluent-cloud/). They offer a fully managed Kafka cluster and new signups receive free credits that they can spend to explore the service.

Once you have your account setup we recommend you to run through their getting started tutorial. It will show you how to create a cluster, create a topic for your data and produce messages to that topic. The last step of the tutorial will show you how to setup their Datagen Source connector. It will generate mock data that we will process in a function.

> If you want to use the code snippets we provide without modification you will have to create a topic named `user.signup` and configure the Datagen Source connector to produce `Users` data to that topic. Make sure to save the api key and secret you create during the tutorial. We will need them later on.

![The getting started tutorial on Confluent Cloud](/images/2022-05-faasd-pro/confluent-cloud.png)
> The getting started tutorial on Confluent Cloud


### Configuring the connector
After you completed the tutorial and have your kafka cluster setup, we can move on and configure the kafka-connector on faasd.

The kafka-connector will need to authenticate to your cluster. It will need to have access to the api key and secret you created earlier to do this. Save your api key to a file `/var/lib/faasd/secrets/broker-username` and the secret to `/var/lib/faasd/secrets/broker-password`. faasd will mount both files into the container running the kafka-connector.

Edit `/var/lib/faasd/docker-compose.yaml` and add the configuration for the kafka-connector:
```yaml
kafka-connector:
    image: ghcr.io/openfaasltd/kafka-connector:0.6.1
    environment:
      - gateway_url=http://gateway:8080
      - topics=faas-request
      - print_response=true
      - print_response_body=true
      - print_request_body=false
      - asynchronous_invocation=false
      - basic_auth=true
      - secret_mount_path=/run/secrets
      - broker_host=kf-kafka:9092
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

We will create a new pyhon3 function called user-fn. This function will parse the json data that is generated by the Datagen Source connector and published on the `user.signup` topic.
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

![Logs of the kafka connector that show messages being consumed by the user-fn function](/images/2022-05-faasd-pro/kafka-connector-logs.png)
> Logs of the kafka connector that show messages being consumed by the user-fn function.

![Dashboard view of user-fn showing a rising invocation count](/images/2022-05-faasd-pro/kafka-connector-dashboard.png)
> Dashboard view of user-fn showing a rising invocation count.


# Wrapping up
We looked at some of the OpenFaaS Pro components and how they can be used at the edge with faasd. I showed you how to setup the kafka-connector on faasd and how to use functions to consume messages from Kafka topics. While [OpenFaaS Pro](https://www.openfaas.com/support/) comes with a lot of features you might want when running in production, the base version of faasd is a great way to get started. You can use it to deploy microservices, run long running task in the background with async functions or trigger functions from any kind of event. For more insights and tutorials on what you can do with faasd take a look at the following resources:
- [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else)
- [Build at the Edge with OpenFaaS and GitHub Actions](https://www.openfaas.com/blog/edge-actions/)
- [Build a Serverless appliance with faasd](https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/)

Using faasd to run OpenFaaS can be useful if you want to avoid the complexity of running and managing Kubernetes or when you just don't need clustering capabilities. However, running Kubernetes at the edge is now also a possibility. [The LinuxFoundation](https://www.linuxfoundation.org/) even has a course: [Introduction to Kubernetes on Edge with k3s](https://training.linuxfoundation.org/training/introduction-to-kubernetes-on-edge-with-k3s-lfs156x/). OpenFaaS offers you the same experience and features, whether you choose to use Kubernetes with [K3s](https://k3s.io/) or [faasd](https://github.com/openfaas/faasd).

Running the [OpenFaaS Pro](https://www.openfaas.com/support/) components requires a license key. If you are already a pro customer you can go ahead an try out all the [OpenFaaS Pro](https://www.openfaas.com/support/) components on faasd. If your are new to OpenFaaS or OpenFaaS Pro you can always [reach out to talk to us](https://www.openfaas.com/support/).

Take a look at the documentation for a detailed overview of all the OpenFaaS Pro features:
  - [OpenFaaS Pro documentation](https://docs.openfaas.com/openfaas-pro/introduction/)
