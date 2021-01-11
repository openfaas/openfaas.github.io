---
title: "How to developing and test your GitHub Apps with faasd"
description: "In this guide, we are going to demonstrate how to build our GitHub App and run it locally on our faasd instance then expose it to the internet using inlets to be able to Github can send events to it"
tags: inlets-pro inletsctl go github-application faasd rasperry-pi caddy tls
author_staff_member: developer-guy
dark_background: true
image: /images/2021-01-15-github-application-using-go-and-inlets-pro/faasd-issue-bot.png
date: 2021-01-15


---

How to build our GitHub App and run it locally on our faasd instance then expose it to the internet using inlets to be able to Github can send events to it

# Introduction

In this guide, we are going to develop a [GitHub App](https://docs.github.com/en/free-pro-team@latest/developers/apps) using Go, then we deploy it as a serverless function to make use of [faasd](https://github.com/openfaas/faasd) which is a lightweight & portable faas engine.We are also going to do this demo on our local environment, so we should open our function which runs on our local environment to the Internet so Github can send events to our function. In order to do that we use inlets-pro which provides secure TCP/L4 tunnels.

GitHub Apps are first-class actors within GitHub. A GitHub App acts on its own behalf, taking actions via the API directly using its own identity, which means you don't need to maintain a bot or service account as a separate user. GitHub Apps can be installed directly on organizations and user accounts and granted access to specific repositories. They come with built-in webhooks and narrow, specific permissions. When you set up your GitHub App, you can select the repositories you want it to access. For example, in this guide we are going to develop a Github App that respond or close the comments for your repositories that you installed Github App for. Also there is a two good examples available on that topic: [Derek](https://github.com/alexellis/derek) and [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud).

Derek is a Github App that reduces fatigue for maintainers by automating governance and delegating permissions to your team and community. It provides the following automations:
- Generate changelogs for releases with PRs merged and commits added
- Let designated non-admin users manage Issues and PRs by commenting Derek <command> or /command
- Enforce Developer Certificate of Origin (DCO) checking (optional)
- Automatically label/flag PRs without a Description

OpenFaaS Cloud is designed as Multi-user OpenFaaS Platform. With OpenFaaS Cloud functions are managed through typing git push which reduces the tooling and learning curve required to operate functions for your team. As soon as OpenFaaS Cloud receives a push event from git it will run through a build-workflow which clones your repo, builds a Docker image, pushes it to a registry and then deploys your functions to your cluster. Each user can access and monitor their functions through their personal dashboard.

## Pre-requisites

* DigitalOcean Account - We are going to use DigitalOcean as a provider to host our exit-node.
* arkade - arkade provides a portable marketplace for downloading your favourite devops CLIs and installing helm charts, with a single command.
* inletsctl - inletsctl automates the task of creating an exit-node on cloud infrastructure. 
* inlets-pro - You can use inlets-pro to tunnel out any TCP traffic from an internal network to another network. 
* multipass - Multipass provides a command line interface to launch, manage and generally fiddle about with instances of Linux.
* faas-cli - This is a CLI for use with OpenFaaS - a serverless functions framework for Docker & Kubernetes.

Now we are ready to go 🚀

## Setup exit-node server on DigitalOcean
For this tutorial you will need to have an account and API key with one of the [supported providers](https://github.com/inlets/inletsctl#featuresbacklog), or you can create an exit-server manually and install inlets PRO there yourself.

For this tutorial, the DigitalOcean provider will be used. You can get [free credits on DigitalOcean with this link](https://m.do.co/c/8d4e75e9886f).

Create an API key in the DigitalOcean dashboard with Read and Write permissions, and download it to a file called do-access-token in your home directory or set this token as an environment variable like this:

```bash
$ export INLETS_ACCESS_TOKEN="<digitalocean_api_token>"
```

You need to know the IP of the machine you to connect to on your local network, for instance 192.168.0.35 or 127.0.0.1 if you are running inlets PRO on the same host as SSH.

You can use the inletsctl utility to provision exit-servers with inlets PRO preinstalled, it can also download the inlets-pro CLI.

```bash
curl -sLSf https://inletsctl.inlets.dev | sh
sudo mv inletsctl /usr/local/bin/
sudo inletsctl download --pro
```

Finally, start your exit-node server on the fra1 region.

```bash
$ inletsctl create \
  --provider digitalocean \
  --access-token-file ~/do-access-token \
  --region lon1 \
  --pro
```

If everything goes well, you should see your newly created "exit-node" on the homepage of your the DigitalOcean account like the following:

![inlets-droplet](/images/2021-01-15-github-application-using-go-and-inlets-pro/inlets-droplet.png)

> If you curious about what the "exit-node or exit-server" is, you can follow a link in the inlets documentation [here](https://docs.inlets.dev/#/?id=exit-servers).

## Setting up a new GitHub App

To register a new app, visit the app settings page in your GitHub profile, and click New GitHub App.

![register-github-app](/images/2021-01-15-github-application-using-go-and-inlets-pro/register-github-app.png)
You'll see a form where you can enter details about your app. See "Creating a GitHub App" for general information about the fields on this page. For the purposes of this guide, you'll need to enter specific data in a few fields:

For more details you can check it out the [link](https://docs.github.com/en/free-pro-team@latest/developers/apps/setting-up-your-development-environment-to-create-a-github-app#step-2-register-a-new-github-app)

The most important parts of this form are "Webhook URL,Webhook Secret and Private keys":

* Webhook URL : You should set the IP address of the output of the command above.
![webhook-url](/images/2021-01-15-github-application-using-go-and-inlets-pro/webhook-url.png)
  
* Webhook Secret : Define a secret for your Webhook.
![webhook-secret](/images/2021-01-15-github-application-using-go-and-inlets-pro/webhook-secret.png)
  
* Private Key : Generate and download private key for your Github Application.
![private-key](/images/2021-01-15-github-application-using-go-and-inlets-pro/private-keys.png)

Also, *do not forget to request permissions to Read & Write the repository's issues.*
![issues](/images/2021-01-15-github-application-using-go-and-inlets-pro/permissions.png)
  
Finally, we registered our application.
![github-app](/images/2021-01-15-github-application-using-go-and-inlets-pro/app.png)
  
## Get up and running with your own faasd installation on your Mac
In order to get up and running with your own faasd installation on your Mac you can use multipass.For more details you can follow the [link](https://github.com/openfaas/faasd/blob/master/docs/MULTIPASS.md).

Let's start our Ubuntu VM with multipass.First, we need a cloud-config.txt to set up faasd while bootstrapping VM.

```bash
$ curl -sSLO https://raw.githubusercontent.com/openfaas/faasd/master/cloud-config.txt
```

Then, we need to update the SSH key to match your own, edit cloud-config.txt:

```
$ ssh-keygen -t rsa -b 4096 -C "developerguyn@gmail.com" -f $PWD/id_rsa
```

Replace the _ssh_authorized_keys::ssh-rsa_ value with the contents of `~/.ssh/id_rsa.pub`, which is defined in `cloud-config.txt`.

Finally, boot the VM

```bash
$ multipass launch --cloud-init cloud-config.txt  --name faasd
```

Check the VM if it is working properly

```bash
$ multipas list
Name                    State             IPv4             Image
faasd                   Running           192.168.64.25    Ubuntu 20.04 LTS
```

## Build and Deploy function
For this demo, we are going to use golang to develop our GitHub App, in order to do that, first, we need to pull the corresponding function template for the golang.

We need to install "faas-cli" tool for that but we need to install arkade first because arkade is the marketplace for our favourite devops CLIs.

```bash
$ curl -sLS https://dl.get-arkade.dev | sudo sh
```

Then, let's install our faas-cli tool.

```bash
$ arkade get faas-cli
```

Finally,we can continue to create our function.

```bash
# let's look at the available Go function templates within the OpenFaaS store
$ faas-cli template store list | grep -i "go"
go                       openfaas           Classic Golang template
golang-http              openfaas           Golang HTTP template
golang-middleware        openfaas           Golang Middleware template
# We are going to use golang-middleware function template, let's pull it.
$ faas-cli template store pull golang-middleware
# Then, create the function itself.
$ faas-cli new issues-bot --lang golang-middleware --prefix <DOCKER_HUB_ID>
```

You can find all the code details in the [GitHub repository](https://github.com/developer-guy/faasd-github-bot).

After created the function, we need to define some arguments, environments and secrets for the function.
Let's add them:

```yaml
  build_args:
      GO111MODULE: on
    secrets:
      - webhook-secret # your secret goes here
      - private-key-secret # your private key goes here
    environment:
      APP_ID: "" #your app id goes here
```

Finally, we need to create those secrets above with make use of faas-cli.

Let's create our secrets.

```bash
$ export WEBHOOK_SECRET="sup3rs3cr3t"
$ faas-cli secret create webhook-secret --from-literal $WEBHOOK_SECRET
# Download the private key to your host
$ faas-cli secret create private-key-secret --from-file <path_to_your_pem_file>.pem
```

We should create a secret in faasd, in order to do that we need to access the Gateway of faasd.
```bash
$ export IP=$(multipass info faasd --format json| jq '.info.faasd.ipv4[0]' | tr -d '\"')
# Let's capture the authentication password into a file for use with faas-cli
$ ssh ubuntu@$IP "sudo cat /var/lib/faasd/secrets/basic-auth-password" > basic-auth-password
# Login from your laptop (the host)
$ export OPENFAAS_URL=http://$IP:8080 && \
cat basic-auth-password | faas-cli login -s
```

Also, it is worth to mention that you can run multipass info faasd at any time to get details of the faasd instance.
```bash
$ multipass info faasd
Name:           faasd
State:          Running
IPv4:           192.168.64.25
Release:        Ubuntu 20.04.1 LTS
Image hash:     d68d50a4067d (Ubuntu 20.04 LTS)
Load:           0.68 1.09 0.54
Disk usage:     1.9G out of 4.7G
Memory usage:   259.8M out of 981.4M
```

## Connect your Exit Node
We need to establish connection between our client, and the inlets-pro server in order to get events from there.

```bash
$ export UPSTREAM=$IP # faasd gateway ip, we have already grap the URL above
$ export PORTS=8080 # faasd gateway port
$ export LICENSE="eyJhbGciOiJFUzI..."

# Notice that this command is the output of the "inletsctl create" command above
$ inlets-pro client --url "wss://XX.XXX.XXX.XX:8123/connect" \
        --token "$TOKEN" \
        --license "$LICENSE" \
        --upstream $UPSTREAM \
        --ports $PORTS
```

## Test
In order to test it we need to install this app to selected repositories. Create a repository called "test-issues-bot", then install this app for it.
![repository-access](/images/2021-01-15-github-application-using-go-and-inlets-pro/repository-access.png)

Then, create an issue for the repository. You will see the message.
> "Hello, issue opened by: developer-guy"

![test-issue-bot](/images/2021-01-15-github-application-using-go-and-inlets-pro/test-issue-bot.png)

Finally , let's close the issue by typing command */close*.
![close-issue](/images/2021-01-15-github-application-using-go-and-inlets-pro/close-issue.png)

## Cleanup

```bash
$ multipass delete --purge faasd
$ inletsctl delete --provider digitalocean --id "YOUR_INSTANCE_ID"
```

# Acknowledgements

* Special Thanks to [Alex Ellis](https://twitter.com/alexellisuk) for all guidance and for merging changes into OpenFaaS to better support this workflow.
* Special Thanks to [Furkan Türkal](https://twitter.com/furkanturkaI) for all the support.
* Special Thanks to [Kumar Utsav Anand](https://twitter.com/Utsav2Anand) for all the support.

# References
* [https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/](https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/)
* [https://www.x-cellent.com/blog/automating-github-with-golang-building-your-own-github-bot/](https://www.x-cellent.com/blog/automating-github-with-golang-building-your-own-github-bot/)
* [https://blog.alexellis.io/share-work-using-inlets/](https://blog.alexellis.io/share-work-using-inlets/)
