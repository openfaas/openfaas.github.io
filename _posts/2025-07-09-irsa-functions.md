---
title: "Manage AWS Resources from OpenFaaS Functions With IRSA"
description: "We show you how to create AWS ECR repositories from a function written in Go using IAM Roles for Service Accounts."
date: 2025-07-09
author_staff_member: alex
categories:
- aws
- identity
- rbac
dark_background: true
image: "/images/2025-07-irsa/background.png"
hide_header_image: true
---

In this post we'll create a function in Golang that uses AWS IAM and ambient credentials to create and manage resources in AWS.

As a built-in offering, AWS Lambda is often used to respond to events and to manage AWS resources, so how does OpenFaaS compare?

OpenFaaS is a self-hosted platform that can run on any cloud or on-premises, including AWS EKS. Whilst AWS Lambda is a popular and convenient offering, it does have some tradeoffs and limitations which can cause friction for teams with more specialised requirements, workflows, or high usage ($$$).

If your team is developing code for Kubernetes using AWS EKS, then OpenFaaS can be a more natural fit than AWS Lambda, since it can use the same workflows, tools and processes you already have in place for your existing Kubernetes applications. That includes Helm, CRDs, Kubernetes RBAC, container builders in CI/CD and ArgoCD/Flux.

Both AWS Lambda and OpenFaaS can be used to manage resources within AWS, with either shared credentials which need to be created, managed and rotated by your team, or with ambient credentials which are automatically obtained at runtime by the function.

Our function will be used to create repositories in Elastic Container Registry (ECR). This is a common task for teams that run OpenFaaS in a multi-tenant environment, where each tenant or team publishes their own functions to the platform. It'll receive credentials using IAM Roles for Service Accounts (IRSA), which is the most modern way to map Kubernetes Service Accounts to native AWS IAM roles.

Contents:

* [Create an EKS cluster with IRSA enabled](#create-an-eks-cluster-with-irsa-enabled)
* [Install OpenFaaS Standard or For Enterprises](#install-openfaas-standard-or-for-enterprises)
* [IAM Policy for ECR Access](#iam-policy-for-ecr-access)
* [Create IAM Role and Service Account](#create-iam-role-and-service-account)
* [Create a function that uses the IAM Role](#create-a-function-that-uses-the-iam-role)
* [Invoke the function to create a new repository](#invoke-the-function-to-create-a-new-repository)
* [Wrapping up and next steps](#wrapping-up-and-next-steps)

## Create an EKS cluster with IRSA enabled

You may already have an AWS EKS cluster provisioned, if so, you can enable IRSA by following these instructions: [IRSA on EKS](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html).

If not, we can create a quick cluster using the [eksctl CLI tool](https://eksctl.io/):

```bash
eksctl create cluster \
    --name of-test \
    --with-oidc \
    --spot \
    --nodes 1 \
    --nodes-max 3 \
    --nodes-min 1 \
    --region eu-west-1
```

Whilst eksctl looks like an imperative CLI tool, it is a client that manages declarative CloudFormation templates under the hood. You'll see the one created for your cluster by navigating to CloudFormation page of the AWS console. Provisioning can take up to 15-20 minutes depending on how many nodes and add-ons you've selected.

## Install OpenFaaS Standard or For Enterprises

If you don't have OpenFaaS installed, you can follow the [OpenFaaS installation guide](https://docs.openfaas.com/deployment/pro/). If you already have OpenFaaS installed, you can skip this step.

For experimentation, you can use port-forwarding instead of setting up DNS and Ingress for the OpenFaaS gateway. It'll make it a bit quicker to get started.

## IAM Policy for ECR Access

We need to create an IAM Policy that will allow the OpenFaaS function to create and query repositories in ECR.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:CreateRepository",
        "ecr:DeleteRepository",
        "ecr:DescribeRepositories"
      ],
      "Resource": "*"
    }
  ]
}
```

You can create this role using the AWS CLI or the AWS Management Console. If you're using the CLI, you can run the following command:

```bash
aws iam create-policy \
  --policy-name ecr-create-query-repository \
  --policy-document file://ecr-policy.json
```

Note down the given ARN, i.e.

```
{
    "Policy": {
        "PolicyName": "ecr-create-query-repository",
        "Arn": "arn:aws:iam::ACCOUNT_NUMBER:policy/ecr-create-query-repository"
    }
}
```

## Create IAM Role and Service Account

The easiest way to create the IAM Role and Service Account is to use `eksctl`:

```bash
export ARN=arn:aws:iam::ACCOUNT_NUMBER:policy/ecr-create-query-repository

eksctl create iamserviceaccount \
  --name openfaas-create-ecr-repo \
  --namespace openfaas-fn \
  --cluster of-test \
  --role-name ecr-create-query-repository \
  --attach-policy-arn $ARN \
  --region eu-west-1 \
  --approve
```

This can also be done manually by creating the IAM Role in AWS, followed by a correctly annotated Service Account in Kubernetes using the `eks.amazonaws.com/role-arn` annotation.

## Create a function that uses the IAM Role

We are going to use Go to create this function. You can learn more about the Go template in the [OpenFaaS documentation](https://docs.openfaas.com/languages/go/).

AWS also has [SDKs available for other languages](https://docs.aws.amazon.com/sdkref/latest/guide/overview.html) supported by OpenFaaS such as Python, Java, Node.js, C#, etc.

Create a new function using the `golang-middleware` template:

```bash
export OPENFAAS_PREFIX=ttl.sh/openfaas

faas-cli new --lang golang-middleware ecr-create-repo
```


Edit the stack.yaml file to add an annotation stating which Kubernetes Service Account to use:

```diff
functions:
  ecr-create-repo:
+    annotations:
+      com.openfaas.serviceaccount: openfaas-create-ecr-repo
```

Set the region for the function, along with the URL of the ECR registry:

```diff
functions:
  ecr-create-repo:
+    environment:
+      AWS_REGION: eu-west-1
```

Add the AWS SDK for Go to the function as a dependency:

```bash
cd ecr-create-repo
go get github.com/aws/aws-sdk-go-v2/aws
go get github.com/aws/aws-sdk-go-v2/config
go get github.com/aws/aws-sdk-go-v2/service/ecr
```

You can learn more about the AWS SDK for Go in the [AWS documentation](https://docs.aws.amazon.com/sdk-for-go/v2/developer-guide/welcome.html).

Edit the functions handler to use the AWS SDK for Go:

```go
package function

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/ecr"
	"github.com/aws/aws-sdk-go-v2/service/ecr/types"
)

type CreateRepoReq struct {
	Name string `json:"name"`
}

type CreateRepoRes struct {
	Arn string `json:"arn"`
}

func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		input = body
	}

	var createRepoReq CreateRepoReq
	if len(input) > 0 {
		if err := json.Unmarshal(input, &createRepoReq); err != nil {
			http.Error(w, "Invalid request body", http.StatusBadRequest)
			return
		}
	}

	if len(createRepoReq.Name) == 0 {
		http.Error(w, "Missing in body: name", http.StatusBadRequest)
		return
	}

	cfg, err := config.LoadDefaultConfig(context.TODO(),
		config.WithRegion(os.Getenv("AWS_REGION")))
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	// Using the Config value, create the ECR client
	svc := ecr.NewFromConfig(cfg)

	// Check if the repository already exists
	if _, err := svc.DescribeRepositories(context.TODO(), &ecr.DescribeRepositoriesInput{
		RepositoryNames: []string{createRepoReq.Name},
	}); err != nil {
		log.Printf("Error describing repository: %s", err.Error())
		if !strings.Contains(err.Error(), "RepositoryNotFoundException") {
			http.Error(w, fmt.Sprintf("Failed to describe repository: %s", err.Error()), http.StatusInternalServerError)
			return
		}
	}

	// Create the repository
	createRes, err := svc.CreateRepository(context.TODO(), &ecr.CreateRepositoryInput{
		RepositoryName:     &createRepoReq.Name,
		ImageTagMutability: types.ImageTagMutabilityMutable,
		EncryptionConfiguration: &types.EncryptionConfiguration{
			EncryptionType: types.EncryptionTypeAes256,
		},
		ImageScanningConfiguration: &types.ImageScanningConfiguration{
			ScanOnPush: false,
		},
	})
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create repository: %s", err.Error()), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusCreated)

	createRepoRes := CreateRepoRes{
		Arn: *createRes.Repository.RepositoryArn,
	}
	json.NewEncoder(w).Encode(createRepoRes)
}
```

## Invoke the function to create a new repository

Now you can use curl to create a repository:

```bash
curl http://127.0.0.1:8080/function/ecr-create-repo \
  -d '{"name":"tenant1/fn1"}' \
  -H "Content-type: application/json"
```

The response contains the ARN of the repository, ready for you to use in something like the OpenFaaS Function Builder API to push a new image.

```json
{
    "arn": "arn:aws:ecr:eu-west-1:ACCOUNT_NUMBER:repository/tenant1/fn1"
}
```

You should see the repository created in AWS Console.

You can also verify this from the command line:

```bash
aws ecr list-images --repository-name tenant1/fn1 --region eu-west-1

aws ecr describe-repositories --repository-name tenant1/fn1 --region eu-west-1
```

## Wrapping up and next steps

In a very short period of time, we created a function using the `golang-middleware` template, added the AWS SDK for Go as a dependency, and used it to create a repository in ECR.

This is required step to push new images to an AWS ECR registry, and could form part of a CI/CD pipeline, or a multi-tenant functions platform.

With a few simple steps, you can take code in the form of a plain files, a zip file, tar file, or Git repository, and turn it into a function.

1. Create a tenant namespace using the [OpenFaaS Gateway's REST API](https://docs.openfaas.com/reference/rest-api/#create-a-namespace) i.e. `tenant`
2. Create a repository for the tenant's new function you want to build i.e. `tenant/fn1`
3. Use the [Function Builder's API](https://docs.openfaas.com/openfaas-pro/builder/) to publish the image to the full ARN path i.e. `ACCOUNT_NUMBER.dkr.ecr.eu-west-1.amazonaws.com/tenant1/fn1:TAG`
4. Post a request to the pOpenFaaS Gateway's REST API](https://docs.openfaas.com/reference/rest-api/#deploy-a-function) to deploy the function to the `tenant1` namespace

Highlights of this approach:

* The function operates with AWS IAM, using least privilege principles.
* The function obtains ambient credentials from the Kubernetes Service Account, using IRSA instead of shared, long-lived credentials.
* The function can be deployed to Kubernetes rapidly using the same workflows and tools you already use with Kubernetes.

To take things further, consider authentication options for the function.

1. [Built-in Function Authentication using OpenFaaS IAM](https://docs.openfaas.com/openfaas-pro/iam/function-authentication/).
2. Your own code in the handler to process an Authorization header with a static key or JWT token.

We wrote to the AWS API directly, however you can use the [Event Connectors for AWS SQS or SNS](https://docs.openfaas.com/openfaas-pro/sqs-events/) to receive events from other AWS services such as S3, DynamoDB, etc.

The same technique can be applied for other APIs such as the Kubernetes API, for when you want a function to obtain an identity to manage resources in one or more Kubernetes clusters: [Learn how to access the Kubernetes API from a Function](https://www.openfaas.com/blog/access-kubernetes-from-a-function/).

