---
title: "Get started with Java 11 and Vert.x on Kubernetes with OpenFaaS"
description: Follow this tutorial to get started with Java 11 and Vert.x on Kubernetes with OpenFaaS without worrying about mastering YAML or having to optimize a lengthy Docker build.
date: 2020-01-30
image: /images/2020-01-30-get-started-with-java-openjdk11/java11.jpg
categories:
  - serverless
  - paas
  - kubernetes
  - java
  - vert-x
author_staff_member: alex
dark_background: true

---

Follow this tutorial to get started with Java 11 and Vert.x on Kubernetes with OpenFaaS without worrying about mastering YAML or having to optimize a lengthy Docker build.

## Before we start

You'll need access to the following:

* An Intel computer or a remote cluster
* [Kubernetes](https://kubernetes.io/) - install with your preferred local tooling such as KinD, minikube, or k3d. Or use a cloud service like Amazon EKS, GKE or DigitalOcean Kubernetes. A single VM running k3s is also fine.
* [OpenFaaS](https://github.com/openfaas/faas) - we'll install OpenFaaS in the guide using a developer setup, you can read past blog posts and the documentation for how to best tune your setup for production

## Tutorial

We'll first of all get OpenFaaS installed using the easiest way possible. Then we'll build two different functions, one will use a function-like template called `java11` and the other `java11-vert-x` will use Vert.x from the Eclipse Foundation. Both OpenFaaS templates use Eclipse Temurin images based on Ubuntu 24.04 Noble and have built-in support for external dependencies from artifact repositories such as Maven Central. The chosen build system for the templates is Gradle, so that you can see a worked example and start making use of your Kubernetes clusters to solve real problems.

> OpenFaaS templates use Eclipse Temurin for their JDK and JRE images. They are fully customisable, so you can fork them and switch to [Maven](https://maven.apache.org/) if you wish. See the link at the end of the post.

### Get OpenFaaS

Make sure that you have the Kubernetes CLI ([kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)) available.

Download [arkade](https://arkade.dev/), which is an installer for helm charts for any Kubernetes cluster. We will install OpenFaaS using `arkade install` and [the OpenFaaS helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas):

```sh
curl -sSLf https://get.arkade.dev | sudo sh
```

Now install openfaas:

```sh
arkade install openfaas
```

You can also customise values from the helm chart's README by passing in `--set`, for instance, or by using a user-friendly flag shown below:

```sh
Install openfaas

Usage:
  arkade install openfaas [flags]

Examples:
  arkade install openfaas --loadbalancer

Flags:
  -a, --basic-auth                    Enable authentication (default true)
      --clusterrole                   Create a ClusterRole for OpenFaaS instead of a limited scope Role
      --direct-functions              Invoke functions directly from the gateway (default true)
      --function-pull-policy string   Pull policy for functions (default "Always")
      --gateways int                  Replicas of gateway (default 1)
  -h, --help                          help for openfaas
  -l, --load-balancer                 Add a loadbalancer
  -n, --namespace string              The namespace for the core services (default "openfaas")
      --operator                      Create OpenFaaS Operator
      --pull-policy string            Pull policy for OpenFaaS core services (default "IfNotPresent")
      --queue-workers int             Replicas of queue-worker (default 1)
      --set stringArray               Use custom flags or override existing flags 
                                      (example --set=gateway.replicas=2)
      --update-repo                   Update the helm repo (default true)
```

At the end of the installation you'll get instructions for how to:

* install the OpenFaaS CLI (`faas-cli`)
* port-forward the gateway to your local machine
* and to log-in using `faas-cli login`

If you lose this information just type in `arkade info openfaas` at any time.

### Example 1) The `java11` function

Pull the official templates:

```sh
faas-cli template pull
```

Create a new function named `find-a-quote`:

```sh
faas-cli new --lang java11 \
  --yaml find-a-quote.yml \
  find-a-quote
```

OpenFaaS builds immutable Docker or OCI-format images, so you will need to push your image to a registry such as the Docker Hub, you can edit your `find-a-quote.yml` file and add your Docker Hub username like `image: alexellis2/find-a-quote:latest`.

> If you're new to working with Docker and Kubernetes, then I would recommend taking up the workshop listed at the end of this tutorial which explains all of the above in detail.

You'll now get the following familiar Java file-system with a place for unit tests and for your function's code.

```sh
├── find-a-quote
│   ├── build.gradle
│   ├── gradle
│   │   └── wrapper
│   │       ├── gradle-wrapper.jar
│   │       └── gradle-wrapper.properties
│   ├── settings.gradle
│   └── src
│       ├── main
│       │   └── java
│       │       └── com
│       │           └── openfaas
│       │               └── function
│       │                   └── Handler.java
│       └── test
│           └── java
│               └── HandlerTest.java
└── find-a-quote.yml
```

This is the handler, which you can customise.

```java
package com.openfaas.function;

import com.openfaas.model.IResponse;
import com.openfaas.model.IRequest;
import com.openfaas.model.Response;

public class Handler extends com.openfaas.model.AbstractHandler {

    public IResponse Handle(IRequest req) {
        Response res = new Response();
	    res.setBody("Hello, world!");

	    return res;
    }
}
```

We're going to query [DummyJSON](https://dummyjson.com/docs/quotes) and use the query-string to select a quote by ID from `https://dummyjson.com/quotes/:id`.

This template uses Gradle, and we'll need to add dependencies to fetch HTTP pages with [OkHttp](https://square.github.io/okhttp/).

Keep the template's existing dependencies and add these two lines to its `dependencies` block:

```javascript
dependencies {
    // Existing template dependencies remain above.
    compile 'com.squareup.okhttp3:okhttp:3.10.0'
    compile 'com.squareup.okio:okio:1.14.1'
}
```

Let's see the new code for the Handler.java file.

First we need to get the "query-string" from the `IRequest` in the function handler, the interface looks like this:

```java
public interface IRequest {
    String getBody();
    Map<String, String> getHeaders();
    String getHeader(String key);
    String getQueryRaw();
    Map<String, String> getQuery();
    String getPathRaw();
    Map<String, String> getPath();
}
```

In the URL we will pass a query string of `?id=1` to select a quote, so let's see what that looks like:

```java
package com.openfaas.function;

import com.openfaas.model.IResponse;
import com.openfaas.model.IRequest;
import com.openfaas.model.Response;
import java.util.Map;

import okhttp3.OkHttpClient;

public class Handler extends com.openfaas.model.AbstractHandler {

    public IResponse Handle(IRequest req) {
        IResponse res = new Response();

        try {
            OkHttpClient client = new OkHttpClient();

            Map<String, String> query = req.getQuery();
            String id = query.get("id");

            String url = "https://dummyjson.com/quotes/" + id;
            okhttp3.Request request = new okhttp3.Request.Builder()
                .url(url)
                .build();

            okhttp3.Response response = client.newCall(request).execute();
            String ret = response.body().string();
            res.setBody(ret);

        } catch(Exception e) {
            e.printStackTrace();
            res.setBody(e.toString());
        }

        return res;
    }
}
```

Now we can run a build and deploy our function, but first let's enable Docker's new Buildkit container builder which can dramatically reduce the time taken to build images.

```sh
export DOCKER_BUILDKIT=1
```

```sh
faas-cli up -f find-a-quote.yml
```

My build took around 15s to complete on a modest Intel i7 micro-PC.

You'll be given a URL and Kubernetes will have already pulled the image and started a Pod for your function.

```
kubectl get deploy -n openfaas-fn -o wide
```

```sh
curl -sSLf http://127.0.0.1:8080/function/find-a-quote?id=1 | jq
```

In the example above I used the `jq` utility to format the output:

```json
{
  "id": 1,
  "quote": "Your heart is the size of an ocean. Go find yourself in its hidden depths.",
  "author": "Rumi"
}
```

As an extension of this example, why don't you customise the code to parse the response and return only the quote text? You'll want to find yourself a JSON parsing library and then add it to your `build.gradle` file.

> In my blog post [Java comes to OpenFaaS from 2018](https://blog.alexellis.io/java-comes-to-openfaas/), I used [Gson from Google](https://github.com/google/gson). You'll find an example of how to use the library in that post.

### Example 2) The `java11-vert-x` service

In this example we'll build a service using Vert.x which determine the latest download URL for a GitHub project. We'll set the name and owner of the project via the deployment YAML file, rather than taking it in via the query string.

Why do this? Well downloading binaries from GitHub's releases page is a common task that needs to be automated in many workflows, unfortunately the GitHub API that gives this data back is very heavily rate-limited. Fortunately there's a work-around to send a HTTP `HEAD` request to the GitHub HTTP server instead.

```sh
faas-cli new --lang java11-vert-x \
  --yaml github-release-finder.yml \
  github-release-finder
```

Edit `github-release-finder.yml` and add the following for your service:

```yaml
    environment:
      owner: openfaas
      repo: faas-cli
```

We can read this deployment data at runtime using `System.getenv()`, for confidential data like API tokens, we would use a Kubernetes secret created via `faas-cli secret create` or `kubectl`.

Here's what our basic Handler.java file looks like with the Vert.x template:

```java
package com.openfaas.function;

import io.vertx.ext.web.RoutingContext;
import io.vertx.core.json.JsonObject;

public class Handler implements io.vertx.core.Handler<RoutingContext> {

  public void handle(RoutingContext routingContext) {
    routingContext.response()
      .putHeader("content-type", "application/json;charset=UTF-8")
      .end(
        new JsonObject()
          .put("status", "ok")
          .encodePrettily()
      );
  }
}
```

You can see that we have the ability to take much more control over the HTTP request and response and to use middleware.

Let's update the Handler with my sample code:

```java
package com.openfaas.function;

import io.vertx.ext.web.RoutingContext;
import io.vertx.core.json.JsonObject;

import io.vertx.core.buffer.Buffer;
import io.vertx.ext.web.client.HttpResponse;
import io.vertx.ext.web.client.WebClient;
import io.vertx.ext.web.client.WebClientOptions;

public class Handler implements io.vertx.core.Handler<RoutingContext> {

  public void handle(RoutingContext routingContext) {

    WebClientOptions options = new WebClientOptions();
    options.setFollowRedirects(false);

    WebClient client = WebClient.create(routingContext.vertx(), options);

    String repo = System.getenv("repo");
    String owner = System.getenv("owner");

    client
      .head(443, "github.com", "/"+owner+"/"+repo+"/releases/latest")
      .ssl(true)
      .send(ar -> {
        if (ar.succeeded()) {
          HttpResponse<Buffer> response = ar.result();

          System.out.println("Received response with status code " + response.statusCode());
          String location = response.getHeader("Location");

          routingContext.response()
          .putHeader("content-type", "application/json;charset=UTF-8")
          .end(
            new JsonObject()
              .put("releaseUrl", location)
              .encodePrettily()
          );

        } else {
          System.out.println("Something went wrong " + ar.cause().getMessage());

          routingContext.response()
          .putHeader("content-type", "application/json;charset=UTF-8")
          .end(
            new JsonObject()
              .put("releaseUrl", "")
              .encodePrettily()
          );

        }
      });
  }
}
```

I'm using the Vert.x [WebClient](https://vertx.io/docs/vertx-web-client/java/) instead of okhttp in this example to show you the versatility of the OpenFaaS templates.

Now update your `build.gradle` file again and add in the following for `io.vertx:vertx-web-client:3.8.5`:

```javascript
dependencies {
    // Vert.x project
    implementation 'io.vertx:vertx-web:3.5.4'

    // Use JUnit test framework
    testImplementation 'junit:junit:4.12'    

    implementation 'io.vertx:vertx-web-client:3.8.5'
}
```

Now run `faas-cli up` again:

```sh
faas-cli up -f github-release-finder.yml
```

My build took around 15s with Buildkit enabled.

> I worked with a customer earlier in the week who was incurring a massive 2m30s for every rebuild of his simple [Springboot](https://spring.io/projects/spring-boot) API. We can enjoy a much faster build, even when adding a framework like Vert.x.

Let's try the function:

```sh
curl http://127.0.0.1:8080/function/github-release-finder ; echo
{
  "releaseUrl" : "https://github.com/openfaas/faas-cli/releases/tag/0.18.13"
}
```

As an extension to the task, why don't you edit the environment section of your `github-release-finder.yml` file and select a different repo like `alexellis/arkade`, or the main Kubernetes repo. 

### Wrapping up

In a short period of time we were able to build a function and a Vert.x service using OpenFaaS and then to deploy that to a Kubernetes cluster of our choosing. We didn't have to worry about hiring a DevOps expert to hand-craft lengthy YAML files or to tune our Dockerfiles (a common cause of contention for Java development teams).

#### So what does OpenFaaS offer over "vanilla Kubernetes"?

When deployed to Kubernetes, OpenFaaS offers an application stack just like MEAN, LAMP or JAMStack, you can watch my video [from KubeCon on the PLONK stack](https://www.youtube.com/watch?v=NckMekZXRt8) which goes into a bit more detail.

Here's an overview from 10,000ft:

* community-supported and (for customers, commercially-supported) templates for popular languages, optimized and hand-tuned
* a template store ecosystem to find community templates, see `faas-cli template store list`
* optional auto-scaling from 0 to many and back down to zero again
* a simple API to deploy to Kubernetes with best practices, which let your team ship changes quickly
* the ability to ship functions or services, without worrying about all the Kubernetes YAML files that would normally be a concern
* a welcoming and helpful community of developers, sponsors, and end-users with over 2.5k members and 20k GitHub stars

### Try this next

Perhaps next you'd like to move to a managed Kubernetes service, or add a TLS certificate and a custom domain to your OpenFaaS functions?

* [Get TLS for OpenFaaS the easy way with arkade](https://blog.alexellis.io/tls-the-easy-way-with-openfaas-and-k3sup/)
* [Deploy OpenFaaS on Amazon EKS](https://aws.amazon.com/blogs/opensource/deploy-openfaas-aws-eks/)

Find out more about OpenFaaS and Vert.x

* [Get started with the OpenFaaS workshop](https://github.com/openfaas/workshop/) - 12 self-paced labs for setting up a Kubernetes cluster with OpenFaaS locally or in the cloud.
* Read the [Vert.x docs](https://vertx.io/docs/)
* Read the code for the [OpenFaaS Java11 templates](https://github.com/openfaas/templates)

> Acknowledgements: Thank you to [Paulo Lopes](https://github.com/pmlopes) from the Vert.x project for his input and guidance for this blog post and for the OpenFaaS Java templates.
