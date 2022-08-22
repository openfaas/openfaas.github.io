---
title: "How to process large amounts of data with OpenFaaS functions"
description: "We show you how to use a fan out and fan in pattern to process large amounts of data in parallel."
date: 2022-08-22
image: /images/2022-fan-out-and-back-in-using-functions/background.jpg
categories:
- architecture
- dataprocessing
- bigdata
author_staff_member: han

---

We show you how to use a fan out and fan in pattern to process large amounts of data in parallel.

We're increasingly hearing that OpenFaaS functions are convenient for ingesting, transforming and processing large amounts of data. A common pattern used when processing large amounts of data is to break down an expensive task into smaller sub tasks that can be executed in parallel. This fan-out pattern is already available in OpenFaaS through asynchronous functions. With the async feature, invocations are queued up and processed as and when there's capacity.

> Our post, [How to process your data the resilient way with back pressure ](https://www.openfaas.com/blog/limits-and-backpressure/), shows how OpenFaaS can be used to process a dataset as quickly as possible, without losing any of the records.

In some cases we want to be notified when a group of asynchronous function invocations completes and collect the result from each individual invocation. We need to fan-in again. Fanning in requires a bit more code. We will show how this can be implemented with OpenFaaS functions.


## Implementing a fan-out/fan-in pattern in OpenFaaS.
In this section we are going to show you how this pattern can be implemented with OpenFaaS through a relatable use-case. A common big data scenario is batch processing of a data set. In this scenario data is retrieved from a storage system and then processed by parallelized jobs. The results of each individual job is persisted in some kind of data store where it can later be retrieved for further processing when the batch is completed.

In this example we are going to process a CSV file containing URLs to images on Wikipedia. For each URL in the data set we want to run the Inception model and get back image categorizations through machine learning. The inception model can classify what's in a photo based upon a training set made up of objects and animals. As a final processing step we will combine all the individual result into a single output.

![](/images/2022-fan-out-and-back-in-using-functions/fan-out-in-example.png)
> Fan-out/fin-in pattern with OpenFaaS functions

You can find the [full example on GitHub](https://github.com/welteki/openfaas-fan-in-example)

### Fan-out
S3 will be used as the data store throughout this example. The source files are retrieved from an S3 and the final result will be uploaded to the same bucket. To run this example yourself you will need to create an Amazon S3 bucket.

The first part of the workflow will consist of two functions. The `creat-batch` function is responsible for initializing the workflow. It accepts the name of CSV file stored in an S3 bucket as input. The function will retrieve the CSV file containing the image URLs and invoke the second function, `run-model` for each URL in the file.

The `run-model` function is responsible for calling the machine learning model, in this case the `inception` function, and uploading the result to S3.

The handler of the `create-batch` functions:

```python
import os
import json
import uuid
import requests
import pandas as pd
import boto3

from smart_open import open

def handle(event, context):
    bucketName = os.getenv('s3_bucket')
    
    with open('/var/openfaas/secrets/s3-key', 'r') as s:
        s3Key = s.read()
    with open('/var/openfaas/secrets/s3-secret', 'r') as s:
        s3Secret = s.read()

    session = boto3.Session(
        aws_access_key_id=s3Key,
        aws_secret_access_key=s3Secret,
    )

    batchFile = event.body.decode()
    s3URL = 's3://{}/{}'.format(bucketName, batchFile)
    with open(s3URL, 'rb', transport_params={'client': session.client('s3')}) as f:
        records = pd.read_csv(f)

    batchId = str(uuid.uuid4())

    for index, col in records.iterrows():
        headers = { 'X-Batch-Id': batchId }
        res = requests.post('http://gateway.openfaas:8080/async-function/run-model', data=col['url'], headers=headers)

    response = {
        'batch_id': batchId,
    }

    return {
        "statusCode": 201,
        "body": json.dumps(response)
    }
```

The function invokes run-model asynchronously. This decouples the HTTP transaction between the caller and the function. The invocation is added to a queue and runs in the background. This allows us to run the invocations in parallel.

> The parallelism of a batch job can be controlled by changing the number of tasks the queue-worker runs at once. See our[ official documentation](https://docs.openfaas.com/reference/async/#parallelism) for more details on how to do this. 


The handler for the `run-model` function:

```python
import os
import json
import requests
import boto3

from smart_open import open

def handle(event, context):
    bucketName = os.getenv('s3_bucket')

    with open('/var/openfaas/secrets/s3-key', 'r') as s:
        s3Key = s.read()
    with open('/var/openfaas/secrets/s3-secret', 'r') as s:
        s3Secret = s.read()

    session = boto3.Session(
        aws_access_key_id=s3Key,
        aws_secret_access_key=s3Secret,
    )

    batchId = event.headers.get('X-Batch-Id')
    url = event.body.decode()

    res = requests.get("http://gateway.openfaas:8080/function/inception", data=url)

    callId = res.headers.get('X-Call-Id')
    status = 'success' if res.status_code == 200 else 'error'
    result = res.json() if res.status_code == 200 else res.text
    taskResult = {
        'batchId': batchId,
        'callId': callId,
        'url': url,
        'result': result,
        'status': status
    }

    fileName = '{}/{}.json'.format(batchId, callId)
    s3URL = "s3://{}/{}".format(bucketName, fileName)
    with open(s3URL, 'w', transport_params={'client': session.client('s3')}) as fout:
        json.dump(taskResult, fout)

    return {
        "statusCode": 200,
        "body": "Success running model"
    }
```

The `run-model` function invokes the `inception` function synchronously and store the result, along with some metadata like the batch id, call id, and status, as a json file in S3. The result is stored in a folder named after the batch id. This makes it easy to retrieve all results for a certain batch. The metadata can be useful for for debugging or when processing the data in a later step. 

## Fan-in
To be able to fan-in and get notified when all the asynchronous invocations for a batch have finished we need some state to keep track of the progress. A counter can be used to keep track of the work that has been completed. Each time an asynchronous invocation finishes the counter is decremented. When the counter reaches zero the final function in the workflow can be called.

We are going to use a Redis key to store this state for each batch. It has a `DECR` command to atomically decrement a value and it returns the new key value at the end.

We need to create a Redis connection in the `create-batch` and `run-model` functions that they can use to initialize and update the counter.

The following code creates a connection to Redis using redis-py:

```python
redisHostname = os.getenv('redis_hostname')
redisPort = os.getenv('redis_port')

with open('/var/openfaas/secrets/redis-password', 'r') as s:
    redisPassword = s.read()

r = redis.Redis(
    host=redisHostname,
    port=redisPort,
    password=redisPassword,
)
```

Update the stack.yaml for the functions to add the Redis environment variables and secret: 
```yaml
environment:
    s3_bucket: of-demo-inception-data
    redis_hostname: "redis-master.redis.svc.cluster.local"
    redis_port: 637
secrets:
    - s3-key
    - s3-secret
    - redis-password
```

Don't forget to add `redis` to the `requirements.txt` for your functions.


The `create-batch` function can now be updated to count the number of URLs in the CSV file and initialize a Redis key for `batchId` with that value. 
```python
batchFile = event.body.decode()
s3URL = 's3://{}/{}'.format(bucketName, batchFile)
with open(s3URL, 'rb', transport_params={'client': session.client('s3')}) as f:
    records = pd.read_csv(f)

batchId = str(uuid.uuid4())
batchSize = len(records)

r.set(batchId, batchSize)

for index, col in records.iterrows():
    headers = { 'X-Batch-Id': batchId }
    res = requests.post('http://gateway.openfaas:8080/async-function/run-model', data=col['url'], headers=headers)
```

In the `run-model` function we need to decrement this counter every time an invocation to the `inception` function finishes. If the counter reaches zero, this means all work in the batch is completed and the final function can be invoked.

```python

remainingWork = r.decr(batchId)

if remainingWork == 0:
    headers = { 'X-Batch-Id': batchId }
    res = requests.post("http://gateway.openfaas:8080/async-function/collect-result", headers=headers)
    r.delete(batchId)
```

### Collect the results
The final function is called when all asynchronous requests in a batch are completed. This function can be used to aggregate the results, notify some other actor or trigger the next step in your processing workflow. In this example we are going to use it to collect all the responses in a single json file and upload that file to the S3 bucket.

The code of the `collect-result` function:

```python
import os
import json
import boto3

from smart_open import s3
from smart_open import open

def handle(event, context):
    bucketName = os.getenv('s3_bucket')

    with open('/var/openfaas/secrets/s3-key', 'r') as s:
        s3Key = s.read()
    with open('/var/openfaas/secrets/s3-secret', 'r') as s:
        s3Secret = s.read()

    session = boto3.Session(
        aws_access_key_id=s3Key,
        aws_secret_access_key=s3Secret,
    )

    batchId = event.headers.get('X-Batch-Id')

    results = []
    failed = []
    
    for key, content in s3.iter_bucket(bucketName, prefix=batchId + '/', workers=30, aws_access_key_id=s3Key, aws_secret_access_key=s3Secret):
        data = json.loads(content)
        if (data['status'] == 'error'):
            failed.append({ 'url': data['url'], 'result': data['result'] })
        else:
            results.append({ 'url': data['url'], 'result': data['result'] })

    summary = {
        'batchId': batchId,
        'failures': {
            'count': len(failed),
            'results': failed
        },
        'results': {
            'count': len(results),
            'results': results,
        }
    }

    fileName = '{}.json'.format(batchId)
    s3URL = "s3://{}/{}".format(bucketName, fileName)
    with open(s3URL, 'w', transport_params={'client': session.client('s3')}) as fout:
        json.dump(summary, fout)
    
    return {
        "statusCode": 200,
        "body": 'Processed batch: {}'.format(batchId)
    }
```

This function retrieves the batch id from the http headers and uses it to iterate over the S3 Bucket's Contents. All results for the specific batch are retrieved and the result is added to the summary. As a final step the summary file is uploaded to the S3 bucket.

> When processing a large batch this function can take a while to complete. Make sure that your timeouts are configured correctly for both your function and the OpenFaaS core components. See: [Expanding timeouts](https://docs.openfaas.com/tutorials/expanded-timeouts/)

## Conclusion
We showed how a map/reduce pattern can be implemented with OpenFaaS. A created a workflow to process a CSV file containing Wikipedia URLs. Our goal was to run an AI model for each URL. We split the input into many sub tasks to process them in parallel. This fan out part is supported in OpenFaaS through asynchronous functions. We started an asynchronous request for each URL, that in turn invoked the machine learning model. After all the requests completed their results were combined into a single output. This fanning in required some state. We used a redis key to keep track of the batch progress.

The example we showed here is a minimal example that can be used a starting point. It can be further improved and adapted for more specific use cases.

- The processing can be made more resilient by retrying a sub task before marling it as failed.
- A function that returns some info on the batch progress can be added.

See also:
- [How to process your data the resilient way with back pressure](https://www.openfaas.com/blog/limits-and-backpressure/)

If you’d like to talk to us about anything we covered in this blog post: [feel free to reach out](https://www.openfaas.com/support/)

We also run a [Weekly Office Hours call](https://docs.openfaas.com/community/#weekly-office-hours) that you’re welcome to join.