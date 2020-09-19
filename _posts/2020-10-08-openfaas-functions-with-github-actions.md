---
title: "Deploy your functions to OpenFaaS with Github Actions"
description: "Bring CI/CD to your OpenFaaS deployment with Github Actions."
date: 2020-10-08
image: /images/2020-10-08-openfaas-functions-with-github-actions/lego.jpg
categories:
  - faas-netes
  - faasd
  - cicd
  - github
  - multi-arch
author_staff_member: utsav
dark_background: true
---

Learn how to bring CI-CD to your OpenFaaS functions with Github Actions

## Who should read this?

OpenFaaS was created to have the freedom to run serverless functions anywhere, be it on a Raspberry Pi, in a data center, or the cloud. This started with faas-swarm to run on Docker Swarm and faas-netes to run on Kubernetes. faas-netes is the current recommendation for running OpenFaaS in production.
If you're not a large team, or just someone who doesn't want to deal with the complexities that comes with Kubernetes then you're much better off with faasd.

But whatever shape or form you're running OpenFaaS as, if you want more automation for how your functions are built and deployed with Github Actions, this will be a good read for you.

In this tutorial, we'll see how we can get OpenFaaS functions up and running with Github Actions on a faas-netes deployment running on GKE, but the same approach is valid for all forms of OpenFaaS as it exists today whether it is faas-netes or faasd, running either in the cloud or on your desk.


## Prerequisites

* An OpenFaaS deployment that is accessible from the internet

Get started with the official documentation [here](https://docs.openfaas.com/deployment/)

* faas-cli

faas-cli is a command line tool used to interact with OpenFaaS, from deploying your functions to viewing logs.
Follow the installation instructions [here](https://docs.openfaas.com/cli/install/)

> You can follow along with the code used in this tutorial from this [repo](https://github.com/utsavanand2/hello)


## Create an OpenFaaS function

I'm going to create and deploy a Golang function for this tutorial.

```sh
# create a new directory for our project
mkdir hello
# pull golang-http templates
faas-cli template store pull golang-http
# create a new function with faas-cli
faas-cli new hello --lang golang-http
```

If you look into the root directory of the project, faas-cli has created two additional files:

```
./hello/handler.go
./hello.yml
```

The content of our handler looks something like this:
![./hello/handler.go](/images/2020-10-08-openfaas-functions-with-github-actions/handler-go.jpg)

The YAML file is used to configure the deployment and the build and runtime environment of the function
![./hello.yml](/images/2020-10-08-openfaas-functions-with-github-actions/hello-yaml.jpg)

## Setup a workflow file for Github Actions

[Github Action workflows](https://docs.github.com/en/free-pro-team@latest/actions/learn-github-actions/introduction-to-github-actions) is one of the many core components of Github Actions that lets users add an automated workflow that executes on an event, and can be used to test, build and deploy our code.
A workflow can be composed of multiple steps, each executing a particular action.
There are many published [Actions](https://github.com/marketplace?type=actions) that provide nice wrappers for common actions and tools making them easier to use, but we can also use any published Docker image. The OpenFaaS team already publishes an image for `faas-cli` that is ready to use for any workflow.

Our workflow is a simple linear process:
`Checkout` -> `Pull Templates` -> `ShrinkWrap Build` -> `OpenFaaS Login` -> `Docker Login` -> `Docker Buildx Setup` -> `Build & Push Function` -> `Deploy to OpenFaaS`

In the root directory of the project run:

```sh
mkdir -p .github/workflows
nano ./github/workflows/main.yml
```

And paste in the following contents into main.yml file

```yaml
name: CI/CD

on:
  push:
    branches: 
      - master
jobs:
  func-build:
    runs-on: ubuntu-latest
    steps:
      - 
        name: Checkout
        uses: actions/checkout@v2
      -
        name: Pull template
        uses: docker://openfaas/faas-cli:latest-root
        with:
          args: template store pull golang-http
      - 
        name: Run shrinkwrap build
        uses: docker://openfaas/faas-cli:latest-root
        with:
          args: build -f hello.yml --shrinkwrap
      -
        name: Login to OpenFaaS Gateway
        uses: docker://openfaas/faas-cli:latest-root
        with:
          args: login -p {% raw %}${{ secrets.OPENFAAS_GATEWAY_PASSWD }}{% endraw %} -g {% raw %}${{ secrets.OPENFAAS_GATEWAY }}{% endraw %}
      -
        name: Login to DockerHub
        if: success()
        uses: docker/login-action@v1
        with:
          username: {% raw %}${{ secrets.DOCKER_USERNAME }}{% endraw %}
          password: {% raw %}${{ secrets.DOCKER_PASSWORD }}{% endraw %}
      -
        name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
      - 
        name: Build and Push the OpenFaaS function
        uses: docker/build-push-action@v2
        with:
          context: ./build/hello/
          file: ./build/hello/Dockerfile
          push: true
          tags: utsavanand2/hello:latest
      - 
        name: Deploying the OpenFaaS function
        uses: docker://openfaas/faas-cli:latest-root
        with:
          args: deploy -f hello.yml       
```

> Note: Replace the Docker UserID from the image tag name with your own.

Since Github Actions requires us to use a Docker image that has a root user invoking the commands using the Docker action, so we're using the root variant of the faas-cli Docker image. Read more about it [here](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/dockerfile-support-for-github-actions#user)

The faas-cli:latest-root image has the faas-cli installed as the entrypoint, so everything set in args is passed to the faas-cli.
This will work with any of the faas-cli root tags, you can pin to any specific version of faas-cli, for example: `openfaas/faas-cli:0.12.14-root`.

## Create and configure a Github Repo with Github Actions

Initialize a git repo in the root directory of the project

```sh
# Initialize a git repo
git init
# Add a remote
git remote add origin https://github.com/<Your-Github-Username>/hello.git
# Stage and commit your changes
git add .
git commit -m "Initial Commit"
```

Create a Github Repo named hello and add the following secrets and their values to the repo for Github Actions to build push and deploy your OpenFaaS functions. Make sure that the secret names correspond with the Github workflow YAML file as defined above in the previous section.

![secrets](/images/2020-10-08-openfaas-functions-with-github-actions/secrets.jpg)

## Push the repo to Github to trigger Github Actions

```sh
git push -u origin master
```

## Check the status of your Github Actions build

Under the `Actions` tab we can check the status of the workflow

![workflow](/images/2020-10-08-openfaas-functions-with-github-actions/workflow.jpg)

Since we have successfully built and deployed our functions let's invoke it with curl.

## Invoke the function with curl

```sh
export OPENFAAS_GATEWAY=<The OPENFAAS_GATEWAY of your OpenFaaS deployment>
curl http://$OPENFAAS_GATEWAY/function/hello
```

![curl](/images/2020-10-08-openfaas-functions-with-github-actions/curl.jpg)

## Take it further

You can take this to the next level by leveraging multi-arch builds with Docker's [Buildx](https://docs.docker.com/buildx/working-with-buildx/) and the golang-http-templates which now support multi-arch builds. This means that you can deploy the same function to architectures like arm, arm64 of amd64 from a single build.

Just add a step to setup `QEMU` and pass a `platforms` key in the build step, making the last few steps concerned with Docker look something like this:

```yaml
      -
        name: Login to DockerHub
        if: success()
        uses: docker/login-action@v1
        with:
          username: {% raw %}${{ secrets.DOCKER_USERNAME }}{% endraw %}
          password: {% raw %}${{ secrets.DOCKER_PASSWORD }}{% endraw %}
      -
        name: Set up QEMU
        uses: docker/setup-qemu-action@v1
      -
        name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v1
      - 
        name: Build and Push the OpenFaaS function
        uses: docker/build-push-action@v2
        with:
          context: ./build/hello/
          file: ./build/hello/Dockerfile
          push: true
          platforms: linux/amd64,linux/arm64,linux/arm/v7
          tags: utsavanand2/hello:latest
```

You can checkout the workflow YAML supporting multi-arch builds [here](https://github.com/utsavanand2/hello/blob/multi-arch/.github/workflows/main.yml):



## Acknowledgements

Special Thanks to [Lucas Rosler](https://twitter.com/TheAxeR) and [Alex Ellis](https://twitter.com/alexellisuk) for all the precious advice and helping me out with making faas-cli more portable for CI environments than ever before.

Thanks to [Dan Burton](https://unsplash.com/@single_lens_reflex) for the background picture.