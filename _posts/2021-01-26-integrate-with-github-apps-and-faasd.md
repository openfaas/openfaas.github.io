---
title: "How to integrate with GitHub the right way with GitHub Apps"
description: "In this guide, we are going to demonstrate how to build your own GitHub App to get a fine-grained integration with GitHub's API and to act on the behalf of its users."
tags: inlets-pro inletsctl go github-application faasd raspberry-pi
author_staff_member: batuhan
dark_background: true
image: /images/2021-01-15-github-application-using-go-and-inlets-pro/githubpic.jpg
date: 2021-01-26

---

In this guide, we are going to demonstrate how to build your own GitHub App to get a fine-grained integration with GitHub's API and to act on the behalf of its users

# Introduction

With [56 million developers on the platform and 85 million repositories](https://www.theverge.com/2018/6/18/17474284/microsoft-github-acquisition-developer-reaction), integrating with GitHub is not just fun, it's essential. Some companies have even built integrations so good, [that GitHub bought them](https://techcrunch.com/2019/09/18/github-acquires-code-analysis-tool-semmle/) and made them part of the core platform. This has happened multiple times.

> Even faster than that. When we reached out to GitHub for comment, [Martin Woodward, Director of DevRel](https://twitter.com/martinwoodward) told us that [this year they saw 60 million new repositories created](https://octoverse.github.com/).

So why is it that so many of you are doing it wrong? Many of you are still using OAuth apps which are considered legacy and have scopes which are far too broad. Many more of you are taking extreme risks by using Personal Access Tokens (PATs), most of which can do anything to your account and repositories.

> GitHub Apps are first-class actors within GitHub and unlike the legacy OAuth apps, allow or fine-grained actions to be performed on your user's repositories.

In this guide, we are going to develop a [GitHub App](https://docs.github.com/en/free-pro-team@latest/developers/apps) using Go, then we deploy it as a serverless function to make use of [faasd](https://github.com/openfaas/faasd) which is a lightweight & portable faas engine. We are also going to do this demo on our local environment, so we should open our function which runs on our local environment to the Internet so Github can send events to our function. In order to do that we use inlets-pro which provides secure TCP/L4 tunnels.

> If you are a Kubernetes or K3s user and want to follow along, you can do so and switch out faasd and inletsctl, for the [inlets-operator for Kubernetes](https://github.com/inlets/inlets-operator) and your local cluster. Everything else will work the same.

![overview](/images/2021-01-15-github-application-using-go-and-inlets-pro/faasd-issue-bot.png)

A GitHub App acts on its own behalf, taking actions via the API directly using its own identity, which means you don't need to maintain a bot or service account as a separate user. GitHub Apps can be installed directly on organizations and user accounts and granted access to specific repositories. They come with built-in webhooks and narrow, specific permissions. When you set up your GitHub App, you can select the repositories you want it to access. For example, in this guide we are going to develop a Github App that respond or close the comments for your repositories that you installed Github App for.

Two examples that make thorough use of GitHub Apps are below:

* [Derek](https://github.com/alexellis/derek)
* [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud)

Derek is a GitHub bot that reduces fatigue for maintainers by automating governance and delegating permissions to your team and community. It provides the following automation:

- Generate changelogs for releases with PRs merged and commits added, crediting everyone invokved
- Let designated non-admin users manage Issues and PRs by commenting `Derek <command>` or `/command`
- Enforce [Developer Certificate of Origin (DCO)](https://developercertificate.org/) checking (optional)
- Automatically label/flag PRs without a Description

OpenFaaS Cloud is designed as Multi-user version of OpenFaaS with CI/CD built in and a new dashboard. It is aimed at platform engineers who want to give functions to their team, whilst shielding them from Kubernetes at the same time.

With OpenFaaS Cloud functions are managed through typing `git push` which reduces the tooling and learning curve required to operate functions for your team. As soon as OpenFaaS Cloud receives a push event from git it will run through a build-workflow which clones your repo, builds a Docker image, pushes it to a registry and then deploys your functions to your cluster. Each user can access and monitor their functions through their personal dashboard.

## Pre-requisites

* DigitalOcean Account - We are going to use DigitalOcean as a provider to host our exit-node.
* [arkade](https://get-arkade.dev) - arkade provides a portable marketplace for downloading your favourite devops CLIs and installing helm charts, with a single command.
* inletsctl - inletsctl automates the task of creating an exit-node on cloud infrastructure. 
* inlets-pro - You can use inlets-pro to tunnel out any TCP traffic from an internal network to another network. 
* multipass - Multipass provides a command line interface to launch, manage and generally fiddle about with instances of Linux.
* faas-cli - This is a CLI for use with OpenFaaS - a serverless functions framework for Docker & Kubernetes.

Now we are ready to go 🚀

## Setup your exit-node server on DigitalOcean

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

You can also change the region flag to a DigitalOcean region close to your network

> See [the docs for inletsctl](https://docs.inlets.dev/#/tools/inletsctl?id=inletsctl-reference-documentation) for examples of how to use other providers like AWS EC2, Azure and GCP.

If everything goes well, you should see your newly created "exit-node" on the homepage of your the DigitalOcean account like the following:

![inlets-droplet](/images/2021-01-15-github-application-using-go-and-inlets-pro/inlets-droplet.png)

> If you curious about what the "exit-node or exit-server" is, you can follow a link in the inlets documentation [here](https://docs.inlets.dev/#/?id=exit-servers).

## Create the new GitHub App on GitHub

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
  
## Get up and running with your own faasd installation on your computer with multipass

[Multipass](https://multipass.run) is a tool that not enough developers are using. It's 2020's answer to VirtualBox and Docker Desktop in one. You just run a few commands and get a Linux host with Ubuntu pre-installed. The best part is that it supports cloud-init scripts too.

In order to get up and running with your own faasd installation on your Mac you can use multipass. For more details you can follow the [link](https://github.com/openfaas/faasd/blob/master/docs/MULTIPASS.md).

Let's start our Ubuntu VM with multipass. First, we need a cloud-config.txt to set up faasd while bootstrapping VM.

```bash
$ curl -sSLO \
  https://raw.githubusercontent.com/openfaas/faasd/master/cloud-config.txt
```

Then, we need to update the SSH key to match your own, edit cloud-config.txt:

```bash
$ ssh-keygen -t rsa -b 4096 -C "developerguyn@gmail.com" -f $PWD/id_rsa
```

Replace the _ssh_authorized_keys::ssh-rsa_ value with the contents of `~/.ssh/id_rsa.pub`, which is defined in `cloud-config.txt`.

Finally, boot the VM

```bash
$ multipass launch \
  --cloud-init cloud-config.txt \
  --name faasd
```

> Note: `multipass launch` can be configured with more CPUs, RAM and additional disk capacity, just run `--help` to see how.

Check the VM if it is working properly:

```bash
$ multipass list
Name                    State             IPv4             Image
faasd                   Running           192.168.64.25    Ubuntu 20.04 LTS
```

You can connect to the VM through SSH or via `multipass exec faasd`.

To get the IP address simply run `multipass info faasd`:

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

## Build and deploy a webhook receiver function

For this demo, we are going to use Golang to develop a function that responds to any webhooks sent to us from the GitHub App.

In order to do that, first, we need to pull the corresponding function template for the Golang.

We need to install "faas-cli" tool for that but we need to install arkade first because arkade is the marketplace for our favourite devops CLIs.

```bash
$ curl -sLS https://dl.get-arkade.dev | sudo sh
```

Then, let's install our faas-cli tool.

```bash
$ arkade get faas-cli
```

We can now find the Golang template we want and continue to create our function.

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

You can find all the code details in my GitHub repository: [developer-guy/faasd-github-bot](https://github.com/developer-guy/faasd-github-bot).

After you've created the function, you need to define a build-arg to use Go modules, an environment variable for the GitHub App ID (found in the GitHub UI) and a secret for the the webhook secret (for verifying genuine payloads) and the private key (for acting on the behalf of a user).

Let's add them to the YAML file created by `faas-cli new`:

```yaml
  build_args:
      GO111MODULE: on
    secrets:
      - webhook-secret # your secret goes here
      - private-key-secret # your private key goes here
    environment:
      APP_ID: "" # your app id goes here
```

Next we need to create the above two secrets.

Download the private key for the GitHub app to your host using the GitHub UI.

```bash
$ export WEBHOOK_SECRET="sup3rs3cr3t"
$ faas-cli secret create webhook-secret --from-literal $WEBHOOK_SECRET
$ faas-cli secret create private-key-secret --from-file <path_to_your_pem_file>.pem
```

Now it's time to authenticate `faas-cli` so that we can do a deployment to our faasd instance from our laptop. This would work the same if you were deploying faasd to a cloud instance.

```bash
# Get the IP into a variable
$ export IP=$(multipass info faasd --format json| jq '.info.faasd.ipv4[0]' | tr -d '\"')

# Let's capture the authentication password into a file for use with faas-cli
$ ssh ubuntu@$IP "sudo cat /var/lib/faasd/secrets/basic-auth-password" > basic-auth-password

# Login from your laptop (the host)
$ export OPENFAAS_URL=http://$IP:8080

cat basic-auth-password | faas-cli login -s
```

You can add the `OPENFAAS_URL` entry to your shell's profile if you like, so you get the variable set every time you open a new terminal.

## Connect your Exit Node from the faasd instance

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

## Let's test your GitHub App

In order to test it we need to install this app to selected repositories. Create a repository called "test-issues-bot", then install this app for it.
![repository-access](/images/2021-01-15-github-application-using-go-and-inlets-pro/repository-access.png)

If you create an issue on the `test-issues-bot` repository, then you will see a message like this:

> "Hello, issue opened by: developer-guy"

![test-issue-bot](/images/2021-01-15-github-application-using-go-and-inlets-pro/test-issue-bot.png)

Finally, let's close the issue by typing in a command, just like how Derek works:

```
/close
```

![close-issue](/images/2021-01-15-github-application-using-go-and-inlets-pro/close-issue.png)

### Tear down up the resources (optional)

```bash
$ multipass delete --purge faasd
$ inletsctl delete --provider digitalocean --id "YOUR_INSTANCE_ID"
```

## So what next?

Now that you can develop first-class integrations with GitHub, with fine-grained permissions and do things the right way. OAuth works are very broadly defined and personal access tokens (PATs) are just the wrong tool for the job and very risky if someone were to find it.

Each user that installs your app is called an installation and has their own API limit of 1000 calls per hour.

So what will you build?

You could develop a bot, an integration, a linter as a service, integrate a machine-learning model from the OpenFaaS function store, and a whole host of other things. It's up to you to decide.

Do you already have a preferred way to deploy and run HTTP servers which isn't faasd? We're OK with that and want you to know that what you learned here about inlets and GitHub Apps can apply whether you run with a Docker container or just deploy a binary directly to a server. 

# References

Other GitHub Apps:

* [Derek](https://github.com/alexellis/derek)
* [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud)

Blog posts I found useful:

* [https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/](https://blog.alexellis.io/deploy-serverless-faasd-with-cloud-init/)
* [https://blog.alexellis.io/share-work-using-inlets/](https://blog.alexellis.io/share-work-using-inlets/)
* [https://www.x-cellent.com/blog/automating-github-with-golang-building-your-own-github-bot/](https://www.x-cellent.com/blog/automating-github-with-golang-building-your-own-github-bot/)
