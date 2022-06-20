---
title: "Create functions from source code with the OpenFaaS Function Builder API"
description: "We show you how to build function images with the OpenFaaS Function Builder API"
date: 2022-06-22
image: /images/2022-06-create-funcitons-from-source-with-pro-builder-api/background.png
categories:
- containers
- functions
- kubernetes
- oci
author_staff_member: han
---

We show you how to build function images with the OpenFaaS Function Builder API

OpenFaaS uses OCI-format container images for its workloads. Function images are usually built locally or in CI with docker and the faas-cli. Some use cases might require you to build images from your code inside your cluster. For these use cases we created the [OpenFaaS Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/). It provides a simple REST API to create functions from source code.

So why is it right for you?
- You are a service provider and you need a way to run OpenFaaS functions with custom code provided by your customers.
- You need to manage dozens or hundreds of functions. Instead of defining and maintaining hundreds of different CI jobs you can integrate with the Builder's REST API to build functions programmatically.
- You need a secure way to build images in-cluster without sharing the Docker socket.

The Function Builder API can build images in-cluster but can run without root privileges and does not need docker. It uses Builkit, developed by the Docker community to perform fast, cached, in-cluster builds.

## How to call the Function Builder API

The OpenFaaS Pro Builder can be used via a minimal HTTP API. To start a build you have to send a POST request to its `/build` endpoint. It accepts a tar archive containing a build context and build configuration as the payload.

These are the tasks we need to perform to create a payload and invoke the builder API:
1. Construct a folder called `context` with the files needed to build a container.
2. Create a configuration file called `com.openfaas.docker.config`.
3. Create a tar archive which contains `com.openfaas.docker.config` and `context/*`
4. Calculate the SHA256 HMAC signature for the tar file
5. Invoke the API via HTTP

We will first run through an example using the command-line so you get an insight in the steps required to create a build context that we can use to call the Function Builder API. We will then walk through a python example and show you how to do the same thing with code. Take a look at the [examples repository](https://github.com/welteki/openfaas-function-builder-api-examples) if you want to see the same example in different languages.

## Terminal walk-through

In this section we show how to prepare a tar archive that we can then use to invoke the builder with `curl`.

### Create the build context

We will start by creating a test function using the node17 template.
```bash
faas-cli new --lang node17 hello-world
```

To prepare our code we have to create a build context that can be sent to the builder API. The build context is the directory where you would normally run `docker build .` if you are creating your images with docker. `faas-cli build` would normally execute or fork docker, because the command is just a wrapper. To write out a build context we should bypass this behaviour, that's possible via the following command:
```
faas-cli build --shrinkwrap -f hello-world.yml
```

Our context should now be available in the `./build/hello-world/` folder with our function code and the template with its entrypoint and Dockerfile.

```
build
└── hello-world
    ├── Dockerfile
    ├── function
    │   ├── handler.js
    │   └── package.json
    ├── index.js
    ├── package.json
    └── template.yml
```

### Create a tar archive

The builder expects a tar archive with a directory containing the build context and a configuration file named `com.openfaas.docker.config`. The configuration is a JSON object that has one required property `image`.

Write the configuration to `./build/com.openfaas.docker.config`:
```bash
export DOCKER_USER="functions"
echo -n '{"image": "docker.io/'$DOCKER_USER'/hello-world:0.1.0"}' > ./build/com.openfaas.docker.config
```

In addition to the image property the config file also supports defining additional build arguments that will be passed to the build.
```
{
  "image": "docker.io/functions/hello-world:0.1.0",
  "buildArgs": {
    "BASE_IMAGE": "gcr.io/quiet-mechanic-140114/openfaas-base/node14"
  }
}
```

Once the configuration file is created we then have to create a tar archive of the context in the `./build/` directory:
```bash
cd build

# rename the build context
rm -rf context
mv hello-world context

tar cvf req.tar --exclude=req.tar
```

The faas-cli created a build context with the name of the function. The function builder requires the build context to be in a folder named `context`. That's why we have to rename it. 

The contents of the resulting tar archive should look like this:
```
./com.openfaas.docker.config
./context/
./context/index.js
./context/template.yml
./context/Dockerfile
./context/function/
./context/function/package.json
./context/function/handler.js
./context/package.json
./context/.dockerignore
```

### Invoke the builder API

HMAC validation is enabled by default on the builder. To invoke it we have to generate a SHA256 HMAC signature and pass it in the `X-Build-Signature` header:
```bash
PAYLOAD=$(kubectl get secret -n openfaas payload-secret -o jsonpath='{.data.payload-secret}' | base64 --decode)

HMAC=$(cat req.tar | openssl dgst -sha256 -hmac $PAYLOAD | sed -e 's/^.* //')

curl -H "X-Build-Signature: sha256=$HMAC" \
    -s http://127.0.0.1:8081/build \
    -X POST --data-binary @req.tar | jq
```

The API will return a JSON result with the status, logs and an image name if the image was published successfully.
```
{
  "logs": [ "Output from buildkit", "Another log line" ],
  "imageName": "docker.io/functions/hello-world:0.1.0",
  "status": "success"
}
```

### Monitor the build

The builder has additional metrics which will be scraped by the Prometheus instance installed by the OpenFaaS helm chart. The metrics can be used to monitor the number of builds in progress, the build time and number of invocations.

![The builder dashboard showing metrics for a single builder pod.](/images/2022-06-create-funcitons-from-source-with-pro-builder-api/dashboard.png)
> Pictured: metrics for the builder showing inflight builds, average duration and HTTP status codes to detect errors.

## Python walk-through

We showed you how to prepare a tar archive and invoke the builder using curl. In this part we walk through a code example to do the same thing using python code.

> The complete python example, along with examples for other languages, is [available on GitHub](https://github.com/welteki/openfaas-function-builder-api-examples).

### Prepare the build context

Just like in the previous example we start by creating a build context. You could write your own code to construct a build context with a Dockerfile and the other files required to build your container. In his example we will execute the faas-cli command from our application. By running `faas-cli build --shrinkwrap` we are able to reuse the existing OpenFaaS templates or any other template you might want to use.

In our python code we define a function `shrinkwrap`.
```python
def shrinkwrap(image, handler, lang):
    cmd = [
        "faas-cli",
        "build",
        "--lang",
        image,
        "--handler",
        handler,
        "--name",
        "context",
        "--image",
        lang,
        "--shrinkwrap"
    ]

    completed = subprocess.run(cmd)

    if completed.returncode != 0:
        raise Exception('Failed to shrinkwrap handler')
```
The function takes three arguments: the image name to build, the path to our handler directory and the template to use. It uses the [subprocess](https://docs.python.org/3/library/subprocess.html) module to spawn a new process running the `faas-cli build --shrinkwrap` command.

In this example we pass individual values to the build command using flags but you could also use a stack YAML file and run `faas-cli build -f stack.yml`.

### Create a tar archive

The function makeTar will create a tar archive containing the build context and configuration. The first argument is a dictionary for the build configuration. This will be serialised as json and written to a file `com.openfaas.docker.config` at the root of our tar archive alongside the context folder. The result is a tar archive located at the path specified in the third argument that can be used as payload for the build request.

```python
def makeTar(buildConfig, path, tarFile):
    configFile = os.path.join(path, 'com.openfaas.docker.config')
    with open(configFile, 'w') as f:
        json.dump(buildConfig, f)

    with tarfile.open(tarFile, 'w') as tar:
        tar.add(configFile, arcname='com.openfaas.docker.config')
        tar.add(os.path.join(path, "context"), arcname="context")
```

### Invoke the builder API

By default the builder has HMAC validation enabled. We have to create a SHA256 HMAC signature and invoke the API passing in the `X-Build-Signature`.

The function `callBuilder` is responsible for obtaining the HMAC signature and calling the pro-builder.
```python
def callBuilder(tarFile):
    with open(tarFile, 'rb') as t, open('payload.txt', 'rb') as s:
        secret = s.read().strip()
        data = t.read()
        digest = hmac.new(secret, data, 'sha256').hexdigest()
        headers = {
            'X-Build-Signature': 'sha256={}'.format(digest),
            'Content-Type': 'application/octet-stream'
        }
        return requests.post("http://127.0.0.1:8081/build", headers=headers, data=data)
```

We use the [hmac](https://docs.python.org/3/library/hmac.html) from the python standard library to create the HMAC signature for the tar file. The signing key required to create the signature is read from the `payload.txt` file.

You can use this command to retrieve the payload secret and write it to `payload.txt`:
```bash
kubectl get secret \
    -n openfaas \
    payload-secret -o jsonpath='{.data.payload-secret}' \
    | base64 --decode \
    > payload.txt
```

Finally we use the [requests](https://requests.readthedocs.io/en/latest/) library to invoke the builder.

### Run the script

Clone the [examples repo](https://github.com/welteki/openfaas-function-builder-api-examples) to get the complete build script.
```bash
git clone https://github.com/welteki/openfaas-function-builder-api-examples --depth=1
cd openfaas-function-builder-api-examples
```

Make sure that the pro-builder is port-forwarded to port 8081 on localhost and that the payload secret is written to `payload.txt`.
```bash
kubectl port-forward \
    -n openfaas \
    svc/pro-builder 8081:8080
```

Run the python script
```bash
python3 python-request/build.py \
    --image docker.io/functions/hello-world:0.1.0 \
    --handler ./hello-world \
    --lang node17
```

## Conclusion
We walked you through two examples to show you the tasks that need to be preformed to invoke the Function Builder API and build a container image. We put together some more examples for different languages, you can find them on GitHub:

- [Function Builder API Examples](https://github.com/welteki/openfaas-function-builder-api-examples)

Most users will find that `docker` and the `faas-cli` are sufficient for their needs. The [OpenFaaS Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/) was designed for service providers or people who need the manage a large amount of functions. It is easy to integrate with via HTTP and allows you to build images in-cluster.

OpenFaaS uses OCI-format container images for its workloads. While the focus of this post was on building function images, the Function Builder API can be used to create any container image.