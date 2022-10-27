---
title: "Serverless Node.js that you can run anywhere"
description: "Serverless doesn't have to mean using a function, bring your favourite micro HTTP framework with you"
date: 2020-12-02
image: /images/2020-11-nodejs/background.jpg
categories:
 - kubernetes
 - nodejs
 - javscript
 - serverless
 - containers
author_staff_member: alex
dark_background: true

---

Serverless doesn't have to mean using a function, bring your favourite micro HTTP framework with you.

## Introduction

It's hard to beat the convenience of a managed serverless product: plug in your code, and forget about servers and only get billed for what you use. Until recently using a cloud functions service meant packaging code in a [zip file](https://www.openfaas.com/blog/template-store/), and being subjected to a workflow that made testing locally very difficult.

This week we saw [AWS announce some changes to their AWS Lambda product](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/). Functions can now be uploaded using container images to an AWS Elastic Container Registry using `docker push`. This is a huge step forward for the community and means that Lambda functions could potentially be packaged and built in a similar way to other workloads. Before we get too excited, there are a few caveats to consider including the 15 minute execution limit and [an emulation shim](https://github.com/aws/aws-lambda-runtime-interface-emulator/) are required to make your code compatible.

In 2018 Google released their [Cloud Run](https://aws.amazon.com/blogs/aws/new-for-aws-lambda-container-image-support/) product, and made a very different choice to what we'd seen before. They decided to run container images and to make the interface as generic and portable as possible. To run a container on Cloud Run, it simply needs to serve HTTP traffic on port 8080. By some happy co-incidence, that was also how we designed OpenFaaS to work back in 2016 (to accept HTTP requests on a given port).

In this post we'll explore what a Serverless node.js function looks like and how that compares to using something like Express.js or Next.js. At the end I'll also link you to similar posts I've written for Golang HTTP servers, C# with ASP.NET and Python with Flask. I'll also explain some of the benefits of using OpenFaaS over doing everything yourself, manually.

### Option 1 - a Node.js "function"

First of all, we can write a function for Node.js using OpenFaaS' `node12` template, which also supports async/await.

OpenFaaS templates are stored in Git repositories, and can be found using `faas-cli template store list` or `faas-cli template store pull URL`. The `node12` template is one of [the standard templates](https://github.com/openfaas/templates/) and it can be forked and customised or used as-is. 

```bash
faas-cli new --lang node12 \
  --prefix alexellis2 \
  pdf-writer
```

You'll then get three files:

* `pdf-writer.yml` (can also be renamed to stack.yml)
* `pdf-writer/package.json` - standard package management with `npm`
* `pdf-writer/handler.js` - where you write your code

Unlike with AWS Lambda, you can return any content-type you like such as binary data.

The default handler:

```javascript
'use strict'

module.exports = async (event, context) => {
  const result = {
    'status': 'Received input: ' + JSON.stringify(event.body)
  }

  return context
    .status(200)
    .succeed(result)
}
```

Then you can for instance install a PDF generator:

```bash
cd pdf-writer
npm i --save pdfkit
```

Edit `handler.js`:

```bash
'use strict'
const PDFDocument = require('pdfkit')

module.exports = async (event, context) => {
  const payment = 100;

  let pdf = await createDocument(payment)
  return context
    .status(200)
    .headers({
      "Content-type": "application/pdf"
    })
    .succeed(pdf)
}

function createDocument() {
  return new Promise(resolve=> {
    const doc = new PDFDocument({
      size: "LEGAL",
      title: "OpenFaaS Invoice",
      author: "OpenFaaS Ltd"
    });

    const buffers = [];
    doc.on("data", buffers.push.bind(buffers));
    doc.on("end", () => {
      resolve(Buffer.concat(buffers));
    });

    let PAYMENT = 100;
    doc.text(`Invoice amount: ${PAYMENT}USD`);
    doc.end();
    });
}
```

Use `faas-cli up -f pdf-writer.pdf` to build an image, push it to your container registry and then deploy it.

When you invoke it, use the HTTP URL or `faas-cli invoke`

```bash
echo | faas-cli invoke pdf-writer > invoice.pdf

curl -sL http://127.0.0.1:8080/pdf-writer/ > invoice.pdf
```

### Option 2 - Dockerfile and express.js

The basic requirements for an OpenFaaS function are to serve HTTP on port 8080, and by default express.js will serve on port 3000. That is only going to require a very minor change to make any existing microservice work with OpenFaaS.

Let's write a minimal example?

```
faas-cli new --lang dockerfile \
  --prefix alexellis2 \
  express-svc
```

This time we get our YAML file as `express-svc` and a new folder `express-svc` where the Dockerfile and any files required for the build should be placed.

Overwrite the Dockerfile with your own custom logic:

```Dockerfile
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:12.13.0-alpine as ship

RUN apk --no-cache add curl ca-certificates \
    && addgroup -S app && adduser -S -g app app
WORKDIR /root/
ENV NPM_CONFIG_LOGLEVEL warn

RUN mkdir -p /home/app

WORKDIR /home/app
COPY package.json ./
RUN npm i

COPY . .

RUN npm test
WORKDIR /home/app/
RUN chown app:app -R /home/app && chmod 777 /tmp

USER app

CMD ["node", "index.js"]
```

Now let's initialise a new npm package and add express.js:

```bash
cd express-svc
npm init -y
touch index.js

npm i --save express
```

Now edit `express-svc/index.js`:

```javascript
const express = require('express')
const app = express()
const port = 8080

app.get('/', (req, res) => {
  res.send('Hello World!')
})

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`)
})
```

We can also provide a health-checking endpoint to be used for auto-scaling by adding another handler, or [override the HTTP healthcheck endpoint](https://docs.openfaas.com/reference/workloads/#custom-http-health-check) to use the main `/` route.

```yaml
...
functions:
  express-svc:
    lang: dockerfile
    handler: ./express-svc
    image: alexellis2/express-svc:latest
    annotations:
      com.openfaas.ready.http.path: /
```

Now simply run `faas-cli up -f express-svc.yml` and you'll be able to access your Express.js microservice.

```bash
curl http://127.0.0.1:8080/function/express-svc
Hello world!
```

### Option 3 - bring your own microservice framework

You can also bring your own microservices framework like [Next.js](https://nextjs.org/).

### Production - custom domains

The default route in OpenFaaS is convenient for testing and for receiving webhooks, but you can also create a vanity URL or remap your URLs to feel more like "REST".

You can use the FunctionIngress CRD to define custom domains such as:

```yaml
apiVersion: openfaas.com/v1
kind: FunctionIngress
metadata:
  name: express-svc
  namespace: openfaas
spec:
  domain: "express-svc.example.com"
  function: "express-svc"
  ingressType: "nginx"
  tls:
    enabled: true
    issuerRef:
      name: "letsencrypt-prod"
      kind: "Issuer"
```

For more see the docs: [TLS and custom domains for functions](https://docs.openfaas.com/reference/ssl/kubernetes-with-cert-manager/#20-tls-and-custom-domains-for-functions)

## Wrapping up

We've now explored two ways to write serverless Node.js applications - the first used a function handler, which meant we could forget about Dockerfiles and HTTP frameworks. The second example introduced some repetition and overhead with us having to manage a Dockerfile for each service, however this approach makes it easy to run existing services.

### So why use OpenFaaS?

You now know how to create a portable function that can be shipped in a container image. It can be run on Google Cloud Run if you need a managed experience, or for around 5-10 USD / mo with a VPS using [faasd](http://github.com/openfaas/faasd), or on your [Kubernetes cluster using the OpenFaaS helm chart](https://docs.openfaas.com/deployment/).

Your portable application can be invoked via HTTP, which is one of the most common use-cases we see, or through an event. OpenFaaS [supports a number of event triggers](https://docs.openfaas.com/reference/triggers/) out of the box, and we provide [an SDK](https://github.com/openfaas/connector-sdk) that you can use to connect to your own data-sources.

OpenFaaS also comes with a UI for an overview of your system, a queue for asynchronous invocations, scale to zero to lower resource consumption, metrics collection to monitor your services, easy secrets management and a REST API that can be used to deploy new versions of your functions.

* You're invited to our [4th Birthday celebration on 14th December](https://github.com/openfaas/faas/issues/1592) 🎂

### Taking it further

You can learn more about OpenFaaS using the LinuxFoundation's course: [Introduction to Serverless on Kubernetes](https://www.openfaas.com/blog/introduction-to-serverless-linuxfoundation/).

There are three similar tutorials I've written that show how to use microservices or a function-style approach with OpenFaaS:

* [Serverless Python 3 with functions or Flask](https://www.openfaas.com/blog/openfaas-flask/)
* [Simple Serverless with Golang Functions and Microservices](https://www.openfaas.com/blog/golang-serverless/)
* [Build ASP.NET Core APIs with Kubernetes and OpenFaaS](https://www.openfaas.com/blog/asp-net-core/)
