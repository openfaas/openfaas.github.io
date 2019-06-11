---
title: Announcing support to run OpenFaaS functions on AWS Lambda
description: Edward Wilde introduces faas-lambda a way to run OpenFaaS functions on AWS Lambda. Learn how simple container based functions can be deployed to AWS Lambda and Kubernetes with one seamless developer experience
date: 2019-05-24
image: /images/faas-lambda/backdrop.jpg
categories:
  - lambda
  - automation
  - tutorial
author_staff_member: ed
dark_background: true
---

In this post we are going to examine some of the possible use cases for running OpenFaaS functions on AWS Lambda.
Then we are going to take a look at some of the new components I've written to make this possible.
Finally I would like to ask the community for some feedback on these new ideas.


## What value is there in combining OpenFaaS with AWS Lambda?

There could be many great reasons to run OpenFaaS functions on Lambda. Here are some that I've
been considering:

- **CI/CD and a unified developer experience**
 
  
  Deploying AWS Lambda code normally requires a custom build and deployment pipeline. 
Faas-lambda gives you the potential to eliminate this duplication and extra effort.



- **Journey to multi-cloud**
  
  
  Perhaps you started out your cloud journey on AWS and are looking to become vendor neutral and run
on Kubernetes? Using faas-lambda you can port your existing functions to OpenFaaS and still run them on AWS Lambda
until you are ready to migrate them over to Kubernetes



- **Proprietary integrations**

  
  There are some integration points in the AWS architecture that mandate the use of Lambdas. 
However, there is no reason you can't create, manage and run these function using OpenFaaS with it's enhanced
developer experience.


## How does it work?
If we examine the diagram below, you can see that the
faas-lambda provider is a standard OpenFaaS component that implements the [gateway / provider contract](link).
The provider understands how to translate requests from the gateway into appropriate 
responses in the AWS Lambda world. In this architecture the faas-lambda provider runs inside a Kubernetes cluster
and using the go-lang AWS SDK communicates with the AWS Lambda service APIs. Credentials to enable that communication
are stored securely in Kubernetes as secrets, or if running on EKS it would be possible to remove the secrets and
use [IAM roles](https://github.com/uswitch/kiam).

![the faas-lambda provider architecture](/images/faas-lambda/faas-lambda-provider.png)

### Deploy a function
The challenge at deployment time is to take a docker image and transform it into an AWS Lambda package.
In order to achieve this, when the provider receives a deployment request, 
it needs to carry out the following steps shown in the diagram below:

![deploying a container using the faas-lambda provider](/images/faas-lambda/faas-lambda-deploy.png)

1. Using the [Skopeo](link to github) go-lang package we download the container image of the function
that is being deployed
2. Next, we extract each of the container layers using the image manifest information we've obtained from Skopeo.
3. Because the AWS Lambda function has a different handler signature, we need to create a small shim. 
This shim will allow the AWS Lambda service to call into our OpenFaaS function during invocation.
4. Finally, we need to make sure that all of the libraries the function depends on, are in the correct location
the AWS Lambda runtime will expect them to be in. Once that's done, we zip up the shim, original function
and libraries to create our AWS Lambda package.

### Invoke a function
This was an easier problem to solve. Using the AWS go-lang SDK, we call the lambda function, 
passing in the request body we received from the client. We wait for the function to complete and proxy back the response. 
You may have noticed that we've not needed to use the AWS API gateway. This can saving you money, reduce complexity
and allow your function to execute for up to 15 minutes, which is the current AWS Lambda limit. If you use API gateway the current
execution time is limited to 30 seconds. 

![invoking an OpenFaaS function on AWS Lambda](/images/faas-lambda/faas-lambda-invoke.png)

## Running AWS Lambda and Kubernetes functions together side by side
Our normal execution platform for OpenFaaS is Kubernetes. So that we can run functions on both AWS Lambda and Kubernetes, 
we needed to introduce a new component into the architecture. This component is called the
`faas-federator`.

![enable multiple execution platform with faas-federator](/images/faas-lambda/faas-federation-provider.png) 

The `faas-federator` component allows you to have one seamless developer, deployment and invocation experience. However we now have
the flexibility to target multiple execution platforms. We will explore federation in more detail in a future blog post. 

## Demo
Using OpenFaaS to deploy, manage and invoke functions to both Kubernetes and AWS Lambda:

{% include youtube.html id="Dv9BEQWnkRQ" %}

## What's next
This project is in early release. As such we would like to get feedback from the community:

- Please fill out this [this form](https://docs.google.com/forms/d/e/1FAIpQLSe9AfH-uCuK_tUeeRQWLe7_Ti-lbMF5iynwbdfszmB9NEttow/viewform) if you would like to try the new provider and let us know what other use cases you see for this?