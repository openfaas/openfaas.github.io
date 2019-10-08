---
title: "Migrate Your AWS Lambda Functions to Kubernetes with OpenFaaS"
description: Burton explains the steps for migrating an existing AWS Lambda function to OpenFaaS and Kubernetes to gain portability and additional functionality.
date: 2019-10-08
image: /images/lambda-to-openfaas/birds.jpg
categories:
  - lambda
  - aws
  - tutorial
  - migration
author_staff_member: burton
dark_background: false
---

In this tutorial, Burton explains the steps for migrating an existing AWS Lambda function to OpenFaaS and Kubernetes to gain portability and additional functionality.

AWS announced the Lambda feature at [re:Invent 2014](https://www.youtube.com/watch?v=9eHoyUVo-yg). The idea was that you could upload a zip file containing your code logic, and AWS would manage the infrastructure behind the scenes. They would then bill you only for the time the code was being executed.

In his talk [Welcome to Serverless 2.0](https://www.youtube.com/watch?v=JvXm-oHi5Mg), Alex Ellis describes a new standard for serverless functions: the ["Serverless 2.0 runtime contract"](https://docs.openfaas.com/reference/workloads/). This makes your functions completely portable and removes many of the limitations of the previous generation of serverless functions.

In this post, we'll walk through the steps taken to migrate existing AWS Lambda functions to OpenFaaS compatible functions in order to allow easier local testing, familiar development process, and the freedom to use any number of other cloud providers without any code changes. I'll show you how to migrate the compute to OpenFaaS, whilst continuing to use AWS services such as DynamoDB.

Let's see what it takes to upgrade your AWS Lambda functions to OpenFaaS and Serverless 2.0 using OpenFaaS

## Prerequisites

- An existing AWS Lambda functions (optional)
  - For the tutorial, we'll be using the Lambda function in this [Github repository](https://github.com/burtonr/lambda-openfaas-blog)
- OpenFaaS 
  - Check the documentation for [how to deploy to Kubernetes](https://docs.openfaas.com/deployment/kubernetes/)
- OpenFaaS CLI
  - Check the documentation for [installation instructions](https://docs.openfaas.com/cli/install/)
- A text editor, I recommend [VS Code](https://code.visualstudio.com/)

## Getting Started

To begin, let's look at the "hello world" sample function that gets created when you get started with Lambda. When you follow the [Getting Started Guide](https://docs.aws.amazon.com/lambda/latest/dg/getting-started-create-function.html) in the AWS documentation, a basic sample function is generated for you in Node.js 10.x as shown below:

```js
exports.handler = async (event) => {
    // TODO implement
    const response = {
        statusCode: 200,
        body: JSON.stringify('Hello from Lambda!'),
    };
    return response;
};
```

Let's examine the example for OpenFaaS. When you create a new function with the OpenFaaS CLI and the `node10-express` template, sample code is provided as shown here:

```js
"use strict"

module.exports = (event, context) => {
    let err;
    const result = {
        status: "You said: " + JSON.stringify(event.body)
    };
    context
        .status(200)
        .succeed(result);
}
```

At a glance, the two function samples are very similar. The main difference is in the invocation parameters. OpenFaaS passes in the `context` object which is used to provide additional context to the result. The context includes the properties `status`, `succeed`, `error`, and others that make discovering functionality and managing the response of the function easy without having to dig through pages of documentation.

As you can see, migrating the sample function from Lambda to OpenFaaS would be as easy as adding the `context` object to the invocation, and moving the values from the inline `response` object to the OpenFaaS included `context` object properties.

> You can see the documentation and other examples for the node10-express template [here](https://github.com/openfaas-incubator/node10-express-template).

Next, we'll work through a real-world Lambda function that includes IAM permissions to access a DynamoDB table.

## AWS Lambda

The Lambda functions we'll be migrating are part of a URL shortener. One function creates and stores the shortened URL in DynamoDB, and the other function is responsible for looking up the destination URL, and redirecting the browser. We've separated the operations between two functions so that the creation of the short URLs can be placed inside a private network in order to restrict who can create new shortened links.

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
_file source: [lambda/shortener/index.js](https://github.com/burtonr/lambda-openfaas-blog/blob/master/lambda/shortener/index.js)_

A couple of things to note for this function code:
- The input comes as the `event` object and must be parsed before accessing the properties
- The DynamoDB `DocumentClient` doesn't require any additional parameters to connect
  - This is because AWS maps the execution environment to the account and IAM role when you create the function
- The response is an AWS defined object where the body must be converted to a `string`
- Not obvious from the code, but the `aws-sdk` does not need to be included in the `package.json` `dependencies` as it is included when the code is re-packaged for execution in Lambda.

There is also the additional configuration that is required in the AWS API Gateway:
- Creating each of the routes and methods
- Ensuring the request properties are configured properly to allow access to the request body
- In the case of the `redirector` function: 
  - Creating the "Resource" variable `/{token}`
  - Adding each of the HTTP response codes
  - Mapping the response to the appropriate header values

All of this setup and configuration outside of the function code means that the function, while seemingly simple, can only be run within the AWS Lambda environment, and only after several other steps are performed.

## OpenFaaS

### Create the New Function

First, let's set an environment variable that OpenFaaS CLI will use to prefix the image names with our registry (Docker Hub) username

```sh
export DOCKER_USER="<your username>"
```

Pull the Node.js + Express.js template to build from it:

```sh
$ faas-cli template store pull node10-express
```

Now, create the new "shortener" function:

```sh
$ faas-cli new shortener --lang node10-express
```

This will create a `shortener.yml` file, and a directory with the same name containing the sample function code to work from. The `--prefix` flag will add your registry name to the image so that the image can be pushed

OpenFaaS uses the convention of having a `stack.yml` file that contains all of the function definitions to operate on. You can use the `--yaml` or `-f` flags to provide a differently named file, but for this post, we'll rename the generated yml file making the remainder of the commands simpler.

When we create the "redirector" function, we can pass the `--append` flag to automatically add the new function's definition to the existing file.

```sh
$ faas-cli new redirector --lang node10-express --append stack.yml
```

The resulting `stack.yml` file will look something like this:

```yaml
functions:
  shortener:
    lang: node10-express
    handler: ./shortener
    image: burtonr/shortener:latest
  redirector:
    lang: node10-express
    handler: ./redirector
    image: burtonr/redirector:latest
```
_file source: [openfaas/stack.yml](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/stack.yml)_

### Migrate the Function Code

Copy the code from our Lambda function. Everything below the line: `exports.handler = function (event, context, callback) {`

and paste it in to the `handler.js` file, replacing everything below the line: `module.exports = (event, context) => {`

You'll also need to copy over the `require` lines, and any `const` you've defined above the `exports.handler` line.

> The complete function code is available to view on [Github](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/shortener/handler.js)

Since we want this new function to be portable, we'll need to add the `aws-sdk` to our dependencies in the `package.json` file by running the following command:

```sh
npm install aws-sdk
```

> View the complete `package.json` file on [Github](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/shortener/package.json)

### Accessing DynamoDB

As mentioned in the introduction, we're only migrating the functions at this time. This means that we will need to be able to use that same IAM account for access to the DynamoDB table. There are two options available for using the existing IAM account that has permissions to access the data stored in the DynamoDB table. 
- Create an Access Key ID and Secret Access Key, store them as secrets, and pass them into the AWS SDK configuration. 
    - This allows the function to be run on any Kubernetes cluster that the secrets are stored. 
- Use an [IAM Service Account](https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/)
    - This requires running the function on an AWS EKS cluster

### Use secrets

If we want this function to be able to run on any Kubernetes cluster, we'll need to be able to use our AWS Access Key ID and AWS Secret Access Key associated with the same IAM account that our Lambda function was using.

> To learn more about DynamoDB, follow the [Getting Started with DynamoDB](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/GettingStartedDynamoDB.html) guide on AWS

First, you'll need to create a user in AWS with the role that the Lambda function was using. Check the box for "Programmatic access" so that the access keys will be generated. 

Download and save each of the access keys in separate files (with no new lines). We'll read from those files when creating the secrets to ensure that they aren't exposed in any history or logs.

Now, create Kubernetes Secrets for each of those values. You could use the `kubectl create secret ...` command, but to keep with the portability that comes with OpenFaaS, we'll use the OpenFaaS CLI:

```sh
$ faas-cli secret create shorturl-dynamo-key --from-file=./access-key-id
$ faas-cli secret create shorturl-dynamo-secret --from-file=./secret-access-key
```

To access these secrets in the function, add the following lines:

```javascript
let accessKeyId = fs.readFileSync("/var/openfaas/secrets/shorturl-dynamo-key").toString()
let secretKey = fs.readFileSync("/var/openfaas/secrets/shorturl-dynamo-secret").toString()
```
_file source: [/openfaas/shortener/handler.js](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/shortener/handler.js#L32)_

Pass them into the AWS SDK configuration so that the DynamoDB `DocumentClient` will have access to the table:

```javascript
AWS.config.update({
    region: 'us-west-1',
    credentials: {
        accessKeyId: accessKeyId,
        secretAccessKey: secretKey
    }
});
```

_file source: [/openfaas/shortener/handler.js](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/shortener/handler.js#L32)_

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
_file source: [openfaas/stack.yml](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/stack.yml)_

> Read more about [Unifying Secrets with OpenFaaS](/blog/unified-secrets)

### A note on the IAM Service Account in EKS

Using the AWS Elastic Kubernetes Service (EKS), you are able to assign an IAM role to a Kubernetes ServiceAccount. With OpenFaaS, you can assign that ServiceAccount to your function by adding an annotation to the function definition yaml file.

We won't go into the details of creating a Service Account, or how to add the IAM role here. That is well defined in the AWS blog [Introducing Fine-Grained IAM Roles for Service Accounts](https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/).

Below is the additions that would need to be added to the function's yaml file:
```yaml
functions:
  shortener:
    lang: node10-express
    ...
    annotations:
      com.openfaas.serviceaccount: "iamserviceaccount"
```
_file source: [openfaas/stack.yml](https://github.com/burtonr/lambda-openfaas-blog/blob/master/openfaas/stack.yml)_


### Code differences

Below is a picture of what the differences for the "shortener" function look like as seen from a `git diff` (here, using VSCode)

![Function Code Diff](/images/lambda-to-openfaas/code-diff.png)

- We added the `fs` module to be able to read the secrets
- Removed the `JSON.parse()` call, as the input is already in JSON format, so we are able to read the properties directly
- Call a new function `configureAWS()` before creating the new `DynamoDB.DocumentClient`
- Created a new function `configureAWS()` that reads the secrets, and sets the credentials and region for AWS
- Replaced the AWS specific response object with the template's `context`
- Set the `context.success` and `context.fail` status codes and values

If you look at the `git diff --stat` output, we actually removed more code than we added!

```sh
 1 file changed, 35 insertions(+), 37 deletions(-)
```

Also, notice that the AWS credentials are not in the code directly, so this function is still safe to commit to any repository without fear of leaking your credentials.

> Because of the changes made to configuring the aws-sdk and reading secrets, this migrated code will no longer run on Lambda

### Build and Deploy

Now that our function code is migrated, it's time to build and deploy it!

Both of these can be accomplished with the `faas-cli` tool. Optionally, with [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/), this can all happen automatically when the changes are pushed to Github or GitLab.

- Ensure your CLI is logged in to your cluster
```sh
$ echo $PASSWORD | faas-cli login --password-stdin
```

- Now, we're ready to build and deploy the container images.
```sh
$ faas-cli up
```

> The `up` command combines the `build`, `push`, and `deploy` commands into one cohesive operation.


### Invoking the Function

Now that your function has been deployed, it is available to be called via HTTP. OpenFaaS makes the functions available through the gateway URL

```sh
$ curl -d '{"url": "https://something.com/"}' http://127.0.0.1:8080/function/shortener
```

You can also invoke a function using the `faas-cli`

```sh
$ echo '{ "url": "https://something.com/" }' | faas-cli invoke shortener
```

Additionally, it is possible to call a function asynchronously by adjusting the URL route slightly by replacing `/function/` with `/async-function/`

```sh
$ curl -d '{"url": "https://something.com/"}' http://127.0.0.1:8080/async-function/shortener
```

This will return an immediate `202 Accepted` response and the function will be executed in the background.

> Read more about [Asynchronous Functions](https://docs.openfaas.com/reference/async/)


## Wrapping Up

We've migrated our function code from being restricted to only deployable on AWS Lambda infrastructure to being completely portable by using OpenFaaS. 

Additionally, this means that developers are able to test their functions by deploying to a local Kubernetes cluster using Docker for Windows, Docker for Mac, [microk8s](https://johnmccabe.net/technology/projects/openfaas-on-microk8s/), or [KinD](https://blog.alexellis.io/be-kind-to-yourself/)

To further expand the portability, we could migrate the database to MongoDB for a full OSS stack! An example of this can be found on [Alex's Repository](https://github.com/alexellis/mongodb-function)

### Connect With the Community

  * [Join Slack now](https://goo.gl/forms/SqpLSdyzVoOboRqs1)
  * [Start your first contribution](https://docs.openfaas.com/contributing/get-started/)
  * [Become and OpenFaaS Insider via GitHub Sponsors](https://insiders.openfaas.io/)

### For More Information 

Learn the features of OpenFaaS in the [workshop](https://docs.openfaas.com/tutorials/workshop/)

Learn how AWS Lambda and OpenFaaS can play well together with [faas-lambda](/blog/introducing-openfaas-for-lambda)

[Build your own OpenFaaS Cloud with AWS EKS](/blog/eks-openfaas-cloud-build-guide)

[TLS & Custom Domains for your Functions](/blog/custom-domains-function-ingress/)
