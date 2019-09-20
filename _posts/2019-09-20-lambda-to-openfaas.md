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

In this post, I'll walk you through the steps taken to migrate existing AWS Lambda functions to OpenFaaS compatible functions in order to allow easier local testing, familiar development process, and the freedom to use any number of other cloud providers without any code changes.

AWS introduced the world to the idea of serverless architecture back in 2014 with the announcement of Lambda. The idea was that you could upload a zip file containing your code logic, and AWS would manage the infrastructure behind the scenes, billing you only for the time the code was being executed.

In his talk [Welcome to Serverless 2.0](https://www.youtube.com/watch?v=JvXm-oHi5Mg) Alex Ellis described the new standard for serverless functions: Docker/OCI images exposing a port for execution, deployed to a Kubernetes cluster. This makes your functions completely portable and removes many of the limitations of the previous generation of serverless functions.

Without further ado, let's see what it takes to upgrade your AWS Lambda functions to OpenFaaS and Serverless 2.0!

## Prerequisites

- Existing AWS Lambda functions (optional)
  - For the tutorial, we'll be using the Lambda function in this [Github repository](https://github.com/burtonr/lambda-openfaas-blog)
- OpenFaaS 
  - Check the documentation for [how to deploy to Kubernetes](https://docs.openfaas.com/deployment/kubernetes/)
- OpenFaaS CLI
  - Check the documentation for [installation instructions](https://docs.openfaas.com/cli/install/)
- IDE, or other text editor
  - I recommend [Visual Studio Code](https://code.visualstudio.com/)

## AWS Lambda

The Lambda functions we'll be migrating are part of a URL shortener. One function creates and stores the shortened URL in DynamoDB, and the other function is responsible for looking up the destination URL, and redirecting the browser.

Let's have a look at the `shortener` function which creates and stores the shortened URLs:

```javascript
const AWS = require('aws-sdk');

const shortDomain = 'https://checkthisnow.net/'
let docClient = new AWS.DynamoDB.DocumentClient();

exports.handler = function (event, context, callback) {
    let originalUrl = JSON.parse(event.body).url || '';

    checkExists(originalUrl, function (exist) {
        if (!exist) {
            createAndStorePath(originalUrl, callback);
        } else {
            let shortenedURL = shortDomain + exist.token;
            let response = {
                isBase64Encoded: false,
                statusCode: 200,
                headers: {},
                body: JSON.stringify({
                    url: shortenedURL
                })
            };
            callback(null, response);
        }
    });
}

function checkExists(url, callback) {
    docClient.query(params, function (err, data) {
        ...
    });
}

function createAndStorePath(originalUrl, callback) {
    let path = generateToken();
    let shortenedURL = shortDomain + path;
    storeURL(path, originalUrl, function (err) {
        ...
    });
}

function generateToken(path = '') {
    ...
}

function storeURL(token, originalUrl, callback) {
    docClient.put(params, function (err, data) {
        ...
    });
}
```

A couple of things to note for this function code:
- The input comes as the `event` object and must be parsed before accessing the properties
- The DynamoDB `DocumentClient` doesn't require any additional parameters to connect
  - This is because AWS maps the execution environment to the account and IAM role when you create the function
- The response is an AWS defined object where the body must be converted to a `string`
- Not obvious from the code, but the `aws-sdk` does not need to be included in the `package.json` `dependencies` as it is included when the code is re-packaged for execution in Lambda.

There is also the additional configuration that is required in the AWS API Gateway:
- Creating each of the routes and methods
- Ensuring the request properties are configured properly to allow access to the request body
- In the case of the `redirecter` function: 
  - Creating the "Resource" variable `/{token}`
  - Adding each of the HTTP response codes
  - Mapping the response to the appropriate header values

All of this setup and configuration outside of the function code means that the function, while seemingly simple, can only be run within the AWS Lambda environment, and only after several other steps are performed.

## OpenFaaS

#### Create the New Function
Pull the Node.js + Express.js template to build from it:
```shell
$ faas-cli template store pull node10-express
```
Now, create the new "shortener" function:
```shell
$ faas-cli new shortener --lang node10-express
```
This will create a `shortener.yml` file, and a directory with the same name containing the sample function code to work from.

#### Migrate the Function Code
Copy the code from our Lambda function. Everything below the line: `exports.handler = function (event, context, callback) {`

and paste it in to the `handler.js` file, replacing everything below the line: `module.exports = (event, context) => {`

> You'll also need to copy over the `require` lines, and any `const` you've defined above the `exports.handler` line.

Since we want this new function to be portable, we'll need to add the `aws-sdk` to our dependencies in the `package.json` file by running the following command:
```shell
npm install aws-sdk
```

#### Use secrets
We're not moving all of our infrastructure off of AWS, so we'll continue to use DynamoDB. Again, since we want this function to be portable, we'll need to be able to use our AWS Access Key ID and AWS Secret Access Key associated with the same IAM account that our Lambda function was using.

First, you'll need to create a user in AWS with the role that the Lambda function was using. Check the box for "Programmatic access" so that the access keys will be generated. 

Download and save each of the access keys in separate files (with no new lines). We'll read from those files when creating the secrets to ensure that they aren't exposed in any history or logs.

Now, create Kubernetes Secrets for each of those values. You could use the `kubectl create secret ...` command, but to keep with the portability that comes with OpenFaaS, we'll use the OpenFaaS CLI:
```shell
$ faas-cli secret create shorturl-dynamo-key --from-file=./access-key-id
$ faas-cli secret create shorturl-dynamo-secret --from-file=./secret-access-key
```

To access these secrets in the function, add the following lines:
```javascript
let accessKeyId = fs.readFileSync("/var/openfaas/secrets/shorturl-dynamo-key").toString()
let secretKey = fs.readFileSync("/var/openfaas/secrets/shorturl-dynamo-secret").toString()
```

Pass them into the AWS SDK configuration so that the DynamoDB `DocumentClient` will have access to the table:
```javascript
AWS.config.update({
    credentials: {
      accessKeyId: accessKeyId,
      secretAccessKey: secretKey
    }
  });
```
Finally, we'll add the secrets to the function's `yml` file so that the function will be given the appropriate permissions to read the secret values
```yaml
functions:
  shortener:
    lang: node10-express
    ...
    secrets:
      - shorturl-dynamo-key
      - shorturl-dynamo-secret
```

Read more about [Unifying Secrets with OpenFaaS](/blog/unified-secrets) 

## Wrapping Up
We've migrated our function code from being restricted to only deployable on AWS Lambda infrastructure to being completely portable by using OpenFaaS. 

Additionally, this means that developers are able to test thier functions by deploying to a local Kubernetes cluster using Docker for Windows, Docker for Mac, [microk8s](https://johnmccabe.net/technology/projects/openfaas-on-microk8s/), or [KinD](https://blog.alexellis.io/be-kind-to-yourself/)

To further expand the portability, we could migrate the database to MongoDB for a full OSS stack!

#### Connect With the Community

  * [Join Slack now](https://goo.gl/forms/SqpLSdyzVoOboRqs1)
  * [Contribute](https://docs.openfaas.com/contributing/get-started/)
  * [Sponsor on GitHub](https://www.openfaas.com/support/)

## For More Information 
Learn the features of OpenFaaS in the [workshop](https://docs.openfaas.com/tutorials/workshop/)

[Build your own OpenFaaS Cloud with AWS EKS](/blog/eks-openfaas-cloud-build-guide)

[TLS & Custom Domains for your Functions](/blog/custom-domains-function-ingress/)

mTLS, Traffic Splitting, and more with [OpenFaaS and Linkerd2](https://github.com/openfaas-incubator/openfaas-linkerd2)
