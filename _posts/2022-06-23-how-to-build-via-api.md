---
title: "How to build functions from source code with the Function Builder API"
description: "We show you how to build functions programmatically with the OpenFaaS Function Builder API"
date: 2022-06-23
image: /images/2022-06-how-to-build-via-api/background.png
categories:
- containers
- functions
- kubernetes
- oci
author_staff_member: han
---

We show you how to build functions programmatically with the OpenFaaS Function Builder API.

If you've already used OpenFaaS, then you'll be familiar with the `faas-cli build` and `faas-cli up` commands. These are convenient wrappers for Docker, that can be used on your own machine during development, and on a CI server to publish new versions of your functions. The Template Store is a handy way to find templates for writing functions that you can also customise if you need.

How does `faas-cli` work? It takes a template, and then overlays your code on top, making a *build context*. The build context is then passed over to Docker, which finds the Dockerfile at the root-level, and all your code, and gets to work building an OCI-compatible container image, which can be deployed to OpenFaaS.

So why would you want to build with via an API instead?

- You are a service provider and you need a way to run OpenFaaS functions with custom code provided by your customers - think of [Waylay.io](https://www.openfaas.com/blog/low-code-automation/) and [LivePerson](https://www.youtube.com/watch?v=bt06Z28uzPA)
- You need to manage dozens or hundreds of functions. Instead of defining and maintaining hundreds of different CI jobs you can integrate with the Builder's REST API to build functions programmatically.
- You need a secure way to build images in-cluster without sharing the Docker socket, resorting to Docker In Docker (DIND) or bespoke tools like Kaniko.

The Function Builder API provides a secure way to build containers using via a HTTP REST call, making it easy to integrate with your existing tools and products. It doesn't need root privileges, and makes use of BuildKit which was developed by the Docker community, for fast, efficient and isolated builds.

We'll show you how to use the builder using `curl` which will give you everything you need to write your own integration in code, but we're also providing examples for Python and Node.js to get you started.

See the docs: [OpenFaaS Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/)

Code examples with: [Node and Python](https://github.com/welteki/openfaas-function-builder-api-examples)

## How to call the Function Builder API

The OpenFaaS Pro Builder can be used via a simple HTTP API. To start a build you have to send a POST request to its `/build` endpoint. It accepts a tar archive containing a build context and build configuration as the payload. Any caller of the API must sign the payload before invoking the API.

![Conceptual diagram of building from source code](/images/2022-06-how-to-build-via-api/builder-api-flow.png)

> A conceptual diagram of going from source code, and a template to a container ready to deploy to OpenFaaS

These are the tasks we need to preform to create a payload and invoke the builder API:

1. Construct a folder called `context` with the files needed to build a container.
2. Create a configuration file called `com.openfaas.docker.config`.
3. Create a tar archive which contains `com.openfaas.docker.config` and `context/*`
4. Calculate the SHA256 HMAC signature for the tar file
5. Invoke the API via HTTP, adding the HMAC signature as a header.

Then you'll receive a JSON response with the logs, and the final image name:

```
{
    "log": [
        "v: 2022-06-23T09:10:12Z [ship 15/16] RUN npm test 0.35s",
        "v: 2022-06-23T09:10:13Z [ship 16/16] WORKDIR /home/app/",
        "v: 2022-06-23T09:10:13Z [ship 16/16] WORKDIR /home/app/ 0.09s",
        "v: 2022-06-23T09:10:13Z exporting to image",
        "s: 2022-06-23T09:11:06Z pushing manifest for ttl.sh/openfaas-image:1h@sha256:b077f553245c09d789980d081d33d46b93a23c24a5ec0a9c3c26be2c768db93e 0",
        "s: 2022-06-23T09:11:09Z pushing manifest for ttl.sh/openfaas-image:1h@sha256:b077f553245c09d789980d081d33d46b93a23c24a5ec0a9c3c26be2c768db93e 0",
        "v: 2022-06-23T09:10:13Z exporting to image 5.18s"
    ],
    "image": "ttl.sh/openfaas-image:1h",
    "status": "success"
}
```

## Walk-through with curl

In this section we show how to prepare a tar archive that we can then use to invoke the builder with `curl`.

### Create the build context

We will start by creating a test function using the node17 template.

```bash
faas-cli new --lang node17 hello-world
```

To prepare our code we have to create a build context that can be sent to the builder API. The build context is the directory where you would normally run `docker build .` if you are creating your images with docker. `faas-cli build` would normally execute or fork docker, because the command is just a wrapper. To write out a build context we should bypass this behaviour, that's possible via the following command:

```bash
faas-cli build --shrinkwrap -f hello-world.yml
```

The build context will now be available in the `./build/hello-world/` folder with our function code and the template with its entrypoint and Dockerfile.

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

### Create the tar archive

The builder expects a tar archive with a directory containing the build context and a configuration file named `com.openfaas.docker.config`. The configuration is a JSON object that has one required property `image`.

Write the configuration to `./build/com.openfaas.docker.config`:

Here we're using the ttl.sh temporary registry which is easy to use for testing the workflow, since it doesn't require any authentication.

```bash
echo -n '{"image": "ttl.sh/openfaas-image:1h"}' > ./build/com.openfaas.docker.config
```

> The syntax `:1h` will make the image expire and be deleted after one hour, in production, you'll be using your own registry such as the Docker Hub, GHCR or GCR.io, etc, with authentication enabled.

Alternatively, you can use the Docker Hub or any other registry by prefixing `docker.io` for instance: `docker.io/functions/hello-word:0.1.0`.

```bash
echo -n '{"image": "docker.io/'$DOCKER_USER'/hello-world:0.1.0"}' > ./build/com.openfaas.docker.config
```


In addition to the image property the config file also supports defining additional build arguments that will be passed to the build.

```
{
  "image": "ttl.sh/openfaas-image:1h",
  "buildArgs": {
    "NODE_ENV": "PRODUCTION"
  }
}
```

Once the configuration file is created we then have to create a tar archive of the context in the `./build/` directory.

The faas-cli created a build context with the name of the function. The function builder requires the build context to be in a folder named `context`, so we'll rename it:

```bash
cd build

# rename the hello-world folder to "context"
rm -rf context
mv hello-world context

tar cvf req.tar --exclude=req.tar .
```

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

HMAC validation is enabled by default on the builder, to invoke it you'll need to generate a SHA256 HMAC signature and pass it in the `X-Build-Signature` header. This prevents unauthorized users from accessing the builder API.

```bash
PAYLOAD=$(kubectl get secret -n openfaas payload-secret -o jsonpath='{.data.payload-secret}' | base64 --decode)

HMAC=$(cat req.tar | openssl dgst -sha256 -hmac $PAYLOAD | sed -e 's/^.* //')

curl -H "X-Build-Signature: sha256=$HMAC" \
    -s http://127.0.0.1:8081/build \
    -X POST --data-binary @req.tar | jq
```

> Did you know? Node.js, Python, Go and other languages have built-in support for creating tar files and for calculating a HMAC. You'll also find HMAC used with webhooks.

After a few seconds, the API will return a JSON result with the result from the build including the logs, status and an image name if the container was published successfully.

```
{
  "logs": [ "Output from buildkit", "Another log line" ],
  "imageName": "docker.io/functions/hello-world:0.1.0",
  "status": "success"
}
```

### Monitor the build

Once you start building containers at scale, it's going to be important to know how things are going.

The builder has metrics that are scraped automatically and made available by the Prometheus instance installed in the OpenFaaS helm chart.

You'll get:

* The number of builds in progress
* The average build time of the builds
* The number of invocations and HTTP response codes

OpenFaaS Pro users can also correlate the RAM and CPU usage of the builders, to see if there's a bottleneck, or a need to scale out to add more builders.

![The builder dashboard showing metrics for a single builder pod.](https://docs.openfaas.com/images/builder-metrics.png)
> Pictured: metrics for the builder showing inflight builds, average duration and HTTP status codes to detect errors.

## Python walk-through

We showed you how to prepare a tar archive and invoke the builder using curl. In this part we walk through a code example to do the same thing using Python code.

> The complete Python example, along with examples for other languages, is [available on GitHub](https://github.com/welteki/openfaas-function-builder-api-examples).

### Prepare the build context

Just like in the previous example we start by creating a build context. You could write your own code to construct a build context with a Dockerfile and the other files required to build your container. In his example we will execute the faas-cli command from our application. By running `faas-cli build --shrinkwrap` we are able to reuse the existing OpenFaaS templates or any other template you might want to use.

In our Python code we define a function `shrinkwrap`.

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

The function takes three arguments: the image name to build, the path to our handler directory and the template to use. It uses the [subprocess](https://docs.Python.org/3/library/subprocess.html) module to spawn a new process running the `faas-cli build --shrinkwrap` command.

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

We use the [hmac](https://docs.Python.org/3/library/hmac.html) from the Python standard library to create the HMAC signature for the tar file. The signing key required to create the signature is read from the `payload.txt` file.

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

Run the Python script
```bash
python3 python-request/build.py \
    --image docker.io/functions/hello-world:0.1.0 \
    --handler ./hello-world \
    --lang node17
```

How long did it take?

Try running the build a second time, once the builder has the base images cached, you'll see a much quicker overall time on subsequent builds.

If you were to deploy your Python code to a Kubernetes cluster, then you'd want to invoke the builder via its internal service name of: `http://pro-builder.openfaas:8080`.

## Deploying your new function automatically

Now that you've built a function via API, you can deploy it using faas-cli deploy, or using the OpenFaaS REST API:

```bash
export HOST=http://127.0.0.1:8080
export PASSWORD="" # OpenFaaS REST API password
export FUNCTION_NAME="hello-world"

export IMAGE=docker.io/functions/hello-world:0.1.0 

curl -s \
  --data-binary \
  '{"image":"'"$IMAGE"'", "service": "'"$FUNCTION_NAME"'"}' \
  http://admin:$PASSWORD@$HOST/system/functions
```

If you need any additional parameters, like environment variables, labels, etc, you can also set them here, or review the OpenFaaS Swagger definition for more fields.

The [eBook Serverless For Everyone Else](https://gumroad.com/l/serverless-for-everyone-else) has detailed examples on how to use the OpenFaaS REST API.

## Conclusion

We walked you through two examples to show you the tasks that need to be preformed to invoke the Function Builder API and build a container image. The first example was with curl and ttl.sh, so that you can try out the approach quickly, to see what it's like. Then we put together some more examples for different languages, you can find them on GitHub:

- [Function Builder API Examples](https://github.com/welteki/openfaas-function-builder-api-examples)

You'll find more detailed instructions in the documentation and in the Helm chart:

- [Docs: Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/)
- [Function Builder API Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder)

OpenFaaS uses OCI-format for functions, and whilst the focus of this post was on building functions, the Function Builder API can be used to create any container image from a valid Docker context. You could even use it to build the core services that make up OpenFaaS itself, or the rest of your application.

Most users will find that `docker` and the `faas-cli` are sufficient for their needs. The [OpenFaaS Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/) was designed for service providers or people who need the manage a large amount of functions or for those who need to build functions on-demand. It is easy to integrate with via HTTP and allows you to build images in-cluster, in a secure way.

OpenFaaS Pro customers, already have access to the Function Builder API, but if you're still using the Community Edition, then feel free to reach out for a demo or trial key.

If you'd like to talk to us, we'd be happy to speak to you:

[Set up a meeting with us](https://openfaas.com/support/)
