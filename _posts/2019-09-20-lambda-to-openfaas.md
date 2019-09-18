---
title: "Migrate Your AWS Lambda Functions to OpenFaaS"
description: Burton explains the steps for migrating an existing AWS Lambda function to OpenFaaS
date: 2019-09-10
image: /images/lambda-to-openfaas/birds.jpg
categories:
  - Lambda
  - tutorial
  - examples
author_staff_member: burton
dark_background: false
---

** DESCRIBE THE WHAT **

In this post, I'll walk you through the steps taken to migrate existing AWS Lambda functions to OpenFaaS compatible functions in order to allow easier local testing, familiar development process, and the freedom to use any number of other cloud providers without any code changes.

** TELL THE WHY **

AWS introduced the world to the idea of serverless architecture back in 2014 with the announcement of Lambda. The idea was that you could upload a zip file containing your code logic, and AWS would manage the infrastructure behind the scenes, billing you only for the time the code was being executed.

Not much has changed since then. You are still required to upload zip files (although there are now a growing list of tools to help obfuscate this), and the code must follow a very specific pattern in order for AWS to execute it.

** WALK THROUGH **

## Pre-requisites

- Existing AWS Lambda functions
- OpenFaaS 

** WHAT'S NEXT **

Move to MongoDB -> Full OSS Stack

** WHAT YOU'VE DONE AND WHY **

** LINKS **

Tutorial
OpenFaaS Cloud