---
title: "Simple Serverless with Golang Functions and Microservices"
description: In this post Alex will explore what a Serverless function and microservice look like in Golang with OpenFaaS. We'll see how the OpenFaaS templates abstract away boilerplate code and how to start building your own templates.
date: 2019-04-10
image: /images/golang-serverless/foundation.jpg
categories:
  - templates
  - golang
  - go
author_staff_member: alex
dark_background: true
---

In my [previous post](/blog/openfaas-cloudrun/) I demonstrated how the OpenFaaS CLI and build-templates can enable functions on any container orchestrator such as Kubernetes or Google Cloud Run. In today's post I will focus on how to deploy your Golang code to OpenFaaS either as a function or as a stateless microservice.

## What is serverless?

In 2016 I introduced [Functions as a Service (FaaS)](https://blog.alexellis.io/functions-as-a-service/) as a set of behaviours and properties:

Serverless & FaaS:

* tends involve invoking short-lived functions (Lambda has a default 1-sec timeout)
* does not publish TCP services - often accesses third-party services or resources
* tends to be ad-hoc/event-driven such as responding to webhooks
* should deal gracefully with spikes in traffic
* despite name, runs on servers backed by a fluid, non-deterministic infrastructure
* when working well makes the complex appear simple
* has several related concerns: infrastructure management, batching, access control, definitions, scaling & dependencies

Since then I went on to build out a more refined serverless contract for containers:

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">✅Has a simple HTTP contract on port 8080<br>✅Is packaged in containers<br>✅Runs functions OR microservices<br>✅Can use any 64-bit Linux binary or HTTP server<br>✅Auto-scales on QPS, even to zero<br>✅Started over 2.5 years ago 🤔<br><br>Name this <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> framework?</p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1115530479598473216?ref_src=twsrc%5Etfw">April 9, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

This community now has over 2.5 years of experience of working with end-users who are solving real problems with OpenFaaS. For some teams and businesses, rewriting an entire application just to fit into the constraints of a function is not worth the benefit of the cost.

See also: [end-user community](https://docs.openfaas.com/#users-of-openfaas)

Fortunately the [OpenFaaS workloads](https://docs.openfaas.com/reference/workloads/) contract means that you don't have to pick between a function or a microservice.

![](/images/stateless-microservices/venn.png)

See also: [Introducing Stateless microservices](https://www.openfaas.com/blog/stateless-microservices/)

## Tutorial

Here we'll show you how to build a function using two of the available templates and compare the differences. We'll then show you how to construct a microservice followed by how we could get the best of both worlds using a Golang middleware template.

I will be using the OpenFaaS CLI which is available via `brew install faas-cli`, [GitHub releases](https://github.com/openfaas/faas-cli/) or on Linux/Mac with:

```sh
 # use `sudo sh` to move to /usr/local/bin/
curl https://cli.openfaas.com | sh
```

### Golang Function template (classic)

The classic Golang template for OpenFaaS forks one process for every incoming request meaning that state is not retained between invocations. This is a similar model to cgi-bin and uses UNIX STDIO pipes to send the request to the function and to retrieve the response.

Before OpenFaaS had the concept of templates, every function or microservice had its own Dockerfile and entrypoint code. When this template was announced it greatly improved the developer-experience of both writing and maintaining code.

See also: [Build a Serverless Golang Function with OpenFaaS (2017)](https://blog.alexellis.io/serverless-golang-with-openfaas/)

```sh
$ faas-cli new --lang go classic-go

Function created in folder: classic-go
Stack file written: classic-go.yml

Notes:
You have created a new function which uses Golang 1.10.4
To include third-party dependencies, use a vendoring tool like dep:
dep documentation: https://github.com/golang/dep#installation
```

You'll get a handler which looks like this:

```golang
package function

import (
	"fmt"
)

// Handle a serverless request
func Handle(req []byte) string {
	return fmt.Sprintf("Hello, Go. You said: %s", string(req))
}
```

You don't need to manage a Dockerfile or worry about healthchecks or reading HTTP request and response objects. Your HTTP request headers are available via environment variables if required such as `Http_Path` and `Http_X_Custom_Header`

A YAML stack file is also generated for each function and can be used to build multiple functions in parallel, which adds value to the Docker toolchain.

*classic-go.yml*

```yaml
provider:
  name: openfaas

functions:
  classic-go:
    lang: go
    handler: ./classic-go
    image: classic-go:latest
```

To add additional functions to the YAML file just pass `--append classic-go.yml` to `faas-cli new`.

This original Go template is widely used and is maintained for backwards compatibility.

### Golang Function template (HTTP)

A newer template was developed to give full access and control to the underlying HTTP request and response. This template also moves from using STDIO to HTTP so that database connections can be persisted across invocations. It also allows data to be loaded into memory or cached between requests.

To use this template just pull it from the [template store](https://www.openfaas.com/blog/template-store/).

```sh
$ faas-cli template store pull golang-http
$ faas-cli new --lang golang-http http-go
```

You'll see a slightly different signature which makes the HTTP request and response available through an object instead of environment variables:

*handler.go*

```golang
package function

import (
	"fmt"
	"net/http"

	handler "github.com/openfaas/templates-sdk/go-http"
)

// Handle a function invocation
func Handle(req handler.Request) (handler.Response, error) {
	var err error

	message := fmt.Sprintf("Hello world, input was: %s", string(req.Body))

	return handler.Response{
		Body:       []byte(message),
		StatusCode: http.StatusOK,
	}, err
}
```

See also: [golang-http README](https://github.com/openfaas/golang-http-template) for examples of how to use a database connection and HTTP paths.

## Golang Microservice

### Existing Docker image

If you already have a Golang microservice then you can convert it to be built by the `faas-cli` tool-chain or simply add it to your function's YAML file.

The `skip_build` flag will allow the service to be deployed without the `faas-cli` trying to also build it for you. This method is also useful when consuming third-party functions.

```yaml
provider:
  name: openfaas

functions:
  customer-service:
    image: docker.io/org/customer-service:0.1.0
    skip_build: true
    labels:
      com.openfaas.scale.min: 1
      com.openfaas.scale.max: 10   
```

See also: [YAML stack file reference](https://docs.openfaas.com/reference/yaml/)

### New service using a Dockerfile

If you want to build your own Dockerfile and host your own HTTP server then you can do the following using the `dockerfile` template:

```sh
$ faas-cli new --lang dockerfile go-microservice
```

This will create `go-microservice.yml` and the folder `go-microservice`. Simply copy your Dockerfile and source code into the folder.

Let's look at how much code we'd need for a middleware handler, `Dockerfile` and `main.go` entrypoint.

```dockerfile
FROM golang:1.10.4-alpine3.8 as build

RUN mkdir -p /go/src/handler
WORKDIR /go/src/handler
COPY . .

RUN CGO_ENABLED=0 GOOS=linux \
    go build --ldflags "-s -w" -a -installsuffix cgo -o handler . && \
    go test $(go list ./... | grep -v /vendor/) -cover

FROM alpine:3.9
# Add non root user and certs
RUN apk --no-cache add ca-certificates \
    && addgroup -S app && adduser -S -g app app \
    && mkdir -p /home/app \
    && chown app /home/app

WORKDIR /home/app

COPY --from=build /go/src/handler/handler    .

RUN chown -R app /home/app

RUN touch /tmp/.lock #  Write a health check for OpenFaaS here or in the HTTP server start-up

USER app

CMD ["/home/app/handler"]
```

The middleware will simply inject a HTTP header of `X-Served-Date` with the date the request was processed.

```golang
package main

import (
	"fmt"
	"log"
	"net/http"
	"time"
)

func addServedHeader(w http.ResponseWriter, r *http.Request) {
	w.Header().Add("X-Served-Date", time.Now().String())
}

func makeRequestHandler(middleware http.HandlerFunc) func(http.ResponseWriter, *http.Request) {
	return func(w http.ResponseWriter, r *http.Request) {
		middleware(w, r)

		w.Write([]byte("OK"))
	}
}

func main() {
	s := &http.Server{
		Addr:           fmt.Sprintf(":%d", 8080),
		ReadTimeout:    3 * time.Second,
		WriteTimeout:   3 * time.Second,
		MaxHeaderBytes: 1 << 20, // Max header of 1MB
	}

	next := addServedHeader
	http.HandleFunc("/", makeRequestHandler(next))
	log.Fatal(s.ListenAndServe())
}
```

Now run `faas-cli up -f go-microservice.yml` and invoke the service:

```
$ curl -i http://127.0.0.1:8080/function/go-microservice ;echo
HTTP/1.1 200 OK
Content-Length: 2
Content-Type: text/plain; charset=utf-8
Date: Wed, 10 Apr 2019 15:08:46 GMT
X-Call-Id: 0b441f6e-8afa-4d82-80dd-48206b1e0e3e
X-Served-Date: 2019-04-10 15:08:46.215153582 +0000 UTC m=+21.331669185

OK
```

You'll now be able to invoke your function and see the additional header added. We got to build our own Dockerfile and use the Golang HTTP stdlib which is something you don't usually see in the world of FaaS frameworks.

### Golang middleware template

Now if that all felt a little excessive and repetitive to you, then don't worry because you're not the only one. Imagine what that would look like with several dozen of those services? Now what if you need to fine-tune the code in one of the Dockerfiles or update a component?

Fortunately the community came up with a third solution which combines the best parts of the Golang HTTP stdlib and OpenFaaS templates. Let's look at the example above using the `golang-middleware` template.

```
$ faas-cli template store pull golang-middleware
$ faas-cli new --lang golang-middleware go-middle
```

*handler.go*

```golang
package function

import (
	"fmt"
	"io/ioutil"
	"net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := ioutil.ReadAll(r.Body)

		input = body
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Hello world, input was: %s", string(input))))
}
```

This is the standard example with further examples on the README for the `golang-http` template linked above.

```golang
package function

import (
	"net/http"
	"time"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	w.Header().Add("X-Served-Date", time.Now().String())
	w.Write([]byte("OK"))
}
```

Now you can run `faas-cli up -f go-middle.yml` and test the new endpoint. You'll see that it's functionally equivalent but the maintenance of dozens of similar functions will be trivial compared to tending to boilerplate code.

Here's the equivalent result like we saw above from our microservice which included a `Dockerfile`.

```
$ curl -i http://127.0.0.1:8080/function/go-middle ;echo
HTTP/1.1 200 OK
Content-Length: 2
Content-Type: text/plain; charset=utf-8
Date: Wed, 10 Apr 2019 15:11:49 GMT
X-Call-Id: 1d51dcaf-424a-48a7-a28f-6c5034b46f29
X-Duration-Seconds: 0.000577
X-Served-Date: 2019-04-10 15:11:49.998860566 +0000 UTC m=+1.512602566

OK
```

As part of a blog post on how to build a full Single Page App with OpenFaaS I used the golang-middleware template to build a function to consume events from GitHub and to store them in a Postgres database.

You can read the code here for [handler.go](https://github.com/alexellis/leaderboard-app/blob/master/github-sub/handler.go). Confidential data is configured through the use of secrets and non-confidential configuration us set through environment variables in [stack.yml](https://github.com/alexellis/leaderboard-app/blob/master/stack.yml#L18).

## Custom templates

The easiest way to start building your own template is to checkout some of the examples available from the community in the [template store](https://github.com/openfaas/store) or the [Official Classic templates](https://github.com/openfaas/templates/). And remember the [OpenFaaS workloads](https://docs.openfaas.com/reference/workloads/) contract.

If you have a binary, HTTP server or shell script that runs on Linux, then the chances are you can package and deploy it with OpenFaaS for a highly scalable, fault-tolerant serverless experience on any cloud.

## Wrapping up

A goal of Serverless and FaaS is to reduce boilerplate code and process so that you can focus on shipping code instead of worrying about infrastructure.

OpenFaaS provides a flexible templating system and build process through the use of the Docker image format and its user-friendly `faas-cli`. We saw several examples of how to package a Golang function and a Golang microservice into containers for use with OpenFaaS.

You can learn how to deploy OpenFaaS to Kubernetes and build functions and microservices using the [OpenFaaS workshop](https://github.com/openfaas/workshop/).

> OpenFaaS is written in Go. Checkout my new book [Everyday Go](http://store.openfaas.com/l/everyday-golang?layout=profile) for practical tips and hands-on examples to gain experience quickly or to level-up.

### Join the community

The OpenFaaS community values are: developers-first, operational simplicity, and community-centric.

If you have comments, questions or suggestions or would like to join the community, then please [join us on the weekly Office Hours call](https://docs.openfaas.com/community/).

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

### You may also like:

* [Introducing the Kubernetes Operator and CRD](/blog/kubernetes-operator-crd/)
* [Build a single page app with OpenFaaS Cloud](/blog/serverless-single-page-app/)
* [Sailing through the Serverless Ocean with Spotinst & OpenFaaS Cloud](https://spotinst.com/blog/2019/03/25/sailing-through-the-serverless-ocean-with-openfaas-cloud/)
