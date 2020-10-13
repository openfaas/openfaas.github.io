---
title: "Build and deploy OpenFaaS functions with GitHub Actions"
description: "Build and deploy functions to OpenFaaS anywhere with GitHub Actions and multi-arch images"
date: 2020-10-13
image: /images/2020-10-github-actions/lego.jpg
categories:
  - faas-netes
  - faasd
  - cicd
  - github
  - multi-arch
author_staff_member: utsav
dark_background: true
---

Build and deploy functions to OpenFaaS anywhere with GitHub Actions and multi-arch images

## Introduction: automating function updates

OpenFaaS was created to have the freedom to run serverless functions anywhere you want, whether that be within your on-premises environment, on AWS, or even on a Raspberry Pi in your home. Whichever way you're running OpenFaaS, you won't get far without a way to build and deploy functions, and at small scale, you may be doing this manually.

When you're ready to level-up your operations, and update functions after each commit is pushed, or each Pull Request is merged, then build systems like GitLab CI, Travis, CircleCI and GitHub Actions become essentials parts of your infrastructure.

Over the past few years this has meant installing Docker on the build system, and running the `docker` command to build an image, push it to a registry, and to then deploy it. Recently advancements in cross-compilation and the newer container builder `buildkit` means we can build images for multiple platforms with ease, so that an image can be deployed to an AWS Graviton instance with an ARM processor, and to a regular EC2 node using a `x86_64` (Intel) processor.

So in this tutorial I'll show you how to build and deploy functions anywhere using GitHub Actions and multi-arch images that can run on a cloud instance, or on your Raspberry Pi homelab.

### Prerequisites

Kubernetes is our recommendation for teams running at scale, but [faasd](https://www.openfaas.com/blog/faasd-tls-terraform/) provides a suitable alternative for smaller teams.

* An OpenFaaS deployment using Kubernetes or faasd

  You can deploy OpenFaaS [here](https://docs.openfaas.com/deployment/)

* Publicly accessible network OpenFaaS gateway

  Your OpenFaaS gateway should be accessible from the Internet and have TLS enabled for security. If you are running behind a firewall, or at home then checkout the [inlets-operator project](https://docs.inlets.dev/) to make your OpenFaaS gateway accessible from the Internet.

* faas-cli

  faas-cli is a command line tool used to interact with OpenFaaS, from deploying your functions to viewing logs.
  Follow the installation instructions [here](https://docs.openfaas.com/cli/install/)

> All code samples are available in this repo: [github.com/utsavanand2/hello](https://github.com/utsavanand2/hello)

### Create a function using the Golang template

Create a repository on GitHub called `hello` and clone it.

I'm going to create and deploy a Golang function for this tutorial using the `golang-http` template, which closely resembles a HTTP handler in Go's standard library.

```bash
# Change the directory into the repository
cd hello

# Pull golang-http templates
faas-cli template store pull golang-http

# Create a new function with faas-cli
faas-cli new hello --lang golang-http
```

If you look into the root directory of the project, faas-cli has created two additional files:

```bash
./hello/handler.go
./hello.yml
```

The content of our handler looks something like this:
![./hello/handler.go](/images/2020-10-github-actions/handler-go.jpg)

The YAML file is used to configure the deployment and the build and runtime environment of the function
![./hello.yml](/images/2020-10-github-actions/hello-yaml.jpg)

### Setup a workflow file for GitHub Actions

[GitHub Action workflows](https://docs.github.com/en/free-pro-team@latest/actions/learn-github-actions/introduction-to-github-actions) is one of the many core components of GitHub Actions that lets users add an automated workflow that executes on an event, and can be used to test, build and deploy our code.

A workflow can be composed of multiple steps, each executing a particular action.
There are many published [Actions](https://github.com/marketplace?type=actions) that provide nice wrappers for common actions and tools making them easier to use, but we can also use any published Docker image. The OpenFaaS team already publishes an image for `faas-cli` that is ready to use for any workflow.

Our workflow is a simple linear process:
`Checkout` -> `Pull Templates` -> `Shrink-wrap a Docker context` -> `OpenFaaS Login` -> `Docker Login` -> `Docker Buildx Setup` -> `Build & Push Function` -> `Deploy to OpenFaaS`

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

> Note: replace the `DOCKER_USERNAME` from the image tag name with your own.

Since GitHub Actions requires us to use a Docker image that has a root user invoking the commands using the Docker action, so we're using the root variant of the faas-cli Docker image. Read more about it [here](https://docs.github.com/en/free-pro-team@latest/actions/creating-actions/dockerfile-support-for-github-actions#user)

The faas-cli:latest-root image has the faas-cli installed as the entrypoint, so everything set in args is passed to the faas-cli.
This will work with any of the faas-cli root tags, you can pin to any specific version of faas-cli, for example: `openfaas/faas-cli:0.12.14-root`.

### Add secrets to your GitHub repo for the build

Add the following secrets and their values to the repo for GitHub Actions to build push and deploy your OpenFaaS functions. Make sure that the secret names correspond with the GitHub workflow YAML file as defined above in the previous section.

![secrets](/images/2020-10-github-actions/secrets.jpg)

Now trigger a build by editing one of the files and running `git push`.

### Check the status of your GitHub Actions build

Under the `Actions` tab we can check the status of the workflow

![workflow](/images/2020-10-github-actions/workflow.jpg)

Since we have successfully built and deployed our functions let's invoke it with curl.

### Invoke the function with curl

```sh
export OPENFAAS_GATEWAY=<The OPENFAAS_GATEWAY of your OpenFaaS deployment>
curl http://$OPENFAAS_GATEWAY/function/hello
```

![curl](/images/2020-10-github-actions/curl.jpg)

## Take it further

You can take this to the next level by leveraging multi-arch builds with Docker's [Buildx](https://docs.docker.com/buildx/working-with-buildx/) and the golang-http-templates which now support multi-arch builds. This means that you can deploy the same function to architectures like arm, arm64 of amd64 from a single build.

The two changes are to set up an emulation tool for Linux called [qemu](https://www.qemu.org/) and to provide a list of desired architectures for the images.

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

You can see the full workflow YAML file supporting multi-arch builds here: [main.yml](https://github.com/utsavanand2/hello/blob/multi-arch/.github/workflows/main.yml):

### Join the community

Have you got questions, comments, or suggestions? Join the community on [Slack](https://slack.openfaas.io).

Would you like help setting up your OpenFaaS installation, or someone to call when things don't quite go to plan? [Our Premium Subscription plan](https://www.openfaas.com/support/) gives you a say in the project roadmap, a support contact, and access to Enterprise-grade authentication with OIDC.

### Acknowledgements

Special Thanks to [Lucas Rosler](https://twitter.com/TheAxeR) and [Alex Ellis](https://twitter.com/alexellisuk) for all guidance and for merging changes into OpenFaaS to better support this workflow.

Thanks to [Dan Burton](https://unsplash.com/@single_lens_reflex) for the background picture.