---
title: "Build a Function Editor for Your Customer Dashboard"
description: "Let customers supply source code and have it run in a sandbox within your product."
date: 2025-05-29
author_staff_member: han
author_staff_member_editor: alex
categories:
 - functions
 - function-builder
 - integration 
dark_background: true
image: "/images/2025-05-function-editor/background.png"
hide_header_image: true
---

We wanted to show you how to build a Function Editor directly into your product’s dashboard so customers can supply code and have it run in a sandbox within your product.

When it comes to building and hosting functions outside of managed services like AWS Lambda or Google Cloud Functions, Kubernetes is the obvious option and many of you are already using it for your existing applications.

With [OpenFaaS for Enterprises](https://docs.openfaas.com/openfaas-pro/introduction/), we've built all the APIs needed to quickly and securely extend your application with FaaS capabilities. That includes multi-tenant functions, network segmentation, isolation per tenant in namespaces, non-root containers, and read-only file systems.

User functions can be further sandboxed with runtimes like [gVisor](https://gvisor.dev/) or [Kata Containers](https://katacontainers.io/) if desired.

![Screenshot of the OpenFaaS Function Editor main page](/images/2025-05-function-editor/function-editor.png)
> A demo you can [check out on GitHub](https://github.com/openfaas/function-editor-demo) to see how the various APIs are tied together to build customer functions

In this post we start by showing you a demo that we built in around half a day with the assistance of [Cursor](https://www.cursor.com/) and the OpenFaaS API documentation.
It has the following pages:

- Supply source code for the handler
- Supply packages i.e. package.json
- Invoke the function
- View the response including headers/body/timings
- View the logs from the function

Our demo is a single page app that focuses on editing only one function, however yours could list all available functions and customers could click on the one they want to edit, before seeing a similar page to this.

Let’s take a look at each page and discuss how it works and how you could implement something similar.

> Disclaimer: The demo application is suitable for development and testing only. You will need to add some form of suitable authentication if you intend to expose it on the Internet. We recommend running it on localhost, or exposing it via a tool that [can add authentication like Inlets](https://docs.inlets.dev/tutorial/http-authentication/).

See our other posts in the series on how to extend your platform with OpenFaaS for more details on how these features can be used:

- [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)
- [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)

## A quick tour of the sample

The sample application is composed of two main components: a frontend built with [React](https://react.dev/), and a backend API powered by [Express](https://expressjs.com/). Users interact with a browser-based code editor to modify a Node.js function directly within the UI. When they click the *Publish & Deploy* button, the function is packaged and deployed to OpenFaaS. Once deployed, users can navigate to the  *Test Function* page to invoke the function, view the output, and inspect the logs.

The application uses readily available OpenFaaS APIs to transform user-supplied source code into an OpenFaaS-compatible function image, which is then deployed to OpenFaaS to get a custom HTTP endpoint.

OpenFaaS components utilized:

- [Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/)

    Allows code to be submitted, built, and deployed seamlessly.

    This REST API accepts a Docker build context and publishes a container image to a remote registry.

- [OpenFaaS REST API](https://docs.openfaas.com/reference/rest-api/)

    API for managing and invoking functions, secrets and namespaces.

    The OpenFaaS REST API has endpoints to create and manage tenant namespaces, to deploy new functions, list and query existing ones, invoke them and query function logs.

### A place to write the code

The main interface of the app features a function editor powered by the [monaco-editor](https://github.com/microsoft/monaco-editor), offering users an in-browser code editor they can use to change the function handler code.

![Screenshot of the code editor](/images/2025-05-function-editor/edit-function-handler.png)

Currently, our implementation supports editing a single language. However, it's possible to extend this with a language selector that allows users to pick a different [language template](https://docs.openfaas.com/languages/overview/). You could allow users to pick one of the official OpenFaaS language templates, use your own template or even allow users to provide their own templates.

### Where you add the dependencies

For most languages you would want to provide users with some way to add extra dependencies to a function e.g. Python packages, npm packages or Go modules.

In this case we use a separate tab where users can modify the `package.json` file to add extra dependencies. For Python the equivalent would be to allow editing a `requirements.txt` file and for Go the `go.mod` file.

![Screenshot of the dependencies tab](/images/2025-05-function-editor/add-dependencies.png)

Depending on the requirements of your application you have the options to let users add any dependency they want, only allow a predefined set of packages or don't allow any extra dependencies at all.

### Build and deploy

When the users clicks the *Publish & Deploy* function the code, along with any additional information like the language template to use and `package.json` file is posted to the `/api/publish` endpoint on the backend server.

This endpoint is responsible for creating the build context and calling the [OpenFaaS Function Builder REST API](https://docs.openfaas.com/openfaas-pro/builder/) to build the code into a container image and publish that image into a registry.

After the build completes the `/api/deploy` endpoint on the backend server is called which uses the OpenFaaS API to deploy the function.

![Screenshot showing the build and deploy time in the UI](/images/2025-05-function-editor/build-and-deploy.png)

### Store source code

Something that we have not implemented in the sample application is storing of the function source code. The source code is built into a container image and deployed to the OpenFaaS cluster. When a user wants to edit an existing function you will need a way to retrieve the original function handler source.

We recommend storing the source code in an S3 bucket or database each time the function is published. This way it can be easily retrieved when a user wants to edit a function.

### Invoke functions and inspect responses

After a function has been deployed you probably want to provide users with some way to invoke and test functions. OpenFaaS functions are invoked over HTTP so in our sample application we have a separate *Test Function* page that presents users with a Postman-like interface to invoke functions.

![Screenshot of the request editor on the invocation page](/images/2025-05-function-editor/invoke.png)

The users can modify the request body and click the invoke button to invoke the function. A more advanced implementation might give users the ability to select an HTTP method and provide additional headers from the invocation request.

In the sample application function invocations are proxied through the backends `/api/invoke` endpoint. This would allow us to handle any custom authentication for the frontend app and gives the ability to inject extra headers if required. This is optional and functions can also be invoked directly through the OpenFaaS Gateway using the function endpoint, `http://<gateway_url>/function/<function_name>`.

Some general response info, like the status and response time is displayed along with any response headers and the response payload after the invocation completes.

![Screenshot of the response inspection card on the invocation page](/images/2025-05-function-editor/inspect-response.png)

Take a look at the [OpenFaaS Dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/) invocation page for inspiration on how a more advanced version of this page might look and work.

### Inspect Logs

Having access to function logs can be essential when trying to debug a function. Our application uses the [OpenFaaS APIs logs endpoint](https://docs.openfaas.com/reference/rest-api/#logs) to get logs for a function.

The API supports streaming logs using newline delimited JSON (ndjson) so you could stream logs in real time if desired.

![Screenshot of the function logs tab](/images/2025-05-function-editor/function-logs.png)

## A deep dive on the build and deployment process

**Call the OpenFaaS Builder API**

In our documentation we show [three ways to call the builder API](https://docs.openfaas.com/openfaas-pro/builder/#usage).

- Via faas-cli - for testing the initial deployment.
- via curl - to understand what's happening with bash.
- Via various code samples - to help you integrate with the API.

In our sample app the backend runs through the following steps to create the build context that is used to invoke the builder API.

1. Download the required template. Our application downloads and caches all supported templates once on startup. You can handle the downloading and caching of templates however you like.
2. Copy the source code and cached template to a temporary directory.
3. Call `faas-cli build --shrinkwrap` to create the build context.
4. Write the build configuration file, `com.openfaas.docker.config` to the functions build directory. The build configuration also includes the image reference used to publish the image to a registry. Make sure you generate a unique image tag for each rebuild of the function. We are using a random string but using a hash of the function handler could be a good alternative. 
5. Create a tar file from the shrinkwrapped function directory.
6. Call the builder API

This is a high level overview of what is going on. We have a blog post [How to build functions from source code with the Function Builder API ](https://www.openfaas.com/blog/how-to-build-via-api/) that describes and shows how to implement these steps in detail.

You might also want to take a look at our [Function Builder examples](https://github.com/openfaas/function-builder-examples), a sample repository that contains examples for preparing the build context and calling the Function Builder API from different languages.

**Deploy the function**

After the build has completed the `/api/publish` endpoint is called. This endpoint uses the [OpenFaaS API](https://docs.openfaas.com/reference/rest-api/#deploy-a-function) to deploy the function with the image we just built. The function name and image are the only two fields required to deploy the function. However there are many additional configuration parameters that can be included like environment variables, annotations, labels, CPU/memory constraints, and references to required secrets.

Many OpenFaaS features like [autoscaling](https://docs.openfaas.com/architecture/autoscaling/), [additional profiles](https://docs.openfaas.com/reference/profiles/), [HTTP health checks](https://docs.openfaas.com/reference/workloads/#custom-http-health-checks) etc, are all configured through these parameters.

Most of these parameters should be set by the backend code. You might want to expose some parameters like environment variables or some autoscaling labels to the users. These could be easily accepted through an additional form in the UI.

When integrating with the OpenFaaS API you can run the `faas-cli` with the `FAAS_DEBUG=1` environment variable to print out the HTTP REST calls behind commands to help with development and testing.

This is an example of a `stack.yaml` configuration that adds an environment variable, CPU/memory constraints, annotations for the cron-connector and the scale to zero label. We will run the `faas-cli deploy` with debug turned on to log the call the command makes to the OpenFaaS API.

```yaml
functions:
  greet:
    lang: node20
    handler: ./greet
    image: ttl.sh/openfaas/greet:0.0.1
    environment:
      - GREETING: "Hello"
    annotations:
      topic: cron-function
      schedule: "*/5 * * * *"
    labels:
      com.openfaas.scale.zero: "true"
    limits:
      memory: 40Mi
      cpu: 100m
    requests:
      memory: 20Mi
      cpu: 100m
```

Output of running the `faas-cli deploy` command:

```sh
FAAS_DEBUG=1 faas-cli deploy

Deploying: greet.
PUT http://127.0.0.1:8080/system/functions
Authorization: Basic REDACTED
Content-Type: [application/json]
User-Agent: [faas-cli/0.17.1]

{"service":"greet","image":"ttl.sh/openfaas/greet:0.0.1","envProcess":"node index.js","envVars":{"GREETING":"Hello"},"labels":{"com.openfaas.scale.zero":"true"},"annotations":{"schedule":"*/5 * * * *","topic":"cron-function"},"limits":{"memory":"40Mi","cpu":"100m"},"requests":{"memory":"20Mi","cpu":"100m"}}
```

We can see the CLI makes an HTTP PUT request to the `/system/functions` endpoint on the OpenFaaS Gateway. The JSON payload is printed out and can be used as a reference for calling the API from your own code.

## Next steps

### Try it out yourself

Full instructions to run the sample application yourself are available in the [GitHub repository](https://github.com/openfaas/function-editor-demo).

For more inspiration on how to integrate OpenFaaS, refer to our previous blog post to [see how other customers have embedded an editor into their UI](https://www.openfaas.com/blog/add-a-faas-capability/).

You may also like to take a look over [the official OpenFaaS Dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/) for inspiration. Whilst it doesn’t accept source code, it lists functions, allows you to invoke them, and read logs.

We showed how to use a web based editor to let users provide source code but you could also integrate with source control. Receive webhooks when code is committed and build and deploy functions in the background when code changes. Alternatively users could even provide code through your own CLI or Terraform module.

### Watch a video demo

In the video you'll see Alex build and invoke the default handler, then copy and paste in code from the OrcaScan documentation for a function which disallows barcodes from the "@openfaas.com" domain. He invokes the function with a sample payload, sees that the function rejects the payload then sends a new one from "@example.com" which is accepted.

<iframe width="560" height="315" src="https://www.youtube.com/embed/zkYaTgmldpo?si=Ka5PcR0pQyzYj5IY" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

### Contact us to find out more

Would you like to talk to our team about integrating OpenFaaS? Please get in touch via the [OpenFaaS for Enterprises form](https://docs.google.com/forms/d/e/1FAIpQLScFOsfabIDD5gZPs6XvsVWfqwV9kksI-B0FdtU5XdspB7Jk6A/viewform).

You may also like:

- [Integrate FaaS Capabilities into Your Platform with OpenFaaS](https://www.openfaas.com/blog/add-a-faas-capability/)
- [How to Build & Integrate with Functions using OpenFaaS](https://www.openfaas.com/blog/integrate-with-openfaas/)
- [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)
- [Bill your users for their usage with chargeback for OpenFaaS](https://www.openfaas.com/blog/chargeback-billing/)
