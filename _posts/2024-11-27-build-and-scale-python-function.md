---
title: How to Build and Scale Python Functions with OpenFaaS
description: Learn how to build, scale and monitor your first Python function with OpenFaaS, including how to add secrets and pip modules.
date: 2024-11-27
categories:
- functions
- python
- autoscaling
- pip
dark_background: true
image: /images/2024-11-build-scale-python/background.png
author_staff_member: alex
hide_header_image: true
---

In this quickstart, we'll guide you through how to build, scale and monitor your first Python function with OpenFaaS.

We'll do the following:

* Meet two official Python templates
* Build a function and test it locally
* Scale the function horizontally
* Scale the function to zero
* Monitor it during a load test
* Consume a secret and a pip module, to make authenticated API requests

According to Datadog's [State of Serverless report (2023)](https://www.datadoghq.com/state-of-serverless/), Node.js and Python remain the most popular choice for serverless functions on AWS Lambda, with Python coming in at a close second to JavaScript/Typescript. With Python also being the de-factor language for interacting with AI and LLMs, we may see Python shifting into the top spot in the coming years.

Many users like the convenience that a serverless platform offers, whether run as a managed cloud service, or self-hosted on Kubernetes or [an IoT/edge device](https://www.openfaas.com/blog/meet-openfaas-edge/), like with OpenFaaS.

On a recent call with developers at a large travel company, they said they were considering OpenFaaS as a way to ship changes to their product without affecting its core, this is a similar mindset to a microservices architecture. However, microservices require a lot of boiler-plate code, and create operational overhead, which is where OpenFaaS can simplify managing, scaling, and monitoring code as functions.

Unlike cloud solutions, the basic workload for an OpenFaaS function is not a zip file, but a Open Container Initiative (OCI) image. This means that you can use any language, framework or tooling that can produce a Docker image, with a HTTP server listening on port 8080. Container images can be built quickly and easily with CI/CD platforms like [GitHub Actions](https://docs.actuated.com/examples/openfaas-publish/) or [GitLab CI](https://docs.openfaas.com/reference/cicd/gitlab/).

## Introducing the official Python templates

We've had a few variations of Python templates over the years since the first one in 2017, and even today, we still have two choices that make sense for most users, rather than one that does everything.

Both templates use the same HTTP request/response style for their handler, and "pip" along with a requirements.txt file to manage dependencies.

* `python3-http` - based upon Alpine Linux, for the absolute smallest image size and fastest start-up time - use it with pure Python modules only.
* `python3-http-debian` - the same as the above, but it uses a Debian base image, which is more compatible with some Python modules that require native dependencies.

Some people ask why you wouldn't use the Alpine image, then add a build toolchain back in, the answer is that: it's slower at build time, results in a much bigger image at runtime, and uses non-standard musl libc, instead of glibc, which is what most native modules expect.

Here's the basic handler:

```python
def handle(event, context):
    return {
        "statusCode": 200,
        "body": "Hello from OpenFaaS!",
        "headers": {"Content-Type": "text/plain"}
    }
```

As you can see, the minimal example handler takes in an event, and context which contain everything you could ever need to know about the HTTP request, then returns a dictionary with a status code, body and headers.

Any Dockerfile, dependency management, HTTP server, and other details are all abstracted way into the template. You can fork and modify the template if you wish, but most customers will use it as is.

There are more advanced options for working with a database, storing state between requests, and making use of private pip repositories, these are [all detailed in the documentation](https://docs.openfaas.com/languages/python/).

## Building a new function

First of all, we need to fetch the Python templates from GitHub, then we will scaffold a new function called "hello":

```sh
faas-cli template store pull python3-http
```

This command brings down both variations.

Next, set your container registry in the `OPENFAAS_PREFIX` environment variable, and then scaffold a new function.

If you haven't chosen a registry such as the Docker Hub, ECR, or GCR, etc yet, then you can use `ttl.sh` instead for a public image, that will be deleted after 24 hours. ttl.sh is likely to be slower than a production registry, but it's a good way to get started.


```sh
export OPENFAAS_PREFIX="ttl.sh/alexellis"

faas-cli new --lang python3-http hello
```

This will create:

```
./hello
./hello/tox.ini
./hello/handler_test.py
./hello/requirements.txt
./hello/handler.py
./stack.yaml
```

Multiple functions can be added to the same stack YAML file by passing the `--append` flag to `faas-cli new`.


Now there's a way to test the function without even deploying it, so long as it doesn't try to access the network of the Kubernetes cluster.

```sh
faas-cli local-run --tag=digest --watch
```

You'll be able to invoke the function using the URL you were given in the output.

When you're ready, you can publish the image to the remote registry, and deploy it to your OpenFaaS cluster.

```sh
faas-cli up
```

Next, you can use `faas-cli list` to view the deployed function, and `faas-cli describe hello` to see the URL and other details.

```bash
# faas-cli describe hello

Name:               hello
Status:             Ready
Replicas:           1
Available Replicas: 1
Invocations:        1
Image:              ttl.sh/alexellis/hello:latest
Function Process:   python index.py
URL:                http://127.0.0.1:8080/function/hello
Async URL:          http://127.0.0.1:8080/async-function/hello
Usage:
  RAM:  24.00 MB
  CPU:  5 Mi
```

One of the key things we are looking for is that the Status says "Ready", then we know the function is ready to be invoked using its URL.

## Scaling the function

There are some default parameters for scaling functions, which do not require any labels or additional configuration.

The defaults are: 50 Requests Per Second, minimum replicas of 1, maximum replicas of 20, all of these settings can be altered by changing the labels on the function.

Roughly speaking, if a function receives 100 requests per second, two replicas will be created, if it receives 200 requests per second, four replicas will be created, and so forth.

Each OpenFaaS Function can handle dozens, hundreds, if not thousands of requests per second, so unlike a product like AWS Lambda, each replica is not tied to one ongoing request.

You can tune the way functions scale using CPU, RAM, concurrent requests, RPS, or custom metrics in Prometheus.

Not all functions are alike, so you will need to test out an tune the parameters for each, once they start getting heavier load.

See also: [Autoscaling docs](https://docs.openfaas.com/architecture/autoscaling/)

There are sophisticated ways to run load tests on functions using tools like [Grafana k6.io](https://k6s.io) to generate realistic user traffic, but for now, we can use `hey` which is a simple HTTP load generator.

First, install `hey`:

```sh
curl -sLS https://get.arkade.dev | sudo sh
arkade get hey
```

Then run the following command to generate 10 concurrent requests for a period of 5 minutes, not exceeding 100 QPS per concurrent worker:

```sh
hey -c 10 -z 5m -q 100 http://127.0.0.1:8080/function/hello
```

In another window, you can run the following to see the number of replicas that are running:

```sh
kubectl get function/hello -n openfaas-fn -o wide --watch

NAME    IMAGE                           READY   HEALTHY   REPLICAS   AVAILABLE   UNAVAILABLE
hello   ttl.sh/alexellis/hello:latest   True    True      1          1           
hello   ttl.sh/alexellis/hello:latest   True    True      2          2           
hello   ttl.sh/alexellis/hello:latest   True    True      3          3           
...
```

And so forth. OpenFaaS functions use a Kubernetes Deployment object, and Pods, so you can also see those objects if you're interested:

```bash
kubectl get deploy/hello -n openfaas-fn -o wide

kubectl get pod -n openfaas-fn  -l faas_function=hello -o wide
```

Once the load test has completed, you will see the amount of replicas drop off back to the minimum of 1.

## Scaling to zero

If you open the [OpenFaaS Dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/), you'll see the following mid-test:

![](/images/2024-11-build-scale-python/dashboard-stats.png)

Next, if you click on the Task "Configure scale to zero", you'll get the labels you can copy and paste into your stack.yaml to turn it on for this function.

To enable scale to zero, we need to add a couple of labels to the function's YAML file. Here's an example:

```diff
functions:
  hello:
+    labels:
+      com.openfaas.scale.zero: true
+      com.openfaas.scale.zero-duration: 5m
```

Now, you can run `faas-cli up` again to apply the changes.

Leave the function idle for 5 minutes, and watch the following, you'll see it go to "0" under REPLICAS:

```sh
kubectl get function/hello -n openfaas-fn -o wide --watch
```

The dashboard will also show the function as 0/0 replicas.

Next, you can scale back up by invoking the function via the Invoke button on the dashboard, or via curl.

You can learn more about scaling to zero in the docs: [Scale-to-zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)

## Monitoring the function

OpenFaaS has very [detailed Prometheus metrics built into all its components](https://docs.openfaas.com/architecture/metrics/).

Rather than understanding each of these up front, you can deploy our [official Grafana dashboards](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/) to a self-hosted Grafana instance, or a managed Grafana instance on Grafana Cloud.

The overview page shows all the functions in your cluster, and their invocation rate, latency, and error rate.

![Overview dashboard](https://docs.openfaas.com/images/grafana/overview-dashboard.png)

On this page you can ask questions such as:

* Is this function scaling too quickly or too slowly?
* Are any requests erroring?
* Is RAM being recovered when idle, or is there a memory leak?
* Are there any functions that are mainly idle, but could be set to scale to zero?
* Are request durations increasing beyond acceptable levels?
* Do we need to alter the RAM/vCPU allocated to any particular function?

The "spotlight" version has a drop-down that you can use to dial into a specific function without the noise of the rest of the system getting in the way.

## Add a pip module and consume a secret

There are various examples in the documentation on [how to work with SQL](https://docs.openfaas.com/languages/python/#example-with-postgresql), which we don't need to repeat here, so let's add a simple pip module to show you how it's done.

Let's use a module that can interact with GitHub's API, and fetch the number of stars for a repository that we read from the HTTP request.

```bash
faas-cli new --lang python3-http-debian github-stars
```

First, add the module to `github-stars/requirements.txt`:

```diff
+ PyGithub
```

Create a [Personal Access Token on GitHub](https://github.com/settings/tokens), and save it as "token.txt", then create an OpenFaaS secret for the function:

```sh
faas-cli secret create github-token --from-file=token.txt
```

Now, you can modify the handler to fetch the number of stars for a repository.

Edit `github-stars/handler.py`:

```python
import os
import json
from github import Github
from github import Auth

def read_secret(name):
    with open(f"/var/openfaas/secrets/{name}") as f:
        return f.read().strip()

def handle(event, context):

    body = event.body
    if not body:
        return {
            "statusCode": 400,
            "body": "Missing body",
            "headers": {"Content-Type": "text/plain"}
        }

    bodyJson = json.loads(body)

    repo = bodyJson.get("repo")

    token = read_secret("github-token")

    auth = Auth.Token(token)
    g = Github(auth=auth)
    r = g.get_repo(repo)
    g.close()

    return {
        "statusCode": 200,
        "body": f"{repo} has {r.stargazers_count} stars",
        "headers": {"Content-Type": "text/plain"}
    }

```

Now update stack.yaml to include the secret:

```diff
functions:
  hello:
+    secrets:
+      - github-token
```

Deploy the function and try it out:

```sh
faas-cli up
```

If you use the `--append` flag to have your two functions in the same file, you can make development more efficient by passing in the `--filter github-stars` flag to have the commands only work on a single function.

```sh
curl -H "Content-type: application/json" -d '{"repo": "openfaas/faas"}' http://127.0.0.1:8080/function/github-stars

openfaas/faas has 25209 stars
```

## Watch me walk through these steps

I recorded a video walking through most of the steps you find in this blog post, you can watch it back to see it live and if you're having any problems, perhaps find out what you may be doing differently.

{% include youtube.html id="igv9LRPzZbE" %}

## Wrapping up

In this blog post we walked through how to build, scale, and monitor a Python function with OpenFaaS. That included autoscaling in response to a basic load test with the hey load-generation tool, saclign to zero after a period of inactivity, and monitoring with the OpenFaaS Dashboard and Grafana.

We then went ahead and added a secret to a function and accessed GitHub's API using a custom Pip module to fetch the number of stars for a repository.

You can find out more about what we covered in the documentation:

* [Scale to zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)
* [Autoscaling](https://docs.openfaas.com/architecture/autoscaling/)
* [Metrics](https://docs.openfaas.com/architecture/metrics/)
* [Grafana dashboards](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/)
* [Python templates](https://docs.openfaas.com/languages/python/)
