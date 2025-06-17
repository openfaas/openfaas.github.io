---
title: "Introducing Streaming Logs from the Function Builder"
description: "Learn how to stream real-time build logs from the OpenFaaS Function Builder API."
date: 2025-06-17
author_staff_member: han
categories:
 - functions
 - function-builder
 - integration 
dark_background: true
image: "/images/2025-06-function-builder-log-streaming/background.png"
hide_header_image: true
---

In this blog post we'll show you how to build functions using the [OpenFaaS Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/#function-builder-api) and stream build logs in real time.

The Function Builder API takes source code and builds container images without needing root or Docker. It's designed for SaaS companies who want their users to be able to supply their own code to integrate into their product. It can also be used by a platform or managed services team that manages a multi-tenant OpenFaaS environment.

By default, the builder prepares all logs and statuses of a container build in memory, with the build result and logs returned in the API response after completion. However, with the release of Function Builder [version 0.5.0](https://github.com/openfaasltd/pro-builder/pkgs/container/pro-builder/435771100?tag=0.5.0) and onwards, the API now supports streaming build logs.

This allows you to see the build progress in real time, which is useful for displaying live feedback to users.

<iframe width="560" height="315" src="https://www.youtube.com/embed/N_Z0vPtzlBs?si=dkInzqYKkWudbU_K" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

> Above: Video recording of invoking the Function Builder API. We use curl in both panes to perform the same build with and without log streaming. The terminal on the right shows the logs getting streamed in real time, the one on the left blocks until the build is completed.

In this post we:

- Show a recording of the streaming/non-streaming modes side by side.
- Run though an example with curl to show you how the streaming API works.
- Discuss how the [OpenFaaS SDK for Go](https://github.com/openfaas/go-sdk) was updated to support streaming build logs using Golang iterators instead of channels.

The OpenFaaS Function Builder API has been covered in a couple of blog post already. It as a key components for building a multi-tenant functions platform with OpenFaaS:
 
- [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)
- [How to build functions from source code with the Function Builder API](https://www.openfaas.com/blog/how-to-build-via-api/)
- [How to Build Functions with the Go SDK for OpenFaaS](https://www.openfaas.com/blog/building-functions-via-api-golang/)

## How to stream the logs and status output from a build

The Function Builder API offers a secure way to build containers via a standard HTTP REST call. It uses Buildkit, developed by the Docker community, to perform fast, cached, and in-cluster builds. To kick off a build, you send a POST request to its `/build` endpoint, with a tar archive containing a build context and configuration as the payload.

### Create a build context

First, let's create a test function using the `python3-http` template.

```sh
# Prepare a temporary directory
rm -rf /tmp/functions
mkdir -p /tmp/functions
cd /tmp/functions

faas-cli new --lang python3-http hello-world
```

Next, create a build context using the `faas-cli build --shrinkwrap` command. We also write out the build configuration to `com.openfaas.docker.config`.

```sh
# The shrinkwrap command performs the templating 
# stage, then stops before running "docker build"

# Look in ./build/hello-world to see the contents 
# that is normally passed to "docker build"
faas-cli build --shrinkwrap -f stack.yaml

# Now rename "hello-world" to "context"
# since that's the folder name expected by the builder
cd build
rm -rf context
mv hello-world context

# Create a config file with the registry and the 
# image name that you want to use for publishing the 
# function.
export REGISTRY=ttl.sh
export OWNER=openfaas
echo -n '{"image": "'$REGISTRY'/'$OWNER'/test-image-hello:10m", "platforms": ["linux/amd64"]}' > com.openfaas.docker.config
```

Then, create a tar archive of the context of the `/tmp/functions/build/` directory:

```sh
tar cvf req.tar  --exclude=req.tar  .
```

For a detailed explanation and more examples on how to create a build context and configuration, refer to our previous blog post: [How to build functions from source code with the Function Builder API ](https://www.openfaas.com/blog/how-to-build-via-api/).

In this example, our focus will be on the actual API invocation and how to receive real-time updates on the build progress.

### Invoke the builder API

By default, the builder gathers all logs and statuses in memory and sends them after the build completes. To stream the response and receive logs while the build is in progress, you need to set the HTTP `Accept` header to `application/x-ndjson` in your API request. This tells the API to respond with Newline Delimited JSON ([NDJSON](https://en.wikipedia.org/wiki/JSON_streaming)). NDJSON is simply a sequence of individual JSON objects, each separated by a newline character, making it ideal for streaming progress events over HTTP, as clients can parse each update as it arrives.

Before invoking the `/build` endpoint, you'll need to generate a SHA256 HMAC signature of your tar archive. This signature is essential for authenticating the request with the Function Builder API:

```sh
PAYLOAD=$(kubectl get secret -n openfaas payload-secret -o jsonpath='{.data.payload-secret}' | base64 --decode)

HMAC=$(cat req.tar | openssl dgst -sha256 -hmac $PAYLOAD | sed -e 's/^.* //')
```

Now, you can invoke the API like this.

Without streaming the build progress:

```sh
curl -H "X-Build-Signature: sha256=$HMAC" \
  --silent \
  http://127.0.0.1:8081/build -X POST --data-binary @req.tar | jq
```

Add the `Accept: application/x-ndjson` header to stream the build progress:

```sh
curl -H "Accept: application/x-ndjson" \
  -H "X-Build-Signature: sha256=$HMAC" \
  --silent \
  http://127.0.0.1:8081/build -X POST --data-binary @req.tar | jq
```

The API will immediately begin streaming the build progress as individual JSON objects, each separated by a newline character (\n), allowing for easy, one-at-a-time processing. Here's what individual objects look like as the build progresses:

The intermediate output is identified by the `status` field containing `in_progress`. Log lines are available in the `log` field:

```sh
{
  "log": [
    "v: 2021-10-20T16:48:34Z [ship 1/16] WORKDIR /home/app/",
    "v: 2021-10-20T16:48:34Z exporting to image 8.01s"
  ],
  "status": "in_progress",
  "duration": 0.201
}
```

Upon completion, the status field will contain `success` or `failure`.

```sh
{

  "image": "ttl.sh/openfaas/test-image-hello:10m",
  "status": "success",
  "duration": 0.843
}
```

When the build fails, further details may be included in the `error` field.

```sh
{

  "image": "ttl.sh/openfaas/test-image-hello:10m",
  "status": "failure",
  "error": "failed to solve: process \"/bin/sh -c npm i\" did not complete successfully: exit code: 1",
  "duration": 0.843
}
```

## Build and stream logs with the Go SDK

If you're writing code in Go, you can quickly integrate the Function Builder API into your existing systems using the [Go SDK](https://github.com/openfaas/go-sdk). It offers ready-to-use functions and types that abstract away much of the process described in the previous section, making integration straightforward.

This example demonstrates how to build the Python function we created earlier using the OpenFaaS Go SDK. We won't run through the steps to generate a function again.

To build a function using the Go SDK you need to:

* Load the payload secret from a file, or from a secret store, to sign the payload sent to the builder API.
* Create an instance of the builder client with the URL of the builder API and the HMAC secret specified, remember to strip any whitespace from the secret.
* Create a tar archive with the build context
* Specify the build configuration, this will be written out as a file named `com.openfaas.build.config` in the tar archive.
* Invoke the builder API with the tar archive, and the builder will build the image and push it to the registry.
* Process the build results which include logs that are streamed by the API during the build.

For a more detailed walkthrough of these steps and how to use the Go SDK, refer to our blog post: [How to Build Functions with the Go SDK for OpenFaaS](https://www.openfaas.com/blog/building-functions-via-api-golang/)

This post specifically focuses on the last two steps: invoking the builder API and streaming build logs. To support the new log streaming feature, we've added a new method, BuildWithStream, to the builder client.

```go
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
    image = "ttl.sh/openfaas/hello-world-python:30m"
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
		Image:     image,
		Platforms: []string{"linux/amd64"},
		BuildArgs: map[string]string{},
	}

	// Prepare a tar archive that contains the build config and build context.
	if err := builder.MakeTar(tarPath, buildContext, &buildConfig); err != nil {
		log.Fatal(err)
	}

	// Invoke the function builder with the tar archive containing the build config and context
	// to build and push the function image.
	//
	// A BuildResultStream is returned that can be used to iterate over the build logs as they arrive.
	stream, err := b.BuildWithStream(tarPath)
	if err != nil {
		log.Fatal(err)
	}
	defer stream.Close()

	for event, err := range stream.Results() {
		if err != nil {
			log.Fatal(err)
		}

		if event.Log != nil {
			for _, logMsg := range event.Log {
				fmt.Printf("%s\n", logMsg)
			}
		}

		if event.Status == builder.BuildSuccess || event.Status == builder.BuildFailed {
			fmt.Printf("Status: %s\n", event.Status)
			fmt.Printf("Image: %s\n", event.Image)

			if len(event.Error) > 0 {
				fmt.Printf("Error: %s\n", event.Error)
			}
		}
	}
}
```

When you use the `BuildWithStream` method, the SDK invokes the Function Builder API and requests that the build progress be streamed in the response. If the invocation is successful, the method returns a `*builder.BuildResultStream`. This stream allows you to iterate over the build progress and has two key methods:

- `Results()`: This method returns a single-use iterator.

	You can use a range expression to loop over this iterator and receive intermediate build results. Each iteration produces a `builder.BuildResult` and an `error`.

	While the build is in progress, `result.Status` will always be `in_progress`, and `result.Log` will contain the container build logs.

	When the build completes successfully, `result.Status` will be `success`, and `result.Image` will contain the reference for the published image. If an error occurs during the build process, the status will be `failed`, and `result.Error` should contain the error that caused the build to fail.

	The iterator produces an `error` only when something goes wrong while reading or parsing a build result from the HTTP response.

- `Close()`: This method stops the stream and ensures the underlying connection is closed.

	The stream is automatically closed when you iterate through all results or when the iteration terminates (e.g., with `break` or `return`). However, it's a good practice to call `defer stream.Close()` immediately after a successful call to `BuildWithStream` to prevent any resource leaks.


### Why iterators?

Calling `Results()` on a `BuildResultStream` returns an iterator of the type [iter.seq2](https://pkg.go.dev/iter#Seq2). Iterators are a newer addition to Go (since version 1.23), which is why they might not be commonly seen in many libraries yet. For the OpenFaaS Go SDK, we opted for iterators over the more common channel pattern for two main reasons:

- **Handling errors gracefully**

	By using the `iter.seq2` type, we can yield two values: the `builder.BuildResult` itself and an `error`. When a new result arrives, we parse it and return it along with a nil error, just like a standard Go function. If there's an error reading or parsing the result, we can use the error to signal the problem. The code consuming the SDK API can then decide how to handle it, whether by logging the error or breaking out of the loop and stopping event processing.

- **Simplified cleanup**

	Iterators allow us to detect when the calling loop is finished. This is particularly useful in our scenario where the iterator holds resources (like a network connection) that need to be cleaned up. With channels, much more coordination is typically required to prevent resource leaks. For instance, if you stop listening to a channel, the sending goroutine (and the underlying connection) might block indefinitely, leading to a leak. While there are ways to deal with this, they can be annoying and Iterators do it in a more user-friendly way. By using an iterator we also reduce the likelihood SDK consumers make common mistakes that cause resource to be leaked.

## Conclusion

This post demonstrated how the Function Builder API in OpenFaaS, with its new log streaming capabilities, offers enhanced visibility into the build process. By supporting Newline Delimited JSON (NDJSON), the API allows you to receive real-time build progress updates which allow you to provide live feedback to your users or for monitoring long-running builds.

We explored how to interact with this streaming functionality directly using `curl` and delved into the changes made to the OpenFaaS Go SDK to support log streaming. We highlighted the new `BuildWithStream` method that uses Go iterators to make processing the real-time build logs in your Go applications as convenient as possible.

The Function Builder remains a crucial component for creating robust and scalable multi-tenant serverless platforms with OpenFaaS. It allows users to turn their custom code into functions that can be deployed with OpenFaaS securely and efficiently.

## Dive deeper into the Function Builder API

For a more in-depth overview, best practices, and configuration guidelines for the OpenFaaS Function Builder API, be sure to check out these resources:

- [How to build functions from source code with the Function Builder API](https://www.openfaas.com/blog/how-to-build-via-api/)
- [How to Build Functions with the Go SDK for OpenFaaS](https://www.openfaas.com/blog/building-functions-via-api-golang/)

## Explore building serverless platforms with OpenFaaS

If you're looking to integrate FaaS capabilities into your product or provide a serverless platform for your team, you may also like:

- [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)
- [How to Build & Integrate with Functions using OpenFaaS](https://www.openfaas.com/blog/integrate-with-openfaas/)
- [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)