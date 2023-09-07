---
title: "The faster way to iterate on your OpenFaaS functions"
description: "Learn how live reloading and local testing can help you iterate on functions faster with faas-cli."
date: 2023-09-07
categories:
- faas-cli
- openfaas
- functions
- devex
dark_background: true
author_staff_member: han
image: "/images/2023-09-develop-functions-locally/background.png"
hide_header_image: true
---

Learn how live reloading and local testing can help you iterate on functions faster with faas-cli.

We'll start by showing how testing functions on your own machine can help you iterate much more quickly than deploying each change to Kubernetes. That's where `faas-cli local-run` comes in. Then, we'll show the new `--watch` functionality in `faas-cli up`, for when it makes more sense to test and iterate within a cluster due to dependencies on other services.

This is what the typical development lifecycle of an OpenFaaS function looks like:

- Make code changes.
- Publish a new container image.
- Deploy the function.
- Wait for the new image to be pulled and become ready.

We try to minimise the amount of manual steps by bundling some of these actions into a single command. For example, running `faas-cli up` will build, push and deploy functions.

The disadvantage of this workflow is that it can introduce some delay as you will have to wait for the function image to be pushed to a registry, pulled into a node and started up each time you make changes to your code. 

Thanks to some recent work from the community a couple of new features were added to the faas-cli to further improve the development experience.

For fast local iteration on functions, a new command `faas-cli local-run` was added. The command runs a function as a Docker container directly on your machine that spins up pretty much instantly. You won't have to wait for the function to be deployed to OpenFaaS and become ready before you can invoke it.

A second new feature is the addition of the `--watch` flag. It can be used with both the `faas-cli up` as well as the `faas-cli local-run` command and tells the CLI to watch the filesystem so it can automatically build and redeploy functions as you edit and save your code.

## Run functions locally

The OpenFaaS CLI has a command, `local-run`, that allows users to test functions without deploying. It builds a function into your local image library and starts a container locally with Docker.

This has the advantage that you won't have to wait for the image to be pushed to a registry, then pulled into a node and started up.

Create a function or use an existing one and try to run it locally with `faas-cli local-run`.

We will create and run a simple nodeJs function:

```bash
# Create a new function using the node18 template
faas-cli new greeter --lang node18

# Rename the the functions yaml definition to stack.yml
mv greeter.yml stack.yml
```

Update `greeter/handler.js` so that the function returns a nice greeting message.

```js
'use strict'

module.exports = async (event, context) => {

  return context
    .status(200)
    .succeed(`Greetings from OpenFaaS!!!`)
}
```

Run the function locally:

```bash
faas-cli local-run
```

The command will first build the function and next run it locally with docker.

The output should look something like this:

```
#23 exporting to image
#23 exporting layers done
#23 writing image sha256:c384939cb1d69d510c6f1237e371aac21deb2e4ac3f9bc863852084dfda7b20a done
#23 naming to docker.io/library/echo:latest done
#23 DONE 0.0s
Image: echo:latest built.
[0] < Building echo done in 0.66s.
[0] Worker done.

Total build time: 0.66s
Image: echo:latest
Starting local-run for: echo on: http://0.0.0.0:8080

2023/09/05 15:58:55 Version: 0.9.11     SHA: ae2f5089ae66f81a1475c4664cb8f5edb6c096bf
2023/09/05 15:58:55 Forking: node, arguments: [index.js]
2023/09/05 15:58:55 Started logging: stderr from function.
2023/09/05 15:58:55 Started logging: stdout from function.
2023/09/05 15:58:55 Watchdog mode: http fprocess: "node index.js"
2023/09/05 15:58:55 Timeouts: read: 15s write: 15s hard: 10s health: 15s
2023/09/05 15:58:55 Listening on port: 8080
2023/09/05 15:58:55 Writing lock-file to: /tmp/.lock
2023/09/05 15:58:55 Metrics listening on port: 8081
node18 listening on port: 3000
```

Once the container is running, `curl` can be used to invoke the function:

```bash
curl http://127.0.0.1:8080
```

You should see your greeting message in the response printed to the console.

Function logs for each invocation can also be inspected in the console:

```
2023/09/05 15:58:55 Metrics listening on port: 8081
node18 listening on port: 3000
2023/09/05 16:00:07 POST / - 200 OK - ContentLength: 96B (0.0353s)
```

## Select a port

By default the function container publishes port 8080. The `--port` flag can be used to change the port in case you are already port-forwarding the OpenFaaS gateway or when port 8080 is not available for another reason.

```bash
faas-cli local-run greeter --port 3001
```

This will run the greeter function and make it available on port `3001`.

```bash
curl -i http://127.0.0.1:3001
```

## Run multiple functions

The local-run command is great for running and testing individual OpenFaaS functions but it can only run a single function at a time.

If your stack.yaml file only contains a single function, local-run will run that function by default. When there are multiple functions you need to add the name of the function you want to run as an extra argument to the command.

Create a second function, `echo` and append it to the stack.yml file.

```bash
faas-cli new greeter --lang node18 --append stack.yml
faas-cli local-run greeter
```

Since functions are running as an individual Docker container with local-run you can not talk to other functions or the OpenFaaS gateway.

If you are building function pipelines where you need to talk to other functions or if you need to call other services in your cluster, local-run might not be the best option.

While there are some workarounds like port-forwarding the gateway first and making the gateway url configurable in your function through an environment variable you might want to use `faas-cli up --watch` instead.

Running `faas-cli up` will build, push and deploy all functions in the `stack.yml` file. The `--watch` flag will tell the faas-cli to monitor the function source files for any changes and automatically rebuild and redeploy functions as you edit and save your code.

We take a more detailed look into the watch functionality later in this article.

## Use secrets with local-run

All functions can consume secrets in the same way, by reading a file from: `/var/openfaas/secrets/NAME`

To mount a secret in a function the secret name has to be added to the list of secrets in the stack YAML file.

As an example we will add a secret named `api-key` to the echo function:

```yaml
functions:
  echo:
    lang: node18
    handler: ./echo
    image: echo:latest 
    secrets:
      - api-key
```

The local-run command looks for secret files in the `.secrets` folder. You will need to create any secrets you want in this location.

All secrets included in a functions stack.yaml will be mounted into the function container so they can be read from their usual location,`/var/openfaas/secrets/NAME, and used within the function.

Create the `.secrets` folder in your local directory and add a file named api-key.

```bash
mkdir .secrets
echo "secret-access-token" > .secrets/api-key
```

We will use the secret to add authorization to the echo function. Update `./echo/handler.js` to read the secret file from `/var/openfaas/secrets/api-key` and validate the Authorization header against the api-key:

```js
'use strict'

const { readFile } = require('fs').promises

module.exports = async (event, context) => {
  // Read the api-key from an OpenFaaS secret.
  let token = await readFile("/var/openfaas/secrets/api-key", )

  const result = {
    'body': JSON.stringify(event.body),
    'content-type': event.headers["content-type"]
  }
  
  let authHeader = event.headers["authorization"]
  let authToken = ""

  // Get the bearer token from the authorization header.
  if (authHeader.startsWith("Bearer ")){
    let parts = authToken.Split(" ")
    authToken = parts[1]
  } else {
    return context
      .status(400)
      .succeed("Invalid authorization header")
  }

  // Verify bearer token matches the api-key.
  if (authToken != token) {
    return context
      .status(401)
      .succeed("Invalid api key")
  }

  return context
    .status(200)
    .succeed(result)
}
```

Run the function with local-run and see that the secret is mounted in the container and can be read for use within the function. A HTTP 401 status code should be returned if you invoke the function with an invalid api-key.

Run the echo function:

```bash
faas-cli local-run echo
```

Invoke the function with in invalid api-key:

```bash
$ curl -s http://127.0.0.1:8080 \
  -H "Authorization: Bearer invalid"
  -H "Content-Type: text/plain" \
  -d "Greetings from OpenFaaS"

HTTP/1.1 401 Unauthorized
Connection: keep-alive
Content-Length: 15
Content-Type: text/html; charset=utf-8
Date: Thu, 07 Sep 2023 11:20:50 GMT
Etag: W/"f-DQI+tV0HvT0NM/9khJk6PQXU+K4"
Keep-Alive: timeout=5
X-Duration-Seconds: 0.003185

Invalid api key%
```

Invoking the function with the correct api-key that we saved in the secret should return a HTTP 200 status code.

```bash
$ curl -s http://127.0.0.1:8080 \
  -H "Authorization: Bearer secret-access-token"
  -H "Content-Type: text/plain" \
  -d "Greetings from OpenFaaS"

HTTP/1.1 200 OK
Connection: keep-alive
Content-Length: 66
Content-Type: text/html; charset=utf-8
Date: Thu, 07 Sep 2023 11:15:30 GMT
Etag: W/"42-ql9Q2lRIiMOJhodGVWvMjGR/Ezw"
Keep-Alive: timeout=5
X-Duration-Seconds: 0.004418

{"body":"\"Greetings from OpenFaaS\"","content-type":"text/plain"}%
```

## Automatic rebuilds by watching the filesystem

Another feature that can be helpful to iterate on functions quickly during development is the built in watch functionality of the CLI.

The `--watch` flag can be used with both the `local-run` and `up` command. Adding the flag will tell the cli to watch the filesystem for any changes to the function source files and automatically re-build and deploy functions on save.

When using `--watch` flag with `faas-cli up` it is recommended to also set `--tag=digest`. This ensures unique image tags are generated for each build. The next section goes into more detail about the `--tag` flag.

<script async id="asciicast-fqJamTOlxOEijhhedMR98tAvL" src="https://asciinema.org/a/fqJamTOlxOEijhhedMR98tAvL.js"></script>

## Generated image tags

All OpenFaaS functions are built into container images. By default if no image tag is included for a function in the stack.yml file the `:latest` tag is used. When iterating over functions and pushing them to an image registry it is a best practice to organise different image versions using tags instead of always pushing to `:latest`.

There are two options to set tags for function images.

1. Let the faas-cli generate the tag automatically.
2. Set the image tag in the stack.yml file.

The `--tag` option can be used with the `build`, `push` and `deploy` sub-commands of the faas-cli. If this flag is provided, image tags for functions will automatically be generated based on available metadata. This can be either Git metadata like the commit sha or branch name or digest of the function handler content.

The generated tag is always suffixed to any tag defined in the stack.yml file or `latest` if no tag is defined.

Some examples:

When using the flag `--tag=sha` the image tag used in the stack.yml file is suffixed with the short Git SHA. e.g

```yaml
functions:
  echo:
    lang: node18
    handler: ttl.sh/openfaas/echo
    image: echo:0.2
```

For this stack.yml file the resulting image name will be `echo:0.2-cf59cfc`

If no tag is set in the stack.yml file the suffix is appended to latest.

```
image: echo => image: echo:latest-cf59cfc      
```

If you are using `faas-cli up` with the `--watch` flag we recommend also setting `--tag=digest`. The digest is calculated from the function source code and will ensure a unique image tag is generated and pushed for every code change.

> Find an overview of [all the available tag versions](https://docs.openfaas.com/cli/tags/) in the docs.

Alternatively [environment variable substitution](https://docs.openfaas.com/reference/yaml/#yaml-environment-variable-substitution) can be used to set the image.

Here is an example of a stack.yml file:

```yaml
functions:
  echo:
    lang: node18
    handler: ttl.sh/openfaas/echo
    image: echo:${FN_VERSION:-latest}
```

The value of `FN_VERSION` can be set through en environment variable when running commands like `faas-cli up`, `build` or `publish`:

```
FN_VERSION="0.2" faas-cli build
```

Environment variable substitution and the `--tag` flag can also be used together.

## Conclusion

We set out to show you how the new `local-run` command worked for faster iteration, the `--watch` flag for live-reloading as you edit, and the `--tag=digest` flag to generate dynamic tags as you edit.

When it comes to iterating on functions, doing a full deployment with faas-cli up is the easiest and most realistic way to test your work, however, faas-cli local-run can speed things 
up if your function doesn't have a lot of dependencies.

You may also like:

- [Run a registry on your computer to save on push an pull time](https://docs.openfaas.com/tutorials/local-kind-registry/)
- [Smart rebuilds and live updates for OpenFaaS functions with Tilt](https://www.openfaas.com/blog/tilt/)

Feel free to tweet to [@openfaas](https://twitter.com/openfaas) with your comments, questions and suggestions.
