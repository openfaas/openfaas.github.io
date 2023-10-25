---
title: "How to migrate Python functions from AWS Lambda to OpenFaaS and Kubernetes"
description: "This guide will show you how to migrate existing AWS Lambda functions to OpenFaaS running on LKE"
date: 2023-10-26
categories:
- openfaas
- akamai
- linode
- lambda
dark_background: true
image: "/images/2023-10-migrate-lambda-functions/background.png"
author_staff_member: han
hide_header_image: true
---

In this guide we'll show you how to migrate existing AWS Lambda functions to a Akamai Cloud Computing LKE cluster with OpenFaaS.

AWS Lambda was introduced by Amazon in 2014 and popularized the Functions As a Service (FaaS) model. OpenFaaS is one of the earliest FaaS frameworks for Kubernetes. 

Here's what people tend to value in OpenFaaS over a hosted functions service:

* Portability - it can be installed on any cloud where there is a managed Kubernetes service, or into VMs or on bare-metal using K3s, as well as on-premises
* Developer experience - you can write functions in any language, and they build into container images, meaning you get the same experience on your laptop as in production
* Ecosystem - there are dozens of language templates, and you can write your own too, so long as it works in Docker, it's fair game. You'll also find plenty of sample functions in the Function Store
* REST API - the REST API is a first-class citizen, and you can use it to deploy functions, invoke them, and even to get metrics and logs
* Predictable costs - whether you're using an open source version or a commercial version, the cost per month is exactly the same and doesn't increase with usage, in these times that's a big deal for CFOs and budget holders

In this article we will take a look at the differences and similarities between OpenFaaS and AWS Lambda an show what it takes to migrate a Python function from one platform to the other.

We will work through migrating a real-world extract, transform, and load (ETL) workflow from AWS to Linode with OpenFaaS.

## Lambda functions vs OpenFaaS functions

Lambda has the concept of runtimes, OpenFaaS has the concept of templates, and can run any container that serves HTTP or can be invoked as a CLI.

Below, we compare the python3-http OpenFaaS template to the Lambda "python 3.11" runtime.

Let's start by looking at a simple Lambda function that accesses some request parameters like headers and the http method. 

```python
def lambda_handler(event, context):
    # Get request data from the event
    method = event['requestContext']['http']['method'],
    requestBody = event['body']
    contentType = event['headers'].get('content-type')

    return {
        "statusCode": 200,
        "body": {
            "method": method,
            "request-body": requestBody,
            "content-type": contentType
        }
    }
```

AWS Lambda functions can be triggered from different sources:

- Events happening on other AWS services (e.g. S3 bucket notifications)
- REST calls to an AWS API Gateway
- A schedule in Amazon CloudWatch Events
- A direct API call

The event object will be different depending on the source that triggered the function. In this example we are handling an event triggered by a direct API call to the lambda function.

Now let's compare this Lambda function to an equivalent OpenFaaS function. In this case the OpenFaaS function uses the [python-http template](https://github.com/openfaas/python-flask-template) which is our recommended template for creating Python functions.

```python
def handle(event, context):
    # Get request data from the event
    method = event.method,
    requestBody = str(event.body, 'utf-8')
    contentType = event.headers.get('content-type')

    return {
        "statusCode": 200,
        "body": {
            "method": method,
            "request-body": requestBody,
            "content-type": contentType
        }
    }
```

Similar to the Lambda function the handler is passed two arguments, event and context.

While the structure and type of the Lambda event can be different depending on the trigger, OpenFaaS functions are always invoked using HTTP. The event always contains the same data about the request: body, headers, method, query and path.

The default method of invoking OpenFaaS function is over HTTP. Like AWS Lambda OpenFaaS also supports triggering functions from different event sources through [connectors](https://docs.openfaas.com/reference/triggers/#triggers). Some of our popular connectors include: Apache Kafka, AWS SQS or cron if a function needs to be invoked on a schedule.

As you can see Lambda and OpenFaaS functions look very similar. To migrate simple functions you would only need to update your code to handle the different format of the event and context objects.

**Building and deploying**

To deploy a function on Lambda a function's compiled code or scripts and their dependencies need to be built into a deployment package. Lambda supports two types of deployment packages, container images and zip file archives. A deployment package has to be uploaded to S3 or ECR and can then be used to deploy a function.

The main tool to interact with OpenFaaS and build and deploy functions is the [faas-cli](https://github.com/openfaas/faas-cli). The CLI uses Docker to build functions from a [set of supported language templates](https://docs.openfaas.com/languages/overview/). You can also [create your own templates](https://docs.openfaas.com/languages/custom/) or build functions from a [custom Dockerfile](https://docs.openfaas.com/languages/dockerfile/). This means that you can use any programming language or toolchain that can be packaged into a container image.

Lambda:

- Use one of the supported runtimes to create a function.
- Bundle function code and dependencies into deployment packages, either a zip file archive or container images based on one of the Lambda base images.
- Manual steps to upload layers to S3 or images to ECR and deploy and configure a function.
- It can be hard to test functions locally.
- Hard limits for functions, e.g. the maximum runtime for container deployments is 15 minutes.

There are CLIs and tools available that automate some of these steps and provide a way to bundle configuration in a file, e.g. [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html
)

OpenFaaS:

- Supports any programming language or toolchain that can be packaged into a container image.
- Build and deploy functions using the `faas-cli`. Build and deployment configuration is provided through a `stack.yml` configuration file.
- Function can be tested locally using `faas-cli local-run`. It is easy to spin up an OpenFaaS cluster locally or use faasd to test functions.
- No hard limits on image size, maximum runtime or function resources.

In the next section we will show you how to deploy an OpenFaaS cluster and walk through the steps required to migrate a real-world workflow from Lambda to OpenFaaS.

## Deploy OpenFaaS on Linode Kubernetes Engine (LKE)

Let's start be setting up an OpenFaaS cluster. We will be using a managed LKE cluster on Akamai Cloud to deploy OpenFaaS.

A new cluster can be created from the [Linode dashboard](https://cloud.linode.com/kubernetes/clusters). Follow their [getting started guide](https://www.linode.com/docs/products/compute/kubernetes/get-started/) to setup the Kubernetes cluster.

> Did you know? Linode was acquired by Akamai, and is now being branded as "Akamai Cloud Computing".
> The rebranding is still in-progress, so we'll be referring to Linode throughout this article.

For this tutorial I created a 3 node cluster with 4GB of RAM and 2 CPUs per node.

Once you have a cluster deployed an verified you are able to access it move on to the next section to install OpenFaaS.

### Install OpenFaaS

Install OpenFaaS on the cluster. Choose either the [Community Edition (CE)](https://docs.openfaas.com/deployment/kubernetes/) which is intended for development or proof of concepts.

For production and commercial use you should deploy [OpenFaaS Standard or OpenFaaS for Enterprises](https://docs.openfaas.com/deployment/pro/).

CE can be installed relatively quickly with our [arkade](https://github.com/alexellis/arkade) tool, which is a wrapper for the Helm chart, but you can also use the [OpenFaaS Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart) directly, if you prefer.

```bash
arkade install openfaas
```
You can now run `arkade info openfaas` to get the instructions to log in with the CLI and to how to get the password to access the UI.

To follow along with this tutorial you can use the suggested port-forwarding instructions printed out by the info command to access the OpenFaaS gateway.

> If you want to use a TLS-enabled URL to access OpenFaaS and your functions follow the instructions from the "Setup Ingress" and "Install OpenFaaS" sections in our blog post: [How to set up production-ready K3s with OpenFaaS with Akamai Cloud Computing](https://www.openfaas.com/blog/production-faas-linode/)

## Migrate an ETL workload

Most of the time your Lambda functions wil probably use IAM to access other AWS services and have additional dependencies like Python packages or other native dependencies. We will show you what it takes to turn an exiting Python Lambda function into an OpenFaaS compatible function.

The ETL workflow we will be migrating is a video transformation pipeline. A function fetches video and creates a short preview of the input by sampling frames throughout the video and stitching then back together to create the output video.

<!-- Add diagram for workflow -->

Let's start by taking a look at the Lambda function.

```python
import os
import logging
import tempfile
import urllib
import ffmpeg
import boto3

from .preview import generate_video_preview, calculate_sample_seconds

s3_client = boto3.client('s3')

samples = os.getenv("samples", 4)
sample_duration = os.getenv("sample_duration", 2)
scale = os.getenv("scale")
format = os.getenv("format", "mp4")

s3_output_prefix = os.getenv("s3_output_prefix", "output")
debug = os.getenv("debug", "false").lower() == "true"

def handler(event, context):
    s3_bucket_name = event['Records'][0]['s3']['bucket']['name']

    key = urllib.parse.unquote_plus(event['Records'][0]['s3']['object']['key'], encoding='utf-8')

    file_name, _ = os.path.basename(key).split(".")
    output_key = os.path.join(s3_output_prefix, file_name + "." + format)
    out_file = tempfile.NamedTemporaryFile(delete=True)

    try:
        input_url = s3_client.generate_presigned_url('get_object', Params={'Bucket': s3_bucket_name, 'Key': key}, ExpiresIn=60 * 60)
    except Exception as e:
        logging.error("failed to get presigned video url")
        raise e

    try:
        probe = ffmpeg.probe(input_url)
        video_duration = float(probe["format"]["duration"])
    except ffmpeg.Error as e:
        logging.error("failed to get video info")
        logging.error(e.stderr)
        raise e

    # Calculate sample_seconds based on the video duration, sample_duration and number of samples
    sample_seconds = calculate_sample_seconds(video_duration, samples, sample_duration)

    # Generate video preview
    try:
        generate_video_preview(input_url, out_file.name, sample_duration, sample_seconds, scale, format, quiet=not debug)
    except Exception as e:
        logging.error("failed to generate video preview")
        raise e

    # Upload video file to S3 bucket.
    try:
        s3_client.upload_file(out_file.name, s3_bucket_name, output_key, ExtraArgs={'ACL': 'public-read'})
    except Exception as e:
        logging.error("failed to upload video preview")
        raise e
```

An amazon S3 trigger will invoke the function each time a source video is uploaded to the bucket. The function will lookup the bucket name and key of the source video from the event parameters it receives from S3. Next it will use ffmpeg to generate a video preview from the input video. It does this by taking short samples spread throughout the input video and stitching them back together to create a new video. The ffmpeg output is saved to a temporary file that is uploaded to S3 again.

This is what the video generation code looks like:

```python
def sample_video(stream, sample_duration, sample_seconds=[]):
    samples = []
    for t in sample_seconds:
        sample = stream.video.trim(start=t, duration=sample_duration).setpts('PTS-STARTPTS')
        samples.append(sample)

    return samples

def generate_video_preview(in_filename, out_filename, sample_duration, sample_seconds, scale, format, quiet):
    stream = ffmpeg.input(in_filename)

    samples = sample_video(stream, sample_duration=sample_duration, sample_seconds=sample_seconds)
    stream = ffmpeg.concat(*samples)

    if scale is not None:
        width, height = scale.split(':')
        stream = ffmpeg.filter(stream, 'scale', width=width, height=height, force_original_aspect_ratio='decrease')

    (
        ffmpeg
        .output(stream, out_filename, format=format)
        .overwrite_output()
        .run(quiet=quiet)
    )
```

The FFmpeg bindings package, [ffmpeg-python](https://github.com/kkroening/ffmpeg-python) is used to interact with FFmpeg. This means our Lambda function requires the ffmpeg-python package and ffmpeg as a runtime dependency. In the previous section we talked about the different methods to include runtime dependencies. Either by including them in the .zip file archive for your Lambda function or by creating a container image.

> Checkout the AWS docs for more info on how to [add runtime dependencies to Python Lambda functions](https://docs.aws.amazon.com/lambda/latest/dg/python-package.html).

The function can be configured through env variables. Some of the parameters include:

* `samples` - The number of samples to take from the source video.
* `sample_duratio` - The duration of each sample.
* `scale` - Resize the output video to this scale, `width:height`.
* `format` - The output video format, e.g. `mp4`, `webm`, `flv`

A couple of things to note for this function:

- Our example function uploads its output to the same bucket that triggers it. This can cause the function to run in a loop if the trigger is configured improperly. For example if a global trigger is used the function will run again each time it's own output is uploaded to the bucket. To avoid this, configure the trigger to only apply for a prefix used for input videos.
- No additional configuration of the s3 client is required. You only need to initialize the client, `s3Client = boto3.client('s3')`. AWS maps the execution environment to the account and IAM role of the lambda function. This will allow it to access your AWS S3 bucket.

For a detailed overview on how to create a Lambda function that is triggered by S3 bucket events and how to configure the required IAM roles and permissions, take a look this tutorial: [Using an Amazon S3 trigger to invoke a Lambda function](https://docs.aws.amazon.com/lambda/latest/dg/with-s3-example.html)

### Migrate to OpenFaaS

In this section we will take function code from our Lambda function and walk through the steps required to run it as an OpenFaaS function. Since our function will be deployed to a Linode EKS cluster we will also be migrating from AWS S3 to [Linode Object Storage](https://www.linode.com/docs/products/storage/object-storage/) at the same time.

To migrate the function we will need to:

- Enable Linode Object Storage and create a bucket.
- Scaffold a new Python OpenFaaS function.
- Configure the OpenFaaS function to connect to the S3 storage.
- Refactor the handler code.

**Setup Linode Object Storage**

You can follow the official [get started guide](https://www.linode.com/docs/products/storage/object-storage/get-started/) to enable Object storage on Linode and create a new bucket.For this demo we created a bucket named `video-preview`.

Make sure to save the access-key and access-secret for the bucket at the following path:

* Access key - `.secrets/video-preview-s3-key`
* Access secret - `.secrets/video-preview-s3-secret`

`faas-cli local-run` uses the `.secrets` folder to look for secrets files when running the function locally for development.

**Create the OpenFaaS function**

Scaffold a new Python function using the faas-cli:

```bash
# Pull the python3-http template from the store
faas-cli template store pull python3-http

# Scaffold the function.
faas-cli new video-preview --lang python3-http

# Rename the function configuration file.
mv video-preview.yml stack.yml
```

We are using the `python3-http` template to scaffold the function. This template creates a minimal function image based on alpine linux. If your functions depends on modules or packages that require a native build toolchain such as Pandas, Kafka, SQL etc. we recommend using the python3-http-debian template instead.

Once the `video-preview` function is created from the template you can copy over the code from the Lambda function. We will start refactoring it step by step.

**Initialize the S3 client**

The [S3 client](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html) in the boto3 SDK can be used with any S3-compatible Object storage. We won't have to swap out the client to make it work with Linode Object storage. However, we will need to configure the client with access credentials and the correct endpoint URL.

> For more info checkout the guide: [Using the AWS SDK for Python with (boto3) with Linode Object storage](https://www.linode.com/docs/products/storage/object-storage/guides/aws-sdk-for-python/)

> Even if you opted to keep using AWS S3 for object storage, your OpenFaaS functions will not able to automatically map an IAM role to access S3. You will need to create an AWS user with the same role the Lambda function was using so that you can get the appropriate access keys for the S3 client.

Instead of initializing the boto3 client with the defaults we will create a separate function, `init_s3`, to configure the client with the required parameters. This function can be used in the function handler to initialize the S3 client the first time the function runs. After initialization the client is assigned to a global variable so that it can be reused on subsequent calls.

Update `index.py` of the `video-preview` function:

```diff
import os
import logging
import tempfile
import urllib
import ffmpeg
import boto3
+ from botocore.config import Config

from .preview import generate_video_preview, calculate_sample_seconds

- s3_client = boto3.client('s3')
+ s3_client = None

s3_output_prefix = os.getenv("s3_output_prefix", "output")
debug = os.getenv("debug", "false").lower() == "true"

samples = os.getenv("samples", 4)
sample_duration = os.getenv("sample_duration", 2)
scale = os.getenv("scale")
format = os.getenv("format", "mp4")

def handle(event, context):
+    global s3_client

+    # Initialise an S3 client upon first invocation
+    if s3_client == None:
+       s3_client = init_s3()
```

Let's take a look at the `init_s3` function:

```python
def init_s3():
    with open('/var/openfaas/secrets/video-preview-s3-key', 'r') as s:
        s3Key = s.read()
    with open('/var/openfaas/secrets/video-preview-s3-secret', 'r') as s:
        s3Secret = s.read()

    s3_endpoint_url = os.getenv("s3_endpoint_url")

    session = boto3.Session(
        aws_access_key_id=s3Key,
        aws_secret_access_key=s3Secret,
    )
    
    return session.client('s3', config=Config(signature_version='s3v4'), endpoint_url=s3_endpoint_url)
```

The S3 credentials are provided to the function as secrets. Confidential configuration like API tokens, connection strings and passwords should never be made available in the function through environment variables. Secrets can be read from the following location in the function container: `/var/openfaas/secrets/<secret-name>`.

The `init_s3` function reads the S3 key and secret from the file system. The S3 endpoint URL is read from an environment variable. Next, these parameters are used to initialize the client.

The function configuration in the `stack.yml` file needs to be updated. To tell OpenFaaS which secrets to mount for a function add the secret names to the `secrets` section. Also include the `s3_endpoint_url` for your Linode region in the `environment` section.

```diff
functions:
  video-preview:
    lang: python3-http
    handler: ./video-preview
    image: welteki/video-preview:0.0.2
+    environment:
+      - s3_endpoint_url: https://fr-par-1.linodeobjects.com
+    secrets:
+      - video-preview-s3-key
+      - video-preview-s3-secret
```

Make sure the secrets are created in the OpenFaaS cluster before deploying the functions. Secrets can be created in several ways, either through the REST API or using the `faas-cli`. In this example we will use the faas-cli to create the secrets.

```bash

faas-cli secret create video-preview-s3-key \
  --from-file .secrets/video-preview-s3-key

faas-cli secret create video-preview-s3-secret \
  --from-file .secrets/video-preview-s3-secret
```

> You can checkout the documentation for more info on [how to use secrets within your functions](https://docs.openfaas.com/reference/secrets/).

**Add code dependencies**

With AWS Lambda extra binaries, packages and modules the function code depends on need to be included in the deployment package. For Lambda this deployment package can either be a .zip file archive or container image.

OpenFaaS functions are always built into a container image. Our official templates support including dependencies in the function image without having to create your own template and Dockerfile.

For Python functions modules and packages can be added by including them in the `requirements.txt`. Additional packages can be installed in the function image through build arguments.

The function handler folder includes a `requirements.txt` file that was created while scaffolding the video-preview function from the `python-http` template. All Python packages the function code depends on need to be added here. The `video-preview` function uses the official AWS SDK for python, `boto3` to upload files to any S3-compatible Object storage. The `ffmpeg-python` python package provides bindings to FFmpeg and is used to process the input video. Make sure both are included in the `requirements.txt` file:

```
boto3
python-ffmpeg
```

Like with the AWS function you have to make sure all additional binaries the code depends on are installed in the function image. In this case our code depends on FFmpeg. With the official python-http template the build argument, `ADDITIONAL_PACKAGE` can be used specify additional `[apk](https://wiki.alpinelinux.org/wiki/Alpine_Package_Keeper)` or `[apt](https://wiki.debian.org/AptCLI)` packages that need to be installed.

Update the functions `stack.yml` configuration to include FFmpeg as an additional package:

```diff
 functions:
   video-preview:
     lang: python3-http
+    build_args:
+      ADDITIONAL_PACKAGE: "ffmpeg"
```

> See the docs for more details on [adding native dependencies](https://docs.openfaas.com/languages/python/#native-dependencies) to OpenFaaS Python functions.

**Refactor the function handler**

The `handle` function will need to be updated to handle the different format and type of the `event` parameter.

Our Lambda function used an S3 trigger that invoked the function each time a new video was uploaded to AWS S3 bucket. At the moment of writing Linode Object Storage does not have support for bucket notifications so we will update our function handler to accept a JSON payload with a download link instead.

> If you want to copy the AWS workflow and trigger the function on bucket notifications you could add Ceph storage to your cluster with [Rook](https://rook.io/). It has support for setting up S3 compatible Object storage and sending bucket notifications over HTTP. [Minio](https://min.io/) is another option that also supports sending bucket notifications over HTTP.
>
> Configuring any of these is outside the scope is this post.

```diff
import os
+ import json
import logging
import tempfile
import ffmpeg
import boto3
from botocore.config import Config

from .preview import generate_video_preview, calculate_sample_seconds

s3_client = None

samples = os.getenv("samples", 4)
sample_duration = os.getenv("sample_duration", 2)
scale = os.getenv("scale")
format = os.getenv("format", "mp4")

s3_output_prefix = os.getenv("s3_output_prefix", "output")
+ s3_bucket_name = os.getenv('s3_bucket')
debug = os.getenv("debug", "false").lower() == "true"

def handle(event, context):
    global s3_client, s3_endpoint

    # Initialise an S3 client upon first invocation
    if s3_client == None:
        s3_client = init_s3()

+    data = json.loads(event.body)
+    input_url = data["url"]

-    file_name, _ = os.path.basename(key).split(".")
+    file_name, _ = os.path.basename(input_url).split(".")
    output_key = os.path.join(s3_output_prefix, file_name + "." + format)
    out_file = tempfile.NamedTemporaryFile(delete=True)
    
-    try:
-        input_url = s3_client.generate_presigned_url('get_object', Params={'Bucket': s3_bucket_name, 'Key': key}, ExpiresIn=60 * 60)
-    except Exception as e:
-        logging.error("failed to get presigned video url")
-        raise e

    try:
        probe = ffmpeg.probe(input_url)
        video_duration = float(probe["format"]["duration"])
    except ffmpeg.Error as e:
        logging.error("failed to get video info")
        logging.error(e.stderr)
        raise e

    # Calculate sample_seconds based on the video duration, sample_duration and number of samples
    sample_seconds = calculate_sample_seconds(video_duration, samples, sample_duration)

    # Generate video preview
    try:
        generate_video_preview(input_url, out_file.name, sample_duration, sample_seconds, scale, format, quiet=not debug)
    except Exception as e:
        logging.error("failed to generate video preview")
        raise e

    # Upload video file to S3 bucket.
    try:
        s3_client.upload_file(out_file.name, s3_bucket_name, output_key, ExtraArgs={'ACL': 'public-read'})
    except Exception as e:
        logging.error("failed to upload video preview")
        raise e
```

Changes made to the handler function:

- Instead of getting the S3 bucket name from the event payload we now read it from an environment variable. Make sure to add `s3_bucket_name` to the `environment` section in the `stack.yml` file.
- The Lambda function used an S3 key that was also read from the event payload to generate a pre-signed URL to download the source video. In the OpenFaaS function we are reading the download URL directly from the request body.

These are the minimal changes required to run our code as an OpenFaaS function.

**Deploy the OpenFaaS function**

Before you go ahead and deploy the function to the OpenFaaS cluster make sure to check the `stack.yml` file. After adding all the configuration options from the previous steps it should look something like this:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  video-preview:
    lang: python3-http
    build_args:
      ADDITIONAL_PACKAGE: "ffmpeg"
    handler: ./video-preview
    image: welteki/video-preview:0.0.2
    environment:
      s3_bucket: video-preview  
      s3_endpoint_url: https://fr-par-1.linodeobjects.com
      write_timeout: 10m2s
      read_timeout: 10m2s
      exec_timeout: 10m
    secrets:
      - video-preview-s3-key
      - video-preview-s3-secret
```

Note that we included three additional environment variables to [configure the function's timeouts](https://docs.openfaas.com/tutorials/expanded-timeouts/#part-2-your-functions-timeout). Transforming and transcoding videos can take some time depending on the size of the source video. If you have long running functions make sure the timeouts are configured properly so your functions can finish their work.

For quick iterations and testing during development OpenFaaS function can run locally with docker using the `faas-cli local-run` command. We show how to use this feature in our blog post: [The faster way to iterate on your OpenFaaS functions](https://www.openfaas.com/blog/develop-functions-locally/).

To deploy the function run:

```bash
# URL to the OpenFaaS gateway
export OPENFAAS_URL="https://openfaas.example.com"
faas-cli up
```

This will build the function, push the resulting image and deploy the function to your OpenFaaS cluster.

Invoke the function with curl:

```bash
curl -i https://openfaas.example.com/function/video-preview \
  -H 'Content-Type: application/json' \
  -d '{"url": "https://video-preview.fr-par-1.linodeobjects.com/input/openfaas-homepage-vid.webm"}'
```

## Taking it further

We refactored our video-preview function to accept a url in a JSON payload. You can improve the function by accepting a [trigger from S3](https://docs.openfaas.com/reference/triggers/#minio-s3).

We migrated a long running video transformation function that can be resource intensive. To prevent overloading the function you cloud set limits and configure autoscaling. Checkout these blog post to learn how this can be done:

- [Generate PDFs at scale on Kubernetes using OpenFaaS and Puppeteer](https://www.openfaas.com/blog/pdf-generation-at-scale-on-kubernetes/)
- [Rethinking Auto-scaling for OpenFaaS](https://www.openfaas.com/blog/autoscaling-functions/)

## Wrapping up

We saw how to deploy OpenFaaS in a managed Kubernetes cluster with LKE. Alternatively you can create a cluster yourself. Checkout our tutorial: [How to set up production-ready K3s with OpenFaaS with Akamai Cloud Computing](https://www.openfaas.com/blog/production-faas-linode/)

We migrated our ETL pipeline from being restricted to only be deployable on AWS Lambda infrastructure to being completely portable by using OpenFaaS.

Additionally developers are able to test their functions locally by either using the `faas-cli local-run` command or deploying an OpenFaaS cluster locally.
