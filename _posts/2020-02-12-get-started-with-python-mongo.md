---
title: "Get storage for your functions with Python and MongoDB"
description: Learn how to connect storage to your functions with Python3 and MongoDB.
date: 2020-02-12
image: /images/2020-01-30-get-started-with-java-openjdk11/java11.jpg
categories:
  - serverless
  - paas
  - kubernetes
  - python
  - storage
  - mongodb
author_staff_member: alex
dark_background: true

---

Learn how to connect storage to your functions with Python3 and MongoDB.

## Before we start

You'll need access to the following:

* An Intel computer or a remote cluster
* [Kubernetes](https://kubernetes.io/) - install with your preferred local tooling such as KinD, minikube, or k3d. Or use a cloud service like Amazon EKS, GKE or DigitalOcean Kubernetes. A single VM running k3s is also fine.
* [OpenFaaS](https://github.com/openfaas/faas) - we'll install OpenFaaS in the guide using a developer setup, you can read past blog posts and the [documentation](https://docs.openfaas.com) for how to best tune your setup for production

## Tutorial

We'll first of all get OpenFaaS installed using the easiest way possible. Then we'll build a simple Python function using the `python3-debian` template, deploy MongoDB using [its helm chart](https://github.com/helm/charts/tree/master/stable/mongodb) and connect storage to our new function.

### Get OpenFaaS

Make sure that you have the Kubernetes CLI ([kubectl](https://kubernetes.io/docs/reference/kubectl/overview/)) available.

Download [arkade](https://get-arkade.dev/), which is an installer for helm charts for any Kubernetes cluster. We will install OpenFaaS using `arkade install` and [the OpenFaaS helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas):

```sh
curl -sSLf https://dl.get-arkade.dev | sudo sh
```

Now install openfaas:

```sh
arkade install openfaas \
  --helm3
```

You can also customise values from the helm chart's README by passing in `--set`, for instance, or by using a user-friendly flag shown below:

```sh
Install openfaas

Usage:
  arkade install openfaas [flags]

Examples:
  arkade install openfaas --loadbalancer

Flags:
  -a, --basic-auth                    Enable authentication (default true)
      --clusterrole                   Create a ClusterRole for OpenFaaS instead of a limited scope Role
      --direct-functions              Invoke functions directly from the gateway (default true)
      --function-pull-policy string   Pull policy for functions (default "Always")
      --gateways int                  Replicas of gateway (default 1)
      --helm3                         Use helm3 instead of the default helm2
  -h, --help                          help for openfaas
  -l, --load-balancer                 Add a loadbalancer
  -n, --namespace string              The namespace for the core services (default "openfaas")
      --operator                      Create OpenFaaS Operator
      --pull-policy string            Pull policy for OpenFaaS core services (default "IfNotPresent")
      --queue-workers int             Replicas of queue-worker (default 1)
      --set stringArray               Use custom flags or override existing flags 
                                      (example --set=gateway.replicas=2)
      --update-repo                   Update the helm repo (default true)
```

At the end of the installation you'll get instructions for how to:

* install the OpenFaaS CLI (`faas-cli`)
* port-forward the gateway to your local machine
* and to log-in using `faas-cli login`

If you lose this information just type in `arkade info openfaas` at any time.

### Get MongoDB

Now that we have `arkade`, we can install of the apps available such as mongodb, to any Kubernetes cluster. arkade downloads the MongoDB helm chart and sets the proper defaults for development, so you can get up and running in a few seconds.

```bash
arkade install mongodb
```

Now look carefully for the output because it will tell you what the credentials are to access MongoDB, we need that for our functions.

### Create the `hello-python3` function

OpenFaaS builds immutable Docker or OCI-format images, so you will need to push your image to a registry such as the [Docker Hub](https://hub.docker.com), you can edit your `find-a-quote.yml` file and add your Docker Hub username like `image: alexellis2/find-a-quote:latest`.

> If you're new to working with Docker and Kubernetes, then I would recommend taking up the [workshop](https://github.com/openfaas/workshop) listed at the end of this tutorial which explains all of the above in detail.

Create a new function named `hello-python3`:

```bash
export OPENFAAS_PREFIX="alexellis2" # Use your name
faas-cli new --lang python3-debian \
  hello-python3
```

This creates several new files for us:

```bash
├── hello-python3
│   ├── handler.py
│   ├── __init__.py
│   └── requirements.txt
└── hello-python3.yml

```

This is the handler, which you can customise: `hello-python3/handler.py`

```python
def handle(req):
    """handle a request to the function
    Args:
        req (str): request body
    """

    return req

```

Edit the code so that it returns "hello world":

```python

    return "hello world"
```

Now we can run a build and deploy our function, but first let's enable Docker's new Buildkit container builder which can dramatically reduce the time taken to build images.

```bash
export DOCKER_BUILDKIT=1
```

```bash
faas-cli up -f hello-python3.yml
```

The initial build may take a few moments, but after that we are only changing a single text file, so each subsequent build is very quick - mine was between 1 and 2 seconds.

```
Deployed. 202 Accepted.
URL: http://127.0.0.1:8080/function/hello-python3
```

You'll be given a URL and Kubernetes will have already pulled the image and started a Pod for your function and started it in a Pod.

```bash
kubectl get pod -n openfaas-fn -o wide

NAME            READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS      IMAGES                         
follow-github   1/1     1            1           41m   follow-github   alexellis2/follow-github:0.1.3 
```

You can invoke your function using the URL given:

```bash
curl http://127.0.0.1:8080/function/hello-python3
```

Each function also gets an asynchronous URL, which you can find via `faas-cli describe`:

```bash
faas-cli describe -f hello-python3.yml hello-python3
```

Asynchronous processing appears instant to the user, and so you can queue up a lot of work and have it run when the system has capacity. You can read more about asynchronous processing in the [documentation](https://docs.openfaas.com) and [workshop](https://github.com/openfaas/workshop). 

### Create the `follow-github` function

We'll create a new function called `follow-github` which is used to store and query a list of people we want to follow on GitHub.

```bash
export OPENFAAS_PREFIX="alexellis2" # Use your name
faas-cli new --lang python3-debian \
  follow-github
```

Now to access MongoDB we will need to use a client library, [this tutorial](https://api.mongodb.com/python/current/tutorial.html) shows how to use the official library.

First, we'll add "pymongo" to `follow-github/requirements.txt` so that it can be installed with pip during the `faas-cli build/up` command.

```
echo pymongo >> follow-github/requirements.txt
```

Now to test that the build works, run `faas-cli build`.

```bash
faas-cli build -f follow-github.yml
```

Note that the build does not deploy or push the function's image, so after every change you will need to run `faas-cli up`.

You can see the package downloaded and installed in the logs:

```bash
Step 20/29 : RUN pip install -r requirements.txt --target=/home/app/python
 ---> Running in ed1a3721d1f0
Collecting pymongo (from -r requirements.txt (line 1))
  Downloading https://files.pythonhosted.org/packages/49/01/1da7d3709ea54b3b4623c32d521fb263da14822c7d9064d7fd9eeb0b492c/pymongo-3.10.1-cp36-cp36m-manylinux1_x86_64.whl (450kB)
Installing collected packages: pymongo
Successfully installed pymongo-3.10.1
```

This is relatively quick, but fortunately for us Docker also caches the step so that it's even quicker the second time we build our code.

We need to connect to MongoDB which is running inside our Kubernetes cluster and this means using the secret that you stored in the earlier step.

```bash
MongoDB can be accessed via port 27017 on the following DNS name from within your cluster:

mongodb.default.svc.cluster.local

To get the root password run:

export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace default mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)
```

Each openfaas function has a [YAML file](https://docs.openfaas.com/reference/yaml/) which can be used to configure settings, there are two ways you can do this and we'll be using both:

* confidential settings - use a secret
* config - use an environment variable

The secret needs to be fetched and created as a Kubernetes secret so that we can attach it to our function:

```bash
export MONGODB_ROOT_PASSWORD=$(kubectl get secret --namespace default mongodb -o jsonpath="{.data.mongodb-root-password}" | base64 --decode)

faas-cli secret create mongo-db-password --from-literal $MONGODB_ROOT_PASSWORD
```

The URL will be an environment variable, which you can see below.

```yaml
provider:
  name: openfaas

functions:
  follow-github:
    lang: python3-debian
    handler: ./follow-github
    image: alexellis2/follow-github:latest
    environment:
      mongo_host: mongodb.default.svc.cluster.local:27017
      write_debug: true
      combine_output: false
    secrets:
    - mongo-db-password
```

I'm also adding `write_debug: true` to enable verbose logging and `combine_output: false` to separate the logs from the function's response body.

Now we can start accessing Mongo from our code:

```python
import os
from pymongo import MongoClient
from urllib.parse import quote_plus

def get_uri():
    password=""
    with open("/var/openfaas/secrets/mongo-db-password") as f:
        password = f.read()

    return "mongodb://%s:%s@%s" % (
    quote_plus("root"), quote_plus(password), os.getenv("mongo_host"))

def handle(req):
    """handle a request to the function
    Args:
        req (str): request body
    """

    uri = get_uri()
    client = MongoClient(uri)

    db = client['openfaas']

    followers = db.followers
    follower={"username": "alexellis"}
    res = followers.insert_one(follower)

    return "Record inserted: {}".format(res.inserted_id)
```

In the example we create a new client for Mongo for each invocation, this can be optimized later. 

Deploy:

```bash
faas-cli up -f github-follow.py
```

So now we can store a hard-coded record.

```bash
$ curl -d "follower" http://127.0.0.1:8080/function/follow-github/
Record inserted: 5e43cfe69f99b387e99b81af
$ curl -d "follower" http://127.0.0.1:8080/function/follow-github/
Record inserted: 5e43cfe7744e2d157566d637
$ curl -d "follower" http://127.0.0.1:8080/function/follow-github/
Record inserted: 5e43cfe8fbc9ae21a7eb6e36
$ curl -d "follower" http://127.0.0.1:8080/function/follow-github/
Record inserted: 5e43cfe934602a05b9c56f27
```

So what's next?

* accepting user input - we may want to parse the input that the user sends, and use that dynamic content for the insert
* query and insert - what if we could both insert and query data? One way we can do that is by looking at the HTTP method, whether the user sent a GET or a PUT/POST

Let's try that out, then I'll hand it back over to you.

> My goal is to equip you with some basics, so that you can go on to do what you do best, and write your own Python.

We are using a "classic" OpenFaaS template which abstracts away and hides the HTTP details giving a pure-functional approach, you can also use Flask and the [python3-http template](https://github.com/openfaas-incubator/python-flask-template) if you prefer [a microservice style](https://www.openfaas.com/blog/stateless-microservices/).

In this instance we can access HTTP inputs through environment variables, as explained in detail in the [documentation](https://docs.openfaas.com) and [workshop](https://github.com/openfaas/workshop).

Let's also assume that the user is submitting a username in plain-text as the request body.

The method can be fetched with: `os.getenv("Http_Method")`

```python

import os, json, sys
from pymongo import MongoClient
from urllib.parse import quote_plus

def get_uri():
    password=""
    with open("/var/openfaas/secrets/mongo-db-password") as f:
        password = f.read()

    return "mongodb://%s:%s@%s" % (
    quote_plus("root"), quote_plus(password), os.getenv("mongo_host"))

def handle(req):
    """handle a request to the function
    Args:
        req (str): request body
    """

    method = os.getenv("Http_Method")
    sys.stderr.write("Method: {}\n".format(method))

    if method in ["POST", "PUT"]:
        uri = get_uri()
        client = MongoClient(uri)

        db = client['openfaas']
        followers = db.followers

        follower={"username": req.strip()}
        res = followers.insert_one(follower)
        return "Record inserted: {}".format(res.inserted_id)
    elif method == "GET":
        uri = get_uri()
        client = MongoClient(uri)

        db = client['openfaas']
        followers = db.followers

        ret = []
        for follower in followers.find():
            ret.append({"username": follower[u'username']})

        return json.dumps(ret)

    return "Method: {} not supported".format(method)
```

The `sys.stderr.write` statement added is viewable using `kubectl logs`, or `faas-cli logs` as per below:

```bash
faas-cli logs follow-github
```

### Over to you

Now it's over to you to tweak the example, try out OpenFaaS with Python3 and install your favourite libraries from pip.

If you like the example, why don't you extend it and deploy it to DigitalOcean, where you can have the function record a list of everyone who follows you? GitHub can send webhooks over HTTP for the various different event-sources in the platform.

* [GitHub webhooks](https://developer.github.com/webhooks/)

### Wrapping up

In a short period of time we were able to build a function with Python and and access to persistence through MongoDB. We then deployed that via OpenFaaS to a Kubernetes cluster of our choosing. We didn't have to worry about hiring a DevOps expert to hand-craft lengthy YAML files or to tune our Dockerfiles (a common cause of contention for development teams).

#### So what does OpenFaaS offer over "vanilla Kubernetes"?

> When deployed to Kubernetes, OpenFaaS offers an application stack just like MEAN, LAMP or JAMStack, you can watch my video [from KubeCon on the PLONK stack](https://www.youtube.com/watch?v=NckMekZXRt8) which goes into a bit more detail.

Here's an overview from 10,000ft:

* community-supported and (for customers, commercially-supported) templates for popular languages, optimized and hand-tuned
* a template store ecosystem to find community templates, see `faas-cli template store list`
* optional auto-scaling from 0 to many and back down to zero again
* a simple API to deploy to Kubernetes with best practices, which let your team ship changes quickly
* the ability to ship functions or services, without worrying about all the Kubernetes YAML files that would normally be a concern
* a welcoming and helpful community of developers, sponsors, and end-users with over 2.5k members and 20k GitHub stars

Feel free to [join us on Slack](https://slack.openfaas.io/) and to follow [@openfaas](https://twitter.com/openfaas) on Twitter.

### Try this next

Perhaps next you'd like to move to a managed Kubernetes service, or add a TLS certificate and a custom domain to your OpenFaaS functions?

* [Get TLS for OpenFaaS the easy way with arkade](https://blog.alexellis.io/tls-the-easy-way-with-openfaas-and-k3sup/)
* [Deploy OpenFaaS on Amazon EKS](https://aws.amazon.com/blogs/opensource/deploy-openfaas-aws-eks/)
* [Deploy microservices use Dockerfiles with OpenFaaS](https://www.openfaas.com/blog/stateless-microservices/)

Find out more about OpenFaaS and Python

* [Get started with the OpenFaaS workshop](htttps://github.com/openfaas/workshop/) - 12 self-paced labs for setting up a Kubernetes cluster with OpenFaaS locally or in the cloud.
* Read the [Python3 docs](https://www.python.org/download/releases/3.0/)
* [MongoDB and OpenFaaS for Node.js](https://github.com/alexellis/mongodb-function)
