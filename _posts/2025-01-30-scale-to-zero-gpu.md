---
title: "Scale to zero GPUs with OpenFaaS, Karpenter and AWS EKS"
description: ""
date: 2025-01-29
author_staff_member: han
categories:
  - gpu
  - ai
  - eks
  - openfaas
  - serverless
  - auto-scaling
dark_background: true
image: ""
hide_header_image: true
---

If you have ETL pipelines where certain processing steps require some AI model to run. Or if you are doing tasks like, audio transcription, image analysis with object recognition or natural language processing (NLP) for text extraction, then using GPUs can significantly speed up these AI-driven tasks.

GPU nodes are expensive and you don't want these nodes to sit idle costing you money when they are unused. In his post we will walk you through an example of how to build and run these kinds of workloads with OpenFaaS. We will see how OpenFaaS features like [scale-to-zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/) and [asynchronous invocation](https://docs.openfaas.com/reference/async/) can be used together with Karpenter to add and remove GPU nodes on demand.

## Prerequisites

To follow along and run the examples yourself we assume you already have an AKS cluster running with OpenFaaS and Karpenter installed and have a basic knowledge of how Karpenter works.

If you don't have a cluster yet, read the first part of this series on OpenFaaS and Karpenter. There we show [how to deploy and configure OpenFaaS and Karpenter on AWS EKS](https://www.openfaas.com/blog/) in detail.

## Prepare the cluster for GPU support

If you want to add nodes to the cluster that have GPUs available you need to deploy the appropriate device plugin daemonset. In this example we will be using Nvidia GPUs only. However Kubernetes and Karpenter support more GPU vendors and types of accelerators. See the [Karpenter docs](https://karpenter.sh/docs/concepts/scheduling/#acceleratorsgpu-resources) for more.


Install the [Nvidia device plugin](https://github.com/NVIDIA/k8s-device-plugin)

Basic device plugin installation without custom options:

```sh
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
  --namespace nvidia-device-plugin \
  --create-namespace \
  --version 0.17.0
```

> For more advanced configuration like GPU sharing see the [Nvidia-device-plugin README](https://github.com/NVIDIA/k8s-device-plugin).

## Schedule GPU nodes with Karpenter

Karpenter supports accelerators such as GPUs. A GPU can be request by simply adding requirements to the workload requirements.

```yaml
spec:
  template:
    spec:
      containers:
      - resources:
          limits:
            nvidia.com/gpu: "1"
```

### Add a GPU node pool

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: gpu
spec:
  template:
    metadata:
      labels:
        nvidia.com/gpu: "true"
    spec:
      taints:
        - key: nvidia.com/gpu
          value: "true"
          effect: NoSchedule
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["g", "p"]
        - key: "karpenter.k8s.aws/instance-gpu-manufacturer"
          operator: In
          values: ["nvidia"]
        - key: "karpenter.sh/capacity-type"
          operator: In
          values: ["spot", "on-demand"]
        - key: nvidia.com/gpu
          operator: Exists 
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: gpu
      expireAfter: 720h # 30 * 24h = 720h
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
```

- In the requirements we tell Karpenter to allow both spot and on-demand instances. Karpenter will try to schedule spot instances first since they are usually cheaper and will only use the on-demand as a fallback. If your workload can not tolerate interruptions because an instance is reclaimed request on-demand only.

- We configure Karpenter to select from a range of GPU instances. By setting `karpenter.k8s.aws/instance-category`, we require instances from the `g` and `p` categories. We also set `karpenter.k8s.aws/instance-gpu-manufacturer` to allow Nivida GPUs only. See the [instance type reference](https://karpenter.sh/docs/reference/instance-types/) in the Karpenter docs for all available types and labels to select instances best suited for your workload.

> It is recommend to let Karpenter select from a wide enough range if instance types and sizes to prevent it from running out of capacity when some instances are not available.

GPU NodeClass:

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: gpu
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "KarpenterNodeRole-openfaas" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "openfaas" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "openfaas" # replace with your cluster name
  amiSelectorTerms:
    - id: "ami-0c1146260994887d8" # <- GPU Optimized AMD AMI 
```

## Run a GPU accelerated function.

While the OpenFaaS function spec allows setting cpu and memory resources, gpu resource can not be set directly. They need to be set using an [OpenFaaS Profile](https://docs.openfaas.com/reference/profiles/). Create an Profile named `gpu` this profile can be applied to functions by adding the annotation `com.openfaas.profile=gpu`. The spec from the Profile will be added to the function deployment. In addition to a resources requesting a GPU, a toleration as added that allows the function to run on a GPU node.

```yaml
kind: Profile
apiVersion: openfaas.com/v1
metadata:
  name: gpu
  namespace: openfaas
spec:
  tolerations:
  - key: nvidia.com/gpu
    operator: Exists
    effect: NoSchedule
  resources:
    requests:
      nvidia.com/gpu: 1 # requesting 1 GPU
    limits:
      nvidia.com/gpu: 1
```

Deploy the `nvidia-smi` function from the OpenFaaS store for testing:

```sh
faas-cli store deploy nvidia-smi \
    --annotation com.openfaas.profile=gpu
```

Check the nodes that have GPUs available:

```sh
kubectl get nodes \
"-o=custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\.com/gpu"
```

```
NAME                             GPU
ip-192-168-19-10.ec2.internal    <none>
ip-192-168-35-233.ec2.internal   1
```

Invoke the nvidia-smi function:

```sh
echo | faas-cli invoke nvidia-smi

Tue Jan 21 17:57:25 2025       
+-----------------------------------------------------------------------------------------+
| NVIDIA-SMI 550.144.03             Driver Version: 550.144.03     CUDA Version: 12.4     |
|-----------------------------------------+------------------------+----------------------+
| GPU  Name                 Persistence-M | Bus-Id          Disp.A | Volatile Uncorr. ECC |
| Fan  Temp   Perf          Pwr:Usage/Cap |           Memory-Usage | GPU-Util  Compute M. |
|                                         |                        |               MIG M. |
|=========================================+========================+======================|
|   0  Tesla T4                       On  |   00000000:00:1E.0 Off |                    0 |
| N/A   23C    P8              9W /   70W |       1MiB /  15360MiB |      0%      Default |
|                                         |                        |                  N/A |
+-----------------------------------------+------------------------+----------------------+
                                                                                         
+-----------------------------------------------------------------------------------------+
| Processes:                                                                              |
|  GPU   GI   CI        PID   Type   Process name                              GPU Memory |
|        ID   ID                                                               Usage      |
|=========================================================================================|
|  No running processes found                                                             |
+-----------------------------------------------------------------------------------------+
```

## Tutorial: create a GPU accelerated function workflow.

In this section we are going to show how you how to run a basic GPU accelerated function workflow. We will create a function the runs the Whisper speech recognition model to transcribe an audio file. The function takes a url to a file as the input, transcribes the files an returns the transcript in the response. The response will be submitted to the next function in the workflow for further processing.

This basic example is intended to show you how to:

- Use the OpenFaaS autoscaler and scale to zero capabilities for cost effective, on demand GPU node provisioning with Karpenter. GPU nodes are removed from the cluster to save cost when functions are idle.
- Use asynchronous invocations and callbacks to build a resilient function workflows. Invoke function asynchronously to handle, cold start delays when GPU nodes need to be provisioned. Use the async callback functionality to get the result from asynchronous invocations for further processing by a next function.
- Use concurrency limits and retries for efficient scaling and to prevent overloading the cluster.


**Create a function**

Create a new function using the [OpenFaaS CLI](https://github.com/openfaas/faas-cli).

```yaml
# Change this line to your own registry
export OPENFAAS_PREFIX="docker.io/welteki"

# Scaffold a new function using the python3-http-debian template
faas-cli new whisper --lang python3-http-debian
```
This scaffolds a new function named `whisper` using the `python3-http-debian` template, one of the official [OpenFaaaS python templates](https://docs.openfaas.com/languages/python/#python).

The function handler `whisper/handler.py` is where you write the custom function code. In this case the function retrieves an audio file from a url that is passed in through the request body. Next the whisper model transcribes the audio file and the transcript is returned in the response.

```python
import tempfile
from urllib.request import urlretrieve

import whisper

def handle(event, context):
    models_cache = os.getenv("MODELS_CACHE", "/tmp/models")
    model_size = os.getenv("MODEL_SIZE", "tiny.en")

    url = str(event.body, "UTF-8")
    audio = tempfile.NamedTemporaryFile(suffix=".mp3", delete=True)
    urlretrieve(url, audio.name)

    model = whisper.load_model(name=model_size, download_root=models_cache)
    result = model.transcribe(audio.name)
    
    return (result["text"], 200, {'Content-Type': 'text/plain'})
```

The first time the function is invoked it will download the model and save it to the location set in the `models_cache` variable. `/tmp/models` is used by default. Subsequent invocations of the function will not need to refetch the model.

> It is good practice to only write to the `/tmp` folder from function and make the function filesystem read-only by setting `readonly_root_filesystem: true` in the function stack.yaml. This provides tighter security by preventing the function from modifying the rest of the filesystem.

The function uses the `tiny.en` model by default but different model sizes can be selected by setting the `MODEL_SIZE` env variable for the function.

**Add runtime dependencies**

Our function handler uses the [`openai-whisper`](https://github.com/openai/whisper) python packages. Edit the `whisper/requirements.txt` file and add the following line:

```
openai-whisper
```

Whisper relies on ffmpeg for audio transcoding. It requires that ffmpeg is installed it the function container as a runtime dependency.
The [OpenFaaS python3 templates](https://github.com/openfaas/python-flask-template) support specifying additional packages that will be installed with apt through the ADDITIONAL_PACKAGE build arguments.

Update the `stack.yaml` file:

```diff
functions:
  whisper:
    lang: python3-http-debian
    handler: ./whisper
    image: docker.io/welteki/whisper:latest
+    build_args:
+      ADDITIONAL_PACKAGE: "ffmpeg"
```


**Apply profiles**

The function will need to apply the `gpu` profile that was created while preparing the cluster for GPU workloads. The profile sets gpu resource requests and adds the required tolerations to the function deployment. Add the `com.openfaas.profile: gpu` annotation to the `stack.yaml` file:

```diff
functions:
  whisper:
    lang: python3-http-debian
    handler: ./whisper
    image: docker.io/welteki/whisper:latest
    build_args:
      ADDITIONAL_PACKAGE: "ffmpeg"
+    annotations:
+      com.openfaas.profile: gpu
```

**Configure scale to zero**

The Karpenter gpu NodePool that we configured removes nodes when they or idle or when the resources are underutilized. Our function requests a GPU to run so as long as there are any function replicas holding on to these resource no nodes will get removed. To free up these resources and save money by removing GPU nodes from the cluster, functions can be configured to scale down to zero replicas when idle.

Scale down to zero is controlled by the [OpenFaaS Pro autoscaler](https://docs.openfaas.com/architecture/autoscaling/). By default the autoscaler does not scale functions to zero. This is by design and means that you need to opt-in each of your functions to scale down. Scale to zero for function is configured by setting the `com.openfaas.scale.zero` and `com.openfaas.scale.zero-duration` on a function.

Add the autoscaling labels to the `stack.yaml` configuration to scale down the function after 2 minutes of inactivity.

```diff
functions:
  whisper:
    lang: python3-http-debian
    handler: ./whisper
    image: docker.io/welteki/whisper:latest
    build_args:
      ADDITIONAL_PACKAGE: "ffmpeg"
    annotations:
      com.openfaas.profile: gpu
+    labels:
+      com.openfaas.scale.zero: true
+      com.openfaas.scale.zero-duration: 2m
```

**Configure timeouts**

It is common for inference or other machine learning workloads to be long running jobs. In this example transcribing the audio file can take some time depending on the size of the file and the GPU speed. To ensure the function can run to completion timeouts for the function and OpenFaaS components need to be configured correctly.

If you followed steps in our previous post, [Save costs on AWS EKS with OpenFaaS and Karpenter](https://www.openfaas.com/blog/eks-openfaas-karpenter/), to setup your cluster the timeouts for the OpenFaaS core components should be set to 10 minutes which is plenty for this demo.

Update the `stack.yaml` file to set the appropriate timeouts for the function:

```diff
functions:
  whisper:
    lang: python3-http-cuda
    handler: ./whisper
    image: whisper:0.0.1
    annotations:
      com.openfaas.profile: gpu
+    environment:
+        write_timeout: 5m5s
+        exec_timeout: 5m
```

See the section on [extended timeouts](https://docs.openfaas.com/tutorials/expanded-timeouts/) in our docs for more info.

**Invoke the function asynchronously and capture the result**

Before the function can be invoked it needs to be deployed to the cluster. The `faas-cli` can build and deploy the function using a single command:

```sh
faas-cli up whisper
```

We are going to invoke the function asynchronously and set the `X-Callback-Url` header to receive the result. In this example we will be sending the result to the `printer` function for simplicity. The printer function is one of our utility function that just logs the request headers and body when invoked.

In a production pipeline the callback function could be the next step in the workflow that does some further processing of the result or uploads it to some storage solution like a database or S3 bucket.

Deploy the printer function:

```sh
faas-cli store deploy printer
```
Invoke the function asynchronously using `curl`:

```sh
curl -i http://127.0.0.1:8080/async-function/wisper \
  -H "X-Callback-Url: http://gateway.openfaas:8080/function/printer"
  -d https://example.com/track.mp3
```

Monitor the logs of the `printer` function to see the result.

```sh
faas-cli logs printer -t
```

Note that it can take some time before we get back the result. As we saw in the first section of the article with the `nvidia-smi` function Karpenter needs to provision an new GPU node before the function Pod can be scheduled.

Since we invoked the function asynchronously we don't have to worry about setting the correct request timeout. The OpenFaaS queue-worker will try to invoke the function once it becomes ready. Any failures are retried with a backoff and the result is posted back to the URL that we set in the `X-Callback-Url` header.

## Concerns for production

**Trigger a workflow**

- Trigger using OpenFaaS event connectors e.g. cron
- SQS, S3 bucket event -> [How to integrate OpenFaaS functions with managed AWS services ](https://www.openfaas.com/blog/integrate-openfaas-with-managed-aws-services/)

**Model caching**

- Mention the caching options and briefly touch on using the `/tmp` directory again.
  - Pull model on first request
  - Pre pull model on function start -> [Custom health and readiness checks](https://www.openfaas.com/blog/health-and-readiness-for-functions/)
  - Include model in container image
  - Future work

**Handle the result callback**

- Run further inference in the result.
- Upload result to AWS S3 or database.

**Setting limits**

- Limit max GPUs in NodePool
- Concurrency limit on functions

[Fine-tuning the cold-start in OpenFaaS ](https://www.openfaas.com/blog/fine-tuning-the-cold-start/)

# Conclusion

- [How to transcribe audio with OpenAI Whisper and OpenFaaS](https://www.openfaas.com/blog/transcribe-audio-with-openai-whisper/)
- [Exploring the Fan out and Fan in pattern with OpenFaaS](https://www.openfaas.com/blog/fan-out-and-back-in-using-functions/)
- [Fine-tuning the cold-start in OpenFaaS](https://www.openfaas.com/blog/fine-tuning-the-cold-start/)