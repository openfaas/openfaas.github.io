---
title: "How to integrate OpenFaaS functions with managed AWS services"
description: "Trigger OpenFaaS functions based upon many different types of events generated in AWS using an AWS SNS subscription."
date: 2023-01-19
image: /images/2023-integrate-openfaas-with-managed-aws-services/background.jpg
categories:
- aws
- sns
- functions
- triggers
author_staff_member: han
---
Trigger OpenFaaS functions based upon many different types of events generated in AWS using an AWS SNS subscription.

## Introduction

OpenFaaS uses connectors to map one or more topics, subjects or queues from a stateful messaging system or event-source to a number of functions in your cluster. With the connector pattern, you can trigger functions from any event-source or messaging system, without having to add SDKs or subscription code to each of your functions.

The [SNS connector](https://docs.openfaas.com/reference/triggers/#aws-sns) is the latest addition to our list of available event connectors. With the SNS connector you can trigger OpenFaaS functions based upon many different types of events generated in AWS:

- EC2 Image builder - receive notifications when builds are completed.
- S3 - trigger OpenFaaS functions when a new file is uploaded to a bucket.
- AWS IoT events - receive notification from your fleet of devices.

For all possible integrations checkout the list of available [Amazon SNS event sources](https://docs.aws.amazon.com/sns/latest/dg/sns-event-sources.html).

The SNS connector could be used to communicate to OpenFaaS functions from existing microservices or systems on AWS or even to get messages from partners where you give them access to an SNS topic with publish-only access.

In addition to the SNS connector we offer some other connectors that can help you integrate with AWS.

With the Postgres connector users can trigger functions whenever changes are made to a database table. We have a post thats walks you through setting up the connector with AWS Aurora: [Trigger OpenFaaS functions from PostgreSQL with AWS Aurora](https://www.openfaas.com/blog/trigger-functions-from-postgres/)

We also have the [SQS connector](https://docs.openfaas.com/reference/triggers/#aws-sqs) available for AWS users. It can be used to trigger functions from messages published on AWS SQS queues.

![Event-connector pattern](https://docs.openfaas.com/images/connector-pattern.png)
> Pictured: Event-connector pattern. Each topic, subject or queue can be broadcast to one or many functions.

## SNS connector

With the SNS connector AWS SNS subscriptions can be used to trigger OpenFaaS functions.

When the connector is started it will create a subscription on the configured SNS topic. It will automatically verify the subscription and start listening for notifications messages.

When a notification message  is received it will parse the message and invoke any function that has registered their interest in the topic. The message body is used as the request body. SNS metadata and the message attributes or passed on as headers on the HTTP request.

> For detailed usage and installation instructions checkout the [SNS connector docs](https://docs.openfaas.com/openfaas-pro/sns-events/)

How is this better than subscribing and receiving SNS messages directly in a function?

- The connector handles the subscription lifecycle for you.
- Multiple functions can receive notifications from the same topic without having to create a subscription for each function.
- You don't need to set up ingress for every function that has to receive notifications.

Additionally the connector provides some safety features you would otherwise have to handle yourself in each function. To receive notifications the subscription endpoint needs to be publicly accessible. The connector verifies the authenticity of each Amazon SNS message it receives to prevent spoofing attacks on the public callback endpoint.

## Trigger OpenFaaS functions on S3 event notifications

A common use case we hear from our customers is triggering OpenFaaS workflows on S3 events.

Some use-cases might be for you to:

- Run an AI model each time a file is uploaded to a bucket.
- Trigger an image processing workflow when a new image is uploaded.
- Decrypt files for Extract Load Transform (ETL).
- Chunking large files into smaller pieces for processing.

In this section we will walk through a brief example of how to use the SNS connector to receive event notification form S3 and trigger OpenFaaS functions.

### Setup the required AWS services

To configure an S3 bucket for SNS notifications we need to:

1. Create an S3 bucket
2. Create an SNS topic
3. Add a notification configuration to the bucket

Create a new S3 bucket using the aws-cli or console. We will name it `incoming-images-bucket`.

```bash
aws s3api create-bucket --bucket incoming-images-bucket --region eu-central-2
```

Create an Amazon SNS topic that will be used for bucket notifications:

```bash
aws sns create-topic --name s3-event-notification-topic --region eu-central-2
```

We need to replace the access policy attached to the topic with the following policy so that the S3 bucket can publish messages to it:

```bash
export BUCKET_OWNER_ID=""

cat > topicpolicy.json <<EOF
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:*:*:s3-event-notification-topic",
        "Condition":{
            "ArnLike":{
                "aws:SourceArn": "arn:aws:s3:*:*:incoming-images-bucket"
            },
            "StringEquals": {
                "aws:SourceAccount": $BUCKET_OWNER_ID
            }
        }
    }]
}
EOF
```

Replace the topic policy:

```bash
export TOPIC_ARN=""

aws sns set-topic-attributes \
    --topic-arn $TOPIC_ARN \
    --attribute-name 'Policy' \
    --attribute-value file://topicpolicy.json
```

As a last step we need to add a notification configuration to the bucket. This can be done in the [S
3 console](https://s3.console.aws.amazon.com/s3/).

1. Open the console and select your bucket. Under the properties tab scroll down the "Event notifications" section and click on "Create event notification".
2. Fill in the general configuration. Give the event a name and optionally filter on suffix or prefix.
3. Select the types of events you want to receive notifications for. In this example we want to receive notifications for all object create events.

    ![select-event-notification](/images/2023-integrate-openfaas-with-managed-aws-services/notification-event-types.png)

4. As a last step select SNS as the destination for events and specify the SNS topic.

    ![select-event-destination](/images/2023-integrate-openfaas-with-managed-aws-services/notification-destination.png)

> [A walkthrough to configure a bucket for notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/ways-to-add-notification-config-to-bucket.html) is also available in the S3 user guide.

### Install the OpenFaaS Pro SNS connector

In this section we will deploy the SNS connector in our OpenFaaS cluster.

> All installation instructions can also be found in the [SNS connector docs](https://docs.openfaas.com/openfaas-pro/sns-events/)

Create an AWS credentials secret for the SNS connector:

```bash
$ kubectl create secret generic -n openfaas \
  aws-sns-credentials --from-file aws-sns-credentials=$HOME/sns-credentials.txt
```

You can configure permissions using a dedicated IAM user. The user needs a policy that grants access to the `Subscribe` and `ConfirmSubscription` actions. For more information see: [Using identity-based policies with Amazon SNS](https://docs.aws.amazon.com/sns/latest/dg/sns-using-identity-based-policies.html)

Create a `snsconnector.yaml` file to use with helm:

```bash
# Public callback URL for subscriptions
callbackURL: "http://sns.example.com/callback"

# SNS topic ARN for the sns event notifications
topicARN: "arn:aws:sns:eu-west-2:123456789012:s3-event-notification-topic"

awsRegion: "eu-west-2"
```

To receive http calls from AWS SNS the callback url has to be publicly accessible. The [Helm chart README](https://github.com/openfaas/faas-netes/tree/master/chart/sns-connector#configure-ingress) has an example of how to setup Ingress for the connector with a TLS certificate using Ingress Nginx.

Now deploy the connector using the Helm chart:

```bash
$ helm repo add openfaas https://openfaas.github.io/faas-netes/
$ helm upgrade sns-connector openfaas/sns-connector \
    --install \
    --namespace openfaas
    -f snsconnector.yaml
```

You can check the connector logs to verify if the SNS subscription was created successfully:

```bash
$ kubectl logs -n openfaas deploy/sns-connector -f

OpenFaaS sns-connector Pro      Version: 0.0.2  Commit: 50da440c52d94b3130b1cb2da25379b7fe7b0e2f

2023-01-18T15:18:55.246Z        info    sns-connector/main.go:125       Licensed to: Han <support@openfaas.com>, expires: 47 day(s) Products: [inlets-pro openfaas-pro openfaas-enterprise openfaas-pro/builder]
2023-01-18T15:18:55.246Z        info    sns-connector/main.go:143       Using AWS shared credentials file: /var/secrets/aws-credentials/aws-sns-credentials
2023-01-18T15:18:55.599Z        info    sns-connector/main.go:200       Requested subscription  {"callbackURL": "https://sns.example.com/callback"}
```

### Upload a file and trigger functions

The [printer function](https://github.com/openfaas/store-functions/blob/master/printer/handler.go) can be used to help with testing and debugging function invocations. It prints out the HTTP headers and body of any invocation.

The printer function is available in the function store and can be deployed with the faas-cli:

```bash
faas-cli store deploy printer \
  --annotation topic=arn:aws:sns:eu-west-2:123456789012:s3-event-notification-topic
```

The function registers interest in events by setting the `topic` annotations. This annotation is used by event connectors to know which functions they should invoke. For the SNS connector the topic annotation has to be set to the ARN of the SNS topic.

Use the S3 console or aws-cli to upload a file to your bucket.

The notification message can be inspected by looking at to logs of the printer function:

```bash
$ faas-cli logs printer

2023-01-18T15:27:47Z Accept-Encoding=[gzip]
2023-01-18T15:27:47Z Content-Type=[text/plain]
2023-01-18T15:27:47Z X-Forwarded-For=[10.42.1.231:43056]
2023-01-18T15:27:47Z X-Forwarded-Host=[gateway.openfaas:8080]
2023-01-18T15:27:47Z X-Sns-Message-Id=[e1aed93a-623b-5269-9f16-85787008e915]
2023-01-18T15:27:47Z X-Sns-Arn=[arn:aws:sns:eu-west-2:123456789012:s3-event-notification-topic]
2023-01-18T15:27:47Z X-Start-Time=[1674055667361030016]
2023-01-18T15:27:47Z X-Call-Id=[c01cda83-c78e-48b8-ba83-7bb5d2d51422]
2023-01-18T15:27:47Z X-Topic=[arn:aws:sns:eu-west-2:123456789012:s3-event-notification-topic]
2023-01-18T15:27:47Z User-Agent=[Go-http-client/1.1]
2023-01-18T15:27:47Z X-Connector=[connector-sdk openfaasltd/sns-connector]
2023-01-18T15:27:47Z X-Sns-Subject=[Amazon S3 Notification]
2023-01-18T15:27:47Z 
2023-01-18T15:27:47Z {"Records":[{"eventVersion":"2.1","eventSource":"aws:s3","awsRegion":"eu-west-2","eventTime":"2023-01-18T15:27:45.912Z","eventName":"ObjectCreated:Put","userIdentity":{"principalId":"A26RER3021T3D3"},"requestParameters":{"sourceIPAddress":"109.236.137.209"},"responseElements":{"x-amz-request-id":"YZCHJQ9CSEJFND46","x-amz-id-2":"39jfrLiq1/a87nv/R+eDaNv3eRfUBushAeRZv4vW4hU+pCq48gd3tYXwIUWvOYiebM1zAzru8Km6bSqTlpEprllENjLsbDDG"},"s3":{"s3SchemaVersion":"1.0","configurationId":"tf-s3-topic-20230118151447219100000001","bucket":{"name":"incoming-images-bucket-20231801","ownerIdentity":{"principalId":"A26RER3021T3D3"},"arn":"arn:aws:s3:::incoming-images-bucket-20231801"},"object":{"key":"teamserverless.png","size":205501,"eTag":"bee8e11690c13dc7ad6db054a8375b44","sequencer":"0063C80FF1CE707C44"}}}]}
2023-01-18T15:27:47Z 
2023-01-18T15:27:47Z 2023/01/18 15:27:47 POST / - 202 Accepted - ContentLength: 0B (0.0013s)
```

We used the `printer` function to inspect the body and headers received from a S3 bucket notification. The same event could be parsed and used to trigger one of the workflows we mentioned earlier.

## Conclusion
We showed you how Amazon SNS notifications can be used to trigger OpenFaaS functions using the SNS connector. 

A lot of different Amazon services can publish events to SNS topics. If you are an AWS user this can be a quick way to integrate OpenFaaS with your existing services.

In case the your service you is not listed in the available [Amazon SNS event sources](https://docs.aws.amazon.com/sns/latest/dg/sns-event-sources.html) there are some other options to consider:

- If the service supports publishing messages to AWS SQS you can use the [OpenFaaS connector for SQS](https://docs.openfaas.com/reference/triggers/#aws-sqs)
- Use Lambda functions as a bridge between the service and SNS. This can for example be used to trigger OpenFaaS functions when a record in DynamoDB is updated. This tutorial can help you create the Lambda connector function: [DynamoDB Streams to SNS](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/Streams.Lambda.Tutorial.html)

Make sure to take a look at the other triggers [available for OpenFaaS](https://docs.openfaas.com/reference/triggers/#additional-triggers)

You may also like:

- [Trigger OpenFaaS functions from PostgreSQL with AWS Aurora](https://www.openfaas.com/blog/trigger-functions-from-postgres/)
- [Staying on topic: trigger your OpenFaaS functions with Apache Kafka](https://www.openfaas.com/blog/kafka-connector/)
- [Event-driven OpenFaaS with Managed Kafka from Aiven](https://www.openfaas.com/blog/openfaas-kafka-aiven/)