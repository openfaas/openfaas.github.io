---
title: "Deploy your existing containers to OpenFaaS"
description: "Learn how to deploy existing containers to OpenFaaS alongside your functions"
date: 2023-06-26
categories:
- docker
- containers
- microservices
- migration
dark_background: true
author_staff_member: alex
image: /images/2023-06-existing-containers/background.png
hide_header_image: true
---

Learn how to deploy existing containers to OpenFaaS alongside your functions.

## Introduction

When you look under the hood at an OpenFaaS function, you'll find that it's represented by a Kubernetes Service and Deployment object. That's the same primitive that most Kubernetes users will be using to deploy just about anything they build to their cluster.

So if a function is just a Kubernetes Deployment, how easy is it to deploy an existing container to OpenFaaS?

```bash
faas-cli store deploy figlet

curl -d "openfaas" http://127.0.0.1:8080/function/figlet
                         __                 
  ___  _ __   ___ _ __  / _| __ _  __ _ ___ 
 / _ \| '_ \ / _ \ '_ \| |_ / _` |/ _` / __|
| (_) | |_) |  __/ | | |  _| (_| | (_| \__ \
 \___/| .__/ \___|_| |_|_|  \__,_|\__,_|___/
      |_|       

kubectl get -n openfaas-fn deploy/figlet svc/figlet 
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/figlet   1/1     1            1           24s

NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/figlet   ClusterIP   10.43.124.169   <none>        8080/TCP   24s
```

That's what we'll be answering in this short tutorial.

As with most things, there's a number of ways to get this done, and the work you put in, the more you'll be able to take advantage of the featureet of OpenFaaS.

* Deploy a pre-built container image to OpenFaaS via the CLI or a stack.yaml file
* Create a stack.yaml so that `faas-cli` can be used to publish and deploy the image
* Add the OpenFaaS watchdog to the image for extra compatibility
* Compare the above to a template-based function

I have a sample container built with Node.js and Express.js (alexellis/expressjs-k8s) which is available on [GitHub](https://github.com/alexellis/expressjs-k8s)

In the conclusion I'll be including lots of additional links for CI/CD, Scale to Zero, Autoscaling of functions, React Apps and Event-driven programming with AWS.

Here's what [Kevin Lindsay, Principal Engineer at Surge](https://www.linkedin.com/in/kevin-lindsay-16a740160/) had to say about running both containers an functions with OpenFaaS.

How do you use OpenFaaS at Surge?

> We've been using OpenFaaS as an abstraction layer for Kubernetes resources, and by extension we're using it for any and all main workload types that Kubernetes is designed to handle.

What separates OpenFaaS from other similar solutions?

> OpenFaaS means we can bring our own infrastructure and also scale our workloads down to zero to save on money and management, it's the most battle-hardened product of its kind in this space. OpenFaaS gives us all the tools we need to just build our applications, and keeps things at the proper abstraction level. For us - it does for applications what snowflake does for databases.

Can you explain one of your highest value use-cases?

> I'd say that one of our most complex workloads is a distributed dynamic ETL pipeline wherein every stage of the ETL process is a discrete function that can handle multiple jobs simultaneously. When all the jobs within a stage complete, the next stage can begin. It coordinates using a database for individual job status tracking, and doesn't run into a deadlock - which is technically very hard to achieve otherwise.

> OpenFaaS gives us the ability to have this entire process scale very quickly per stage, creating as many jobs as we require. We can burst out as arbitrarily high as we need with high auto-scaling precision and very low latency. Then, when everything is done, the entire pipeline scales to zero, and as far as we are concerned, our containers and functions are "just another few functions".

## Deploy a pre-built container image to OpenFaaS

If you already building and publishing a container, then you can deploy it to OpenFaaS using the CLI:

```bash
faas-cli deploy \
    --image alexellis2/service:0.4.1 \
    --name expressjs
```


You can also use a stack.yaml file to deploy the image, which is more succinct:

```yaml
provider:
  name: openfaas
functions:
    expressjs:
        image: alexellis2/service:0.4.1
        skip_build: true
```

Then run `faas-cli deploy` or `faas-cli deploy -f stack.yaml`

By default, OpenFaaS will configure Kubernetes to look for a readiness endpoint at: `/_/ready`, and if that's not present, you can add it to your container's code and publish a new version.

Alternatively, OpenFaaS Standard and Enterprise allow fine-grained tuning of readiness probes, and you can override it with an annotation:

```yaml
functions:
    expressjs:
        image: alexellis2/service:0.4.1
        skip_build: true
        annotations:
          com.openfaas.health.http.path: /ready
```

You can read more about tuning the probes here: [OpenFaaS Reference: Workloads](https://docs.openfaas.com/reference/workloads/)

Just like with Kubernetes Pods, there are several ways to configure your function, and most of the time it will come down to either setting environment variables or using a number of secrets. ConfigMaps are not supported, however, you can use a secret instead which is the equivalent and has the benefit of being encrypted at rest when Kubernetes is appropriately configured.

If you need them, annotations, labels, environment variables and secrets can be added to the stack.yaml file as well.

Read the [stack.yaml reference guide here](https://docs.openfaas.com/reference/yaml/)

This is what it looks like if you enable scale to zero, auto-scaling, Prometheus scraping, a custom environment variable and a secret:
```yaml
provider:
  name: openfaas
functions:
    expressjs:
        image: alexellis2/service:0.4.1
        skip_build: true
        labels:
            com.openfaas.scale.zero: true
        annotations:
            prometheus.io.scrape: "true"
            prometheus.io.port: "8080"
        environment:
            write_debug: true
        secrets:
        - my-secret
```

Secrets are always mounted under `/var/openfaas/secrets/` and should be read from there whenever they are needed. Secrets can be created via `faas-cli secret create` or `kubectl create secret generic`.

Did you know that you can even generate a Kubernetes Custom Resource from the stack.yaml file?

```bash
faas-cli generate > expressjs.yml
```

That'll give the following output, which can be applied via `kubectl apply`:

```yaml

---
apiVersion: openfaas.com/v1
kind: Function
metadata:
  name: expressjs
  namespace: openfaas-fn
spec:
  name: expressjs
  image: alexellis2/service:0.4.1
```

## Build your existing Dockerfiles with faas-cli

To build your existing Dockerfiles with faas-cli, structure the directory like this:

```bash
./stack.yaml
./expressjs/
./expressjs/Dockerfile
```

Then remove `skip_build: true` from the stack.yaml file and add `handler: ./expressjs` to the function definition.

```yaml
provider:
  name: openfaas
functions:
    expressjs:
        image: alexellis2/service:0.4.1
        handler: ./expressjs
```

Running `faas-cli build`, followed by `faas-cli push` or simply `faas-cli publish` will build and push the image to your registry.

There's a couple of shortcuts for auto-generating unique tags if you're using a git repository and have already done a commit:

* `faas-cli build --tag latest` - always change the tag to `latest`
* `faas-cli build --tag sha` - use the git SHA as the tag
* `faas-cli build --tag branch` - use the git branch as the tag
* `faas-cli build --tag describe` - use a mixture of the SHA and any tags as per `git describe`

When using CI, I tend to the available environment variables to generate a unique tag for each build instead:

```yaml
provider:
  name: openfaas
functions:
    expressjs:
        image: ${SERVER:-ghcr.io}/expressjs:${CI_COMMIT_SHORT_SHA:-latest}
        handler: ./expressjs
```

For GitLab CI:

* `CI_COMMIT_SHORT_SHA` i.e. `1ecfd275`
* `CI_COMMIT_SHA` - i.e. `1ecfd275763eff1d6b4844ea3168962458c9f27a`
* `CI_PROJECT_NAMESPACE` - i.e. `alexellis`
* `CI_PROJECT_NAME` - i.e. `expressjs-k8s`

[See more GitLab variables](https://docs.gitlab.com/ee/ci/variables/)

For GitHub Actions:

* `GITHUB_SHA` - i.e. `ffac537e6cbbf934b08745a378932722df287a53`
* `GITHUB_REPOSITORY_OWNER` - i.e. `alexellis`
* `GITHUB_REPOSITORY` - i.e. `alexellis/expressjs-k8s`

[See more GitHub Actions variables](https://docs.github.com/en/actions/learn-github-actions/variables)

## Add the OpenFaaS watchdog to your container

This is an optional step, but does bring some benefits:

* Concurrency limiting middleware
* Management of SIGTERM and SIGINT signals
* Readiness and Health checks
* Logging of requests and handling of STDIO
* Future work around JWT-based authorization

Take any existing Dockerfile:

```diff
+FROM --platform=${TARGETPLATFORM:-linux/amd64} ghcr.io/openfaas/of-watchdog:0.9.11 as watchdog

FROM --platform=${TARGETPLATFORM:-linux/amd64} node:17-alpine as ship

+COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
+RUN chmod +x /usr/bin/fwatchdog


ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG TARGETOS
ARG TARGETARCH

RUN addgroup -S app && \
    adduser -S -g app app && \
    apk --no-cache add ca-certificates

ENV NPM_CONFIG_LOGLEVEL warn
 
RUN mkdir -p /home/app

WORKDIR /home/app
COPY package.json ./

RUN npm i

COPY index.js ./
COPY routes routes

WORKDIR /home/app/

USER app

+ENV fprocess="node index.js"
+ENV mode="http"
+ENV upstream_url="http://127.0.0.1:3000"

-CMD ["node", "index.js"]
+CMD ["fwatchdog"]
```

## What if your container doesn't have a web server?

If your container doesn't have a web server, then you can use the Classic Watchdog to turn it into a HTTP server.

I've seen people run Terraform, ffmpeg and vulnerability scanners as functions.

For a number of quick examples, check out the [function store images](https://github.com/openfaas/store-functions) which include curl, hey, nslookup, nmap, youtube-dl amongst others.

See also:

* [Turn Any CLI into a Function with OpenFaaS](https://blog.alexellis.io/cli-functions-with-openfaas/)
* [Stop installing CLI tools on your build server — CLI-as-a-Function with OpenFaaS](https://medium.com/@burtonr/stop-installing-cli-tools-on-your-build-server-cli-as-a-function-with-openfaas-80dd8d6be611)

## Create a function from a template

There are a number of official templates and community-maintained templates available that accelerate how quickly you can build and deploy a function.

My favourite right now would be the [golang-middleware](https://github.com/openfaas/golang-http-template) template [which I cover in my eBook on OpenFaS and Go](https://store.openfaas.com/l/everyday-golang).

See all available templates:

```bash
faas-cli template store list
```

Create a function from a template using the ephemeral container registry [ttl.sh](https://ttl.sh):

```bash
faas-cli template store pull golang-middleware

export OPENFAAS_PREFIX=ttl.sh

faas-cli new --lang golang-middleware gofn
```

You'll find the following:


* `./gofn.yml` - this is your stack.yaml file
* `./gofn/handler.go` - this is your function's code
* `./gofn/go.mod` - specify any dependencies here

I met with [Patrick Stephens](https://www.linkedin.com/in/patrickjkstephens/) this morning. He works at [Calyptia](https://calyptia.com/) which is the main vendor behind Fluent Bit. His team wanted to migrate Go code from Google Cloud Run to a managed Kubernetes cluster for more control. OpenFaaS was one of the options he was considering due to its ease of use.

His team runs a Lua sandbox, so I wrote a basic function which would take Lua code via stdin and then execute it and print the output.

```go
import (
	"io"
	"net/http"
	"os"

	lua "github.com/Shopify/go-lua"
)

func Handle(w http.ResponseWriter, r *http.Request) {

	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		input = body
	}

	rPipe, wPipe, _ := os.Pipe()
	orig := os.Stdout
	defer func() {
		os.Stdout = orig

	}()

	os.Stdout = wPipe

	l := lua.NewState()
	lua.OpenLibraries(l)
	if err := lua.DoString(l, string(input)); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	wPipe.Close()
	output, _ := io.ReadAll(rPipe)
	rPipe.Close()

	w.WriteHeader(http.StatusOK)
	w.Write(output)
}
```

By redirecting `os.Stdout` to a pipe, we can capture the output printed from the Lua code and return it to the caller via the HTTP body.

Contents of `go.mod`:

```
module handler/function

go 1.20

require github.com/Shopify/go-lua v0.0.0-20221004153744-91867de107cf // indirect
```

Invoking the function gave logs like this:

```
curl http://127.0.0.1:8080/function/patrick1 -d 'print("hi")'

2023-06-26T14:37:41Z 2023/06/26 14:37:41 POST / - 202 Accepted - ContentLength: 0B (0.0027s)
```

When using an invalid Lua script as the input, we see the expected HTTP error returned via the function's handler:

```bash
curl -i http://127.0.0.1:8080/function/
patrick1 -d 'prints("hi")'
HTTP/1.1 500 Internal Server Error
Content-Length: 70
Content-Type: text/plain; charset=utf-8
Date: Tue, 27 Jun 2023 09:35:23 GMT
X-Call-Id: fa909235-8032-4870-93b9-edf7e8b1cf9d
X-Content-Type-Options: nosniff
X-Duration-Seconds: 0.000939
X-Start-Time: 1687858523767283659

runtime error: [string "prints("hi")"]:1: attempt to call a nil value
```

## Wrapping up

We've taken a brief tour of what's needed to deploy an existing container image using `faas-cli`, we then explored how to use the same CLI to build and publish new versions. We saw how to add the OpenFaaS watchdog to an existing Dockerfile for greater compatibility, and finally we saw how to create a new function from a template.

There are many more ways to deploy and update functions like:

* [Actuated docs: Publishing a function from GitHub Actions](https://docs.actuated.dev/examples/openfaas-publish/)
* [Image Update for Functions with ArgoCD](https://www.openfaas.com/blog/argocd-image-updater-for-functions/)
* [How to package OpenFaaS functions with Helm](https://www.openfaas.com/blog/howto-package-functions-with-helm/)
* [Hosting a React App with OpenFaaS](https://www.openfaas.com/blog/react-app/)

Then you can take advantage of the broader features of OpenFaaS and event-driven programming:

* [Scale to zero to save on costs](https://www.openfaas.com/blog/fine-tuning-the-cold-start/)
* [Rethinking Auto-scaling for OpenFaaS](https://www.openfaas.com/blog/autoscaling-functions/)
* [How to integrate OpenFaaS functions with managed AWS services](https://www.openfaas.com/blog/integrate-openfaas-with-managed-aws-services/)
* [The Next Generation of Queuing: JetStream for OpenFaaS](https://www.openfaas.com/blog/jetstream-for-openfaas/)
* [Learn how to access the Kubernetes API from a Function](https://www.openfaas.com/blog/access-kubernetes-from-a-function/)

If you would like to talk to us about OpenFaaS for your team, [you can get in touch via this form](https://openfaas.com/pricing/).
