---
title: How to configure OpenFaaS functions to execute on AWS Lambda
description: In a follow up article Edward Wilde shows how to configure OpenFaaS functions to execute on AWS Lamda using the new faas-lambda provider.
date: 2019-06-25
image: /images/faas-quickstart/backdrop.jpg
categories:
  - lambda
  - automation
  - tutorial
author_staff_member: ed
dark_background: true
---

In this post we are going to follow the steps necessary to configure OpenFaaS to execute function on AWS Lambda using 
the new faas-lambda provider. See the previous blog post [announcing support for AWS Lambda] for an overview of the 
technology.


### Pre-requisites
To follow the steps in this article it is only necessary to have a Kubernetes cluster with Helm installed.

- [Kubernetes cluster](https://kubernetes.io/docs/setup/)
- [Helm installed](https://github.com/openfaas/faas-netes/blob/master/HELM.md)

### 1. Get an early access token
`faas-lambda` is currently in early access, please you the link below to get your access token

- [Create an access token](https://ewilde.o6s.io/faas-lambda-jwt-page)

### 2. Deploy OpenFaaS faas-lambda using helm

Installing OpenFaaS for Lambda requires the following high-level steps:

- Create a Kubernetes namespaces `openfaas` for the OpenFaaS system components.
- Create AWS IAM roles. One for the provider and one for deployed functions to inherit. 
- Allow the provider access to AWS using access key and secret, which are stored as Kubernetes secretes
- Deploy the OpenFaaS Helm chart using specific Lambda configuration options

#### 2.1. Create recommended namespaces
`$kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml`

#### 2.2. Create an OpenFaaS Provider IAM role
In order for the `faas-lambda` provider to communicate with the AWS Lambda service is needs the following minimum 
permissions:

**Minimum persmissions**

```javascript

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "LambdaPermissions",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "lambda:DeleteFunction",
                "lambda:GetAccountSettings",
                "lambda:GetAlias",
                "lambda:GetEventSourceMapping",
                "lambda:GetFunction",
                "lambda:GetFunctionConfiguration",
                "lambda:GetLayerVersion",
                "lambda:GetLayerVersionPolicy",
                "lambda:GetPolicy",
                "lambda:InvokeFunction",
                "lambda:InvokeAsync",
                "lambda:ListAliases",
                "lambda:ListEventSourceMappings",
                "lambda:ListFunctions",
                "lambda:ListLayers",
                "lambda:ListLayerVersions",
                "lambda:ListTags",
                "lambda:ListVersionsByFunction",
                "lambda:TagResource",
                "lambda:UpdateFunctionCode",
                "lambda:UpdateFunctionConfiguration"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMPermissions",
            "Effect": "Allow",
            "Action": [
                "iam:PassRole"
            ],
            "Resource": "*"
        }
    ]
}
```


##### 2.2.1. Recommended setup
- Create a [new IAM policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_create.html#access_policies_create-start), with the above minimum permissions. For example call this new policy `OpenFaaS Lambda Provider Policy`.
- Create a [new IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html), and assign it the above policy. For example call this new role `OpenFaaS Lambda Provider Role`. 
- Create a [new IAM user](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html), that will act as a service account for the `faas-lambda` provider i.e. `service-account-openfaas-lambda`. 
**Assign** the new IAM user the `OpenFaaS Lambda Provider Role`.
- Create [IAM access credentials](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html) using the new service account user.

#### 2.3. Create OpenFaaS Function IAM role
When an OpenFaaS functions executes in AWS Lambda it needs an IAM role. This role will give functions access to other
AWS services. Currently we only support one role that is assigned to all functions. In the future we will change this
to be per function. 

If your functions do not require access please follow the steps to create a [blank role](#232-no-access-function-iam-role)

##### 2.3.1. Restricted function IAM Role
Your requirements will be specific to you, in this example I am giving functions access to a particular s3 bucket:


```javascript
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CreateLogs",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        },
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::kubecon-2019",
                "arn:aws:s3:::containerdays-2019"
            ]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": [
                "arn:aws:s3:::kubecon-2019/*",
                "arn:aws:s3:::containerdays-2019/*"
            ]
        }
    ]
}
``` 

- Create a [new IAM policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_create.html#access_policies_create-start), with the above minimum permissions. For example call this new policy `OpenFaaS Lambda Function Policy`.
- Create a [new IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html), and assign it the above police. For example call this new role `OpenFaaS Lambda Function Role`. 

OR

##### 2.3.2. No access function IAM Role

```javascript
{
    "Version": "2012-10-17",
    "Statement": [
       {
           "Sid": "CreateLogs",
           "Effect": "Allow",
           "Action": [
               "logs:CreateLogGroup",
               "logs:CreateLogStream",
               "logs:PutLogEvents"
           ],
           "Resource": "*"
       }
    ]
}
``` 

- Create a [new IAM policy](https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_create.html#access_policies_create-start), with the above minimum permissions. For example call this new policy `OpenFaaS Lambda Function Policy`.
- Create a [new IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_create_for-user.html), and assign it the above policy. For example call this new role `OpenFaaS Lambda Function Role`. 

#### 2.4. Assign AWS access credentials to faas-lambda using Kubernetes secrets
This is a secure way to pass the AWS access credentials to the `faas-lambda` provider

```
$ export AWS_ACCESS_KEY_ID={value from step}
export AWS_SECRET_ACCESS_KEY={value from last step}

kubectl -n openfaas create secret generic lambda-aws-access \
   --from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
   --from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
```

#### 2.5. Deploy OpenFaaS helm chart


##### 2.5.1 Gather Helm configuration arguments

| Parameter                        | Description |
| -------------------------------- | ----------- |
| aws_region                       | AWS region that your Lambda functions will run in. For example `eu-west-1` |
| faaslambda.lambda_execution_role | IAM role to assign each function. See step 2.3. for more information   . |
| access_token                     | Early access token obtained from step 1. |
| access_email                     | Email address used when registering token from step 1. |


##### 2.5.2 Deploy chart

Below are the commands to clone and deploy the official OpenFaaS Helm chart, configured to deploy to AWS Lambda.
Please change the `--set` parameters `faaslambda.aws_region`, `faaslambda.lambda_execution_role`, `faaslambda.access_token` and
`faaslambda.access_email` with the values you gathered together in the previous step.

```bash
$ git clone git@github.com:openfaas/faas-netes.git
cd faas-netes
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update \
 && helm upgrade openfaas --install openfaas/openfaas \
                                     --namespace openfaas  \
                                     --set faaslambda.create=true \
                                     --set functionNamespace=openfaas-fn \
                                     --set faaslambda.aws_region=eu-west-1 \
                                     --set faaslambda.lambda_execution_role=arn:aws:iam::123456789012:role/openfaas-function-role \
                                     --set faaslambda.access_token=eyJhbGciOiJFUzI1NiIsImtpZCI6IktrVnV5a2VDMkJCenRUREVsSzh5XzNzNlludlBiTHAtRmQ1djY2TGxvUU0iLCJ0eXAiOiJKV1QifQ.eyJhdWQiOiJjb29sZ3V5QGdtYWlsLmNvbSIsImV4cCI6MTU2ODU0NDQyMywiaWF0IjoxNTYwNTk1ODMwLCJpc3MiOiJmYWFzLWxhbWJkYSIsIm5iZiI6MTU2MDU5NTgzMCwic3ViIjoiZWFybHktYWNjZXNzIn0.0cKLO7nkjGQYwjNaQY2OLJFLYpz0bHxB-9btAU9TRrblOO8-hpz1pDRSajwg_SiY0IVRVZfaJRLFqeVy4FS8dA \
                                     --set faaslambda.access_email=fredjones@gmail.com
```

### 3. Verifying the installation

#### 3.1 Main OpenFaaS components are running

```bash
$ kubectl get pods -n openfaas

kubectl get pods -n openfaas                                                                 290ms  Wed 26 Jun 08:06:38 2019
NAME                            READY   STATUS    RESTARTS   AGE
alertmanager-775d5cd49f-2sf2b   1/1     Running   0          8d
faas-idler-57b849dfd-k9rfv      1/1     Running   0          8d
gateway-59d9dbbf-6znm2          2/2     Running   0          8d
nats-75d8f56846-j2b4b           1/1     Running   0          8d
prometheus-5945df7857-rt2fw     1/1     Running   0          8d
queue-worker-5f96b567c5-pnsgd   1/1     Running   0          8d

$ faas-cli version

  ___                   _____           ____
 / _ \ _ __   ___ _ __ |  ___|_ _  __ _/ ___|
| | | | '_ \ / _ \ '_ \| |_ / _` |/ _` \___ \
| |_| | |_) |  __/ | | |  _| (_| | (_| |___) |
 \___/| .__/ \___|_| |_|_|  \__,_|\__,_|____/
      |_|

CLI:
 commit:  25cada08609e00bed526790a6bdd19e49ca9aa63
 version: 0.8.14

Gateway
 uri:     http://localhost:8083

Provider
 name:          faas-lambda
 orchestration: lambda
 version:       dev
 sha:           6de5591299665e5cd0b984b7e0ef195dd3e2d2ea
```

#### 3.2 Deploy your first OpenFaaS function to AWS Lambda

**Deploy function**
```bash
$ faas store deploy "SSL/TLS cert info"


Deployed. 200 OK.
URL: http://localhost:8083/function/certinfo

```

**Verify deployment**
```bash
$ aws lambda list-functions | jq '.Functions[].FunctionName' -r | grep certinfo
 
certinfo
```

**Invoke the function with the OpenFaaS CLI**
```bash
$ echo -n github.com | faas invoke certinfo                                                   2310ms  Wed 26 Jun 08:11:42 2019
  
  Host 140.82.118.4
  Port 443
  Issuer DigiCert SHA2 Extended Validation Server CA
  CommonName github.com
  NotBefore 2018-05-08 00:00:00 +0000 UTC
  NotAfter 2020-06-03 12:00:00 +0000 UTC
  NotAfterUnix 1591185600
  SANs [github.com www.github.com]
  TimeRemaining 11 months from now 
```

**Open the function in the AWS Lambda UI and test it**

![AWS Lambda console showing deployed function](/images/faas-quickstart/aws-console.png)


**Configure a test payload**
![AWS Lambda console showing deployed function](/images/faas-quickstart/aws-test-payload.png)

*Note:* the use of the `OpenFaaSValue` json property here, this is optional. If not used the entire payload is passed
to the function

**Run the AWS Lambda function**
![AWS Lambda test run showing output](/images/faas-quickstart/aws-test-run.png)

### 4. Troubleshooting

#### Supported templates
Currently we only support the following templates:

- python-flask27
- python-flask37
- node
- go