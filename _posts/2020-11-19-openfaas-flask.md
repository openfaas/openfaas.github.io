---
title: "Build a Flask microservice with OpenFaaS"
description: "Which is better Flask or serverless-style Python functions? Why not have both?"
date: 2020-11-19
image: /images/2020-11-flask/background.jpg
categories:
 - kubernetes
 - python
 - flask
author_staff_member: alex
dark_background: true

---

Which is better Flask or serverless-style Python functions? Why not have both?

## Introduction

OpenFaaS has several popular Python templates for users including some that use [Flask](https://flask.palletsprojects.com/en/1.1.x/) as their underlying technology. In this post I'll introduce you to the function-style templates, and then show you how to port a Flask app to OpenFaaS directly through a Dockerfile.

[Flask](https://flask.palletsprojects.com/en/1.1.x/) is a HTTP microservices framework for Python.

> This post is written for existing OpenFaaS users, if you're new then you should [try deploying OpenFaaS](https://docs.openfaas.com/deployment/) and following a tutorial to get a feel for how everything works. Why not start with this course? [Introduction to Serverless course by the LinuxFoundation](https://www.openfaas.com/blog/introduction-to-serverless-linuxfoundation/)

### OpenFaaS workloads and templates

An OpenFaaS workload is a container which serves HTTP on port 8080 and if you're using autoscaling, it will also need a health endpoint. That means that any container built for Google App Engine, Knative, Cloud run, or another PaaS can be deployed to OpenFaaS without changes. The good news for developers using microservices is that it's relatively easy to port your service over and get the benefits of OpenFaaS.

See also: [workload definition](https://docs.openfaas.com/reference/workloads/)

We built OpenFaaS to be more flexible and portable than AWS Lambda and Azure functions. We wanted to create something that used containers instead of zip files.

To make containers feel like cloud-FaaS we created a concept of templates that brings back the look and feel of a function, but under the hood these templates are just HTTP servers.

That's right folks. Serverless has servers.

So let's first look at [a template built for Python](https://github.com/openfaas/python-flask-template) and then how we can build a Docker image for Flask and deploy that directly.

### The Python 3 template

The python3-flask template uses Flask under the hood to build a FaaS-like handler.

This is how you consume a template:

```bash
faas-cli template store pull python3-flask
```

Then create a new function by scaffolding it out from a template:

```bash
export OPENFAAS_PREFIX=alexellis2
export FN="tester"

faas-cli new --lang python3-flask $FN
```

Finally write some code in `tester/handler.py`

```python
def handle(req):
    return "Hi" + str(req)
```

If you have dependencies, just put them into a requirements.txt file.

For native dependencies change from `python3-flask` which uses Alpine Linux to `python3-flask-debian`.

Return a HTTP code:

```python
def handle(req):
    return "request accepted", 201
```

Return custom headers:

```python
def handle(req):
    return "request accepted", 201, {"Content-Type":"binary/octet-stream"}
```

To work with the HTTP request's headers such as the Method, Path or QueryString, you can switch over to the `python3-http` template:

```bash
export OPENFAAS_PREFIX=alexellis2
export FN="http-headers"

faas-cli new --lang python3-http $FN
```

Edit `./http-headers/handler.py`:

```python
def handle(event, context):
    if event.method == 'GET':
        return {
            "statusCode": 200,
            "body": "GET request"
        }
    else:
        return {
            "statusCode": 405,
            "body": "Method not allowed"
        }
```

You could also add a switch statement and work with the path.

Depending on how much control you want over the HTTP headers you can choose between the `python3-flask` and `python3-http` templates.

See also: [the template README](https://github.com/openfaas/python-flask-template)

### Running an existing Flask app

Now for some people, using Flask is just more familiar. Perhaps they have existing code that they don't have time to refactor?

Fortunately, OpenFaaS also has a `dockerfile` template that we can use. The downside of doing this is that you now have to manage the entry-point for your application and a Dockerfile, with templates this is abstracted away and doesn't have to be repeated for each service.

```bash
export OPENFAAS_PREFIX=alexellis2
export FN="flask-service"

faas-cli new --lang dockerfile $FN
```

We'll create a Dockerfile which creates a non-root user and adds the OpenFaaS watchdog. The watchdog can be used to enable a graceful shutdown for the application, to collect metrics automatically, and to add a healthcheck endpoint to existing services without editing them. It can also re-map any HTTP port you may have, without you having to change your existing code.

Edit `flask-service/Dockerfile`:

```Dockerfile
FROM --platform=${TARGETPLATFORM:-linux/amd64} openfaas/of-watchdog:0.7.7 as watchdog
FROM --platform=${TARGETPLATFORM:-linux/amd64} python:3.7-slim-buster

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

# Uncomment if you want to use native modules
#RUN apt-get -qy update && apt-get -qy install gcc make

# Add non root user
RUN addgroup --system app && adduser app --system --ingroup app
RUN chown app /home/app

USER app
ENV PATH=$PATH:/home/app/.local/bin

WORKDIR /home/app/

COPY app.py             .
COPY requirements.txt   .

USER root
RUN pip install -r requirements.txt

WORKDIR /home/app/

RUN chown -R app:app *
USER app

ENV fprocess="python app.py"

ENV upstream_url="http://127.0.0.1:5000"
ENV mode="http"
ENV cgi_headers="true"

CMD ["fwatchdog"]
```

> The watchdog is optional, but recommended. You can also expose your flask app directly on port 8080, and add the HTTP health-check endpoint required for scale from zero.

Now create `flask-service/app.py`:

```python
# Copyright (c) Alex Ellis 2017. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

from flask import Flask, request
from waitress import serve
import os

app = Flask(__name__)

# distutils.util.strtobool() can throw an exception
def is_true(val):
    return len(val) > 0 and val.lower() == "true" or val == "1"

@app.before_request
def fix_transfer_encoding():
    """
    Sets the "wsgi.input_terminated" environment flag, thus enabling
    Werkzeug to pass chunked requests as streams.  The gunicorn server
    should set this, but it's not yet been implemented.
    """

    transfer_encoding = request.headers.get("Transfer-Encoding", None)
    if transfer_encoding == u"chunked":
        request.environ["wsgi.input_terminated"] = True

@app.route("/", defaults={"path": ""}, methods=["POST", "GET"])
def home(path):
    return "home"

@app.route("/users/", methods=['GET', 'POST', 'PUT'])
def users():
    return "get users"

@app.route('/user/<username>')
def profile(username):
    return "get profile"

if __name__ == '__main__':
    serve(app, host='0.0.0.0', port=5000)
```

And add `waitress` and `flask` to the `python-service/requirements.txt` file:

```
flask
waitress
```

Now deploy your function:

```bash
faas-cli up -f flask-service.yml
```

You can now access your Flask app via curl

```bash
curl -s http://127.0.0.1:8080/function/flask-service/
home

curl http://127.0.0.1:8080/function/flask-service/users/
get users

curl http://127.0.0.1:8080/function/flask-service/user/alex
get profile
```

### Multi-arch and ARM

If you want to publish a multi-arch image to use with your AWS Graviton server or Raspberry Pi along with Intel machines, you can use the new `faas-cli publish` command:

```bash
faas-cli publish \
  --platforms linux/amd64,linux/arm64,linux/arm/7 \
  -f flask-service.yml
```

If you want to use a specific version in your stack YAML file then you can also use a tracking tag like `:latest` with `--extra-tag latest`

Then simply run `faas-cli deploy` and specify the gateway for your OpenFaaS gateway. Kubernetes or [faasd](https://github.com/openfaas/faasd) will automatically pull the correct image for the node.

### Going to production with REST-style URLs

Another common reason users ask for Flask is because they want to see a REST-style URL and are unsure how to achieve that with functions.

Imagine we had three functions for the operations above, and wanted to map them all under a single domain with a REST-style API? You can achieve the same result as above using OpenFaaS functions and a FaaS-style handler by using the FunctionIngress custom resource.

* `api.example.com/v1/` -> `home`
* `api.example.com/v1/users` -> `get-users`
* `api.example.com/v1/user/NAME` -> `get-profile`

The mapping can be achieved with three functions using the following:

```yaml
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: home
  namespace: openfaas
spec:
  domain: "api.example.com"
  function: "home"
  ingressType: "nginx"
  path: "/v1/"
---
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: get-users
  namespace: openfaas
spec:
  domain: "api.example.com"
  function: "get-users"
  ingressType: "nginx"
  path: "/v1/users/"
---
apiVersion: openfaas.com/v1alpha2
kind: FunctionIngress
metadata:
  name: get-profile
  namespace: openfaas
spec:
  domain: "api.example.com"
  function: "get-profile"
  ingressType: "nginx"
  path: "/v1/user/(.*)"
```

See also: [REST-style API mapping for your functions](https://docs.openfaas.com/reference/tls-functions/)

## Wrapping up

We explored the workload definition, and how the use of containers means that we can deploy or port existing applications to run on OpenFaaS. We then gave some examples of the "Python 3 Flask template" from the template store, before deploying an existing Flask app using the `dockerfile` template.

It's now over to you to decide whether you want to work with a function / FaaS-style handler, or a Flask app. Perhaps you feel more comfortable with what you know? Maybe you prefer the simplicity of a function doing one thing?

Templates offer reduced duplication, there are no Dockerfiles to think about, no entrypoints, routes or TCP ports to bind. You only have to write a single handler.

Which style do you prefer? [Let us know on Twitter @openfaas](https://twitter.com/openfaas)

Would you like to keep learning? The Python 3 template is a core part of the new [Introduction to Serverless course by the LinuxFoundation](https://www.openfaas.com/blog/introduction-to-serverless-linuxfoundation/)
