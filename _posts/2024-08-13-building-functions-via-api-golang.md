---
title: How to Build Functions with the Go SDK for OpenFaaS
description: Learn how to build functions from source with the Function builder API and Go SDK for OpenFaaS
date: 2024-08-13
categories:
- kubernetes
- faas
- functions
- builder
- multi-tenant
dark_background: true
image: /images/2024-08-function-builder/background.jpg
author_staff_member: alex
hide_header_image: true
---

In this blog post I'll show you how to build functions using the new `builder` package for the [Go SDK](https://github.com/openfaas/go-sdk) for OpenFaaS.

You can use the [builder package](https://pkg.go.dev/github.com/openfaas/go-sdk/builder) to access the the Function Builder API, which takes source code and builds container images without needing root or Docker. It's designed for SaaS companies who want their users to be able to supply their own code to integrate into their product. It can also be used by a platform or managed services team that manages a multi-tenant OpenFaaS environment.

As a general rule, we see customers provide an AWS Lambda-like experience for their users, where code is typed into a text box using a web IDE, and then deployed with a single click.

**Customer spotlight**

Patchworks (https://www.wearepatchworks.com/) is an iPaaS platform that helps businesses transform and connect data between retail systems such as e-commerce, ERP, Warehouse management and marketplaces. They have a pre-built library of [*Connectors*](https://doc.wearepatchworks.com/product-documentation/connectors-and-instances/connectors-and-instances-introduction#connectors) to sync to/from associated applications, a pre-built library of OpenFaaS hosted scripts, and also allow customers to supply their own code using *[Custom Scripting](https://doc.wearepatchworks.com/product-documentation/developer-hub/custom-scripting)* which supports 6 programming languages via OpenFaaS with others able to be configured in if needed. 

Whether the *Custom Script* is pre-supplied by the Patchworks team, or created by a customer, it is built and deployed using the same approach by making a HTTP call to the Function Builder API. The resulting container image is published to a registry, and then gets deployed as an OpenFaaS function. Whenever a script is needed by a user's workflow, it is invoked over HTTP via the OpenFaaS gateway.

For an example of the user-experience Patchworks created for their users, see: [Patchworks docs: Adding & testing custom scripts](https://doc.wearepatchworks.com/product-documentation/developer-hub/custom-scripting/adding-and-testing-custom-scripts#creating-a-new-script)

[E2E Networks Limited](https://www.e2enetworks.com/) is an NSE-listed, infrastructure company headquartered in India. They integrated OpenFaaS more directly, and provide an additional tab alongside other services such as Computer, Kubernetes, & VPCs in their cloud dashboard. Users can supply code using predefined OpenFaaS templates, invoke their functions, and monitor the results in one place. E2E Networks also supply a CLI and GitHub Actions integration.

See also: [E2E networks: Function as a Service (FaaS)](https://docs.e2enetworks.com/faas_doc/faas.html)

**Contents**

* A quick recap on function templates
* Complete example with Go SDK
* How to build multi-arch images
* How to pass build-arguments
* Conclusion

## A quick recap on function templates

OpenFaaS is a serverless platform for building, deploying, [monitoring](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/), [triggering](https://docs.openfaas.com/reference/triggers/) and [scaling](https://docs.openfaas.com/architecture/autoscaling/) functions on Kubernetes. The logical unit is the Open Container Initiative (OCI) image which contains the function code and dependencies. The start-up process is generally the optional [watchdog](https://docs.openfaas.com/architecture/watchdog/) which is responsible for starting the process that handles HTTP requests from the OpenFaaS API. Existing code or containers can also be supplied so long as it conforms to the workload contract, and exposes HTTP traffic along with a readiness endpoint.

The purpose of a template is to make starting a new function easy, without having to think about Dockerfiles, HTTP frameworks, or dependency management. Templates are stored in Git, and the built-in tooling in `faas-cli` can fetch them and use them to scaffold a new function. Templates can be written for any language, so long as they can execute on Linux, expose a HTTP server, and can be built into a container image using a Dockerfile.

For the [golang-middleware](https://github.com/openfaas/golang-http-template) template, whilst users only need to work with a `go.mod` and `handler.go` file, if you look at the Git repository, you'll see the code that starts the process, along with the Dockerfile etc:

```
template/golang-middleware
template/golang-middleware/Dockerfile
template/golang-middleware/main.go
template/golang-middleware/.gitignore
template/golang-middleware/template.yml
template/golang-middleware/go.work
template/golang-middleware/function
template/golang-middleware/function/handler.go
template/golang-middleware/function/go.mod
template/golang-middleware/go.mod
```

As a general rule, users will edit the files in the `function` directory, and template authors write and maintain the files outside of that directory.

Every time a build is performed, the CLI will create a folder such as `build/hello-world`, then it writes the base content of the template into that directory and then copies the user's code into the `function` directory. The `build/hello-world` directory is then used as the build context for the container build.

Templates can be shared with the community, or kept private within an organization. They can be versioned, and they can be updated with new features or bug-fixes.

## Complete example with Go SDK

The Function Builder API takes a Docker build context as an input, and returns the URL to a published image, along with the logs as the result. It can run as non-root, and does not require Docker to be installed. The feature is available in OpenFaaS for Enterprises and is deployed via [separate Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder).

You can read how the Function Builder API works in the [OpenFaaS documentation](https://docs.openfaas.com/openfaas-pro/builder/), which also includes step-by-step examples using Bash, `curl`, and `tar` to show exactly how to prepare a bundle of source code and configuration for the builder.

The below code in the Go SDK abstracts some of the process away so that if you write code in Go, you can integrate the Function Builder API into your existing systems in a short period of time.

Briefly:

* You need to load the payload secret from a file, or from a secret store, to sign the payload sent to the builder API.
* You'll need to create a instance of the builder client with the URL of the builder API and the HMAC secret specified, remember to strip any whitespace from the secret.
* Then you will need to create a tar archive with the build context
* Specify the build configuration, this will be written out as a file named `com.openfaas.build.config` in the tar archive.
* Invoke the builder API with the tar archive, and the builder will build the image and push it to the registry.
* Finally, handle the HTTP status code and the logs from the API.

The code below assumes that you already have the required templates in the working directory, and that you have a `payload.txt` file with the HMAC secret (use the command in the docs to obtain this).

For the example, we used the same functionName and handler, and the language is `python3-http`. The image name is `ttl.sh/hello-world-python:30m` and the platform is `linux/amd64`.

This is the equivalent to the following OpenFaaS stack.yaml file:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  hello-world-python:
    lang: python3-http
    handler: ./hello-world-python
    image: ttl.sh/hello-world-python:30m
```

The code for main.go:

```golang
package main

import (
	"bytes"
	"log"
	"net/http"
	"net/url"
	"os"

	"github.com/openfaas/go-sdk/builder"
)

func main() {

	functionName := "hello-world-python"
	handler := "hello-world-python"
	lang := "python3-http"

	// Load the HMAC secret used for payload authentication with the builder API.
	payloadSecret, err := os.ReadFile(os.ExpandEnv("$HOME/.openfaas/payload.txt"))
	if err != nil {
		log.Fatal(err)
	}
	payloadSecret = bytes.TrimSpace(payloadSecret)

	// Initialize a new builder client.
	builderURL, _ := url.Parse("http://127.0.0.1:8081")
	b := builder.NewFunctionBuilder(builderURL, http.DefaultClient, builder.WithHmacAuth(string(payloadSecret)))

	// Create a temporary file for the build tar.
	tarFile, err := os.CreateTemp(os.TempDir(), "build-context-*.tar")
	if err != nil {
		log.Fatalf("failed to temporary file: %s", err)
	}
	tarFile.Close()

	tarPath := tarFile.Name()
	defer os.Remove(tarPath)

	// Create the function build context using the provided function handler and language template.
	buildContext, err := builder.CreateBuildContext(functionName, handler, lang, []string{})
	if err != nil {
		log.Fatalf("failed to create build context: %s", err)
	}

	// Configuration for the build.
	// Set the image name plus optional build arguments and target platforms for multi-arch images.
	buildConfig := builder.BuildConfig{
		Image:     "ttl.sh/hello-world-python:30m",
		Platforms: []string{"linux/amd64"},
		BuildArgs: map[string]string{},
	}

	// Prepare a tar archive that contains the build config and build context.
	if err := builder.MakeTar(tarPath, buildContext, &buildConfig); err != nil {
		log.Fatal(err)
	}

	// Invoke the function builder with the tar archive containing the build config and context
	// to build and push the function image.
	result, err := b.Build(tarPath)
	if err != nil {
		log.Fatal(err)
	}

	log.Println("Build from builder:")
	for _, logMsg := range result.Log {
		log.Printf("%s\n", logMsg)
	}

	log.Printf("\nStatus: %s, imageRef: %s", result.Status, result.Image)
}
```

When the build completes successfully, the `result.Status` will contain `success` and the `result.Image` will contain the URL to the published image. If the result is not equal to `success`, then there was an error during the build process, and the `result.Log` property should contain the logs from the build process.

A failed build could be the result of incorrectly configured registry credentials, a syntax error in the function code, a missing dependency, a network issue, or a failing unit test supplied by the user. 

**What about the templates?**

The `builder.CreateBuildContext` call takes the `lang` variable which is the name of the OpenFaaS template. The templates must already be presented in the working directory before invoking the `builder.CreateBuildContext` function.

The `faas-cli` is able to clone templates from a Git repository by looking up a JSON manifest file that indexes the various public templates, however you are likely going to have your own set of private templates.

You aren't limited to hosting your templates in a public Git repository like the official templates, you could do any of the following as examples:

* Embedded in your application using Go's [`embed` package](https://pkg.go.dev/embed)
* Stored in a Git repository and cloned at build-time
* Packaged with your application when you build or deploy your application, perhaps using steps in your Dockerfile
* Stored in a Kubernetes volume, mounted to the Pod
* Stored in an S3 bucket, and downloaded at runtime

**What about authentication to ECR, GCR, ACR, The Docker Hub, and other registries?**

As part of the instructions to set up and install the Function Builder, you will create an authentication secret in Kubernetes. This secret will be associated with the builder, and must be created with the instructions given. A common issue is when users mis-read the instructions and instead copy their local `.docker/config.json` file which often is empty, deferring to the operating system's credential store.

For clouds that use service accounts such as GCR, ECR, and etc, a credential helper is built into the image which will obtain a short-lived token in order to publish images.

For The Docker Hub, or other self-hosted registries, you will need to obtain a long-lived token, and to rotate it periodically.

The examples use a free to use registry called `ttl.sh`, it is likely to be very slow compared to hosted registry in the same region as your Kubernetes cluster, but it doesn't require authentication, so we suggest you start there and focus on the workflow first.

**Create a tenant namespace and deploy the function**

You can find two examples on GitHub for creating a tenant namespace and deploying a function:

* [create-namespace](https://github.com/openfaas/go-sdk/blob/master/example/create-namespace/main.go)
* [deploy-function](https://github.com/openfaas/go-sdk/blob/master/example/deploy-function/main.go)

You can use other languages to create and deploy functions, since the Function Builder and the OpenFaaS Gateway both have HTTP REST APIs, but the Go SDK means that you could prototype or build a complete solution in Go in a very short period of time.

**Try out the example**

```bash
## Pull the template into the working directory
faas-cli template store pull python3-http

## Template a new function using the CLI:
faas-cli new --lang python3-http hello-world-python

## Create a payload.txt file with the HMAC
export PAYLOAD=$(kubectl get secret -n openfaas payload-secret -o jsonpath='{.data.payload-secret}' | base64 --decode)
echo $PAYLOAD > $HOME/.openfaas/payload.txt

## Port-forward the builder API in the background
kubectl port-forward -n openfaas \
    deploy/pro-builder 8081:8080 &
```

Run main.go:

```bash
go run .
```

Note that the `ttl.sh` registry used is a public registry designed for testing and development, it is also likely to have high latency. To get the absolutely best build time, use a registry, deployed to the same region as your Kubernetes cluster.

## How to build multi-arch images

The Function Builder API supports building images for multiple different CPU architectures. Practically speaking this will be one of two architectures: `linux/amd64` (also known as "normal Intel/AMD processors") and `linux/arm64` which is a 64-bit Arm processor. Other architectures are supported by the Function Builder API, but are less common in commercial settings.

**One architecture or two?**

It will increase build latency, waste CPU cycles and use up storage space, if you needlessly build multi-arch images. However, if your worker nodes are heterogeneous, or you want to support a wider range of devices for deployment, then multi-arch images make more sense. All the container images for the core OpenFaaS platform are built for both `linux/amd64` and `linux/arm64` to support Ampere Altra, AWS Graviton, and IoT devices like the Raspberry Pi,

64-Arm images be be built either on a `linux/arm64` node, or on a `linux/amd64` host using an emulation layer such as QEMU. Having dedicated Arm nodes for Arm builds requires additional resources, but is a much faster option than emulation. If you want to publish a multi-arch image in one shot, then you will have to endure emulation of at least one of the two build platforms.

And for a completely optimised build, you'll perform three builds. One `linux/amd64` build on `linux/amd64` hardware, one `linux/arm64` build on `linux/arm64` hardware, and then a final build which ties together the references into a single image manifest. Practically speaking, the third build can be optimised away by using a Go container library such as [github.com/google/go-containerregistry](github.com/google/go-containerregistry) to write the manifest without invoking a third build.

The default build platform will be specified in the template's Dockerfile, or be determined by the node where you're running the Function Builder API. If you want to build for a different platform, you can specify it in the `buildConfig` struct.

```golang
buildConfig := builder.BuildConfig{
    Image:     "ttl.sh/hello-docker:30m",
    Platforms: []string{"linux/amd64", "linux/arm64"},
    BuildArgs: map[string]string{},
}
```

## How to pass build-arguments

Build-arguments are used to override behaviour within a Dockerfile.

* Add additional packages or dependencies
* Set environment variables
* Set the version of a package or library
* Change the base image or tag for a base image

Consider the following example, instead of maintaining different templates for Node 16, 17, 18 & 20 and beyond, you can maintain one, and just change the NODE_VERSION build argument.
```Dockerfile
ARG NODE_VERSION
FROM node:${NODE_VERSION:-20} as build

WORKDIR /home/app/function
COPY package.json .
RUN npm install
COPY . .

CMD ["npm", "start"]
```

In the Go SDK, you can pass build arguments like this:

```golang
buildConfig := builder.BuildConfig{
    Image:     "ttl.sh/hello-docker:30m",
    Platforms: []string{"linux/amd64"},
    BuildArgs: map[string]string{
        "NODE_VERSION": "22",
    },
}
```

A common mistake with multi-step templates, and build-arguments is not declaring the `ARG` in the correct scope. If you declare an `ARG` in the first stage, but use it in the second stage, then the build will fail. The `ARG` must be declared in the stage where it is used.

In the following example, the `NODE_ARG` will always be `20`, the default value, you must add `ARG NODE_VERSION` to the second stage named `build`.

```Dockerfile
ARG NODE_VERSION
ARG FAAS_CLI_VERSION
FROM alpine:latest as downloader

RUN apk add --no-cache curl && 
    curl -sL https://github.com/openfaas/faas-cli/releases/download/${FAAS_CLI_VERSION}/faas-cli > /usr/bin/faas-cli

FROM node:${NODE_VERSION:-20} as build

WORKDIR /home/app/function
COPY package.json .
RUN npm install
COPY . .
```

## Conclusion

The Function Builder API is an essential building-block for SaaS companies like Patchworks who need to give customers a way to provide their own code, and for multi-tenant environments like the one run by E2E Networks. Once you have decided which language or languages to support for your users, you can create your own templates, or adapt existing ones. Then the Go SDK makes it quick to build & publish functions, and to deploy them into tenant namespaces.

If you deploy a managed or self-managed registry in the same region or datacenter as the OpenFaaS Kubernetes cluster, then the total time between a user hitting "Save" and your function being deployed could be as low as a few seconds. When a base image is already available in the Function Builder, and builds of a function have minimal changes, the time between hitting "Save" and presenting the build logs to the user could be under a second. From speaking to customers over the year, many bespoke or in-house solutions end up making the feedback loop much longer than this.

The Go SDK is ideal for teams who are familiar with or that want to learn Go, but since the API is HTTP-based, you can use any language that supports making HTTP requests. We have a number of samples in other languages such as: [Node.js, Python, and PHP](https://github.com/openfaas/function-builder-examples).

For a more detailed walk-through, with diagrams and examples, see: [How to build functions from source code with the Function Builder API](https://www.openfaas.com/blog/how-to-build-via-api/)

You can find the Go SDK on GitHub at [github.com/openfaas/go-sdk](https://github.com/openfaas/go-sdk) and the [Function Builder API in the docs](https://docs.openfaas.com/openfaas-pro/builder).

If you have questions or would like to know more, [reach out to us via this page](https://openfaas.com/pricing).

