---
title: "Create your own private cloud with OpenFaaS Cloud"
description: Create your own private cloud with OpenFaaS Cloud for your team to deploy functions and microservices with automatic CI/CD and GitHub integration.
date: 2020-02-27
image: /images/2020-02-27-ofc-private-cloud/private-cloud-servers.jpg
categories:
  - microservices
  - kubernetes
  - serverless
  - cloud
  - governance
  - functions
  - gitops
author_staff_member: alex
dark_background: true

---

In this post I want to show you how to create your own private cloud with [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) and Kubernetes.

After the setup is complete, you can invite your team who will use their GitHub or GitLab accounts to log into a personal dashboard. CI/CD is built-in along with TLS, logging, encrypted secrets, DNS, and governance. Through a wildcard TLS certificate and DNS entry, each user and organization will receive their own sub-domain.

As the administrator, you'll be defining a policy for which features are available, configuring auditing via Slack (or a webhook) and defining governance such as memory and CPU limits.

With your private cloud you'll be able to deploy microservices, APIs, blogs, wikis, functions and more, whatever conforms to the [OpenFaaS workload definition](https://docs.openfaas.com/reference/workloads/).

## Pre-requisites

* A private or public Kubernetes cluster with Intel architecture (ARM is not supported at this time) with at least 3x nodes with 4GB RAM and 2vCPU each

> Note: if you are planning on using k3s, then you should see the [notes in the user-guide about disabling Traefik](https://github.com/openfaas/ofc-bootstrap/blob/master/USER_GUIDE.md)

* An account with DigitalOcean, AWS, GCP or Cloudflare for automatic DNS configuration and TLS

* A top-level domain that you own (`example.com`), or a sub-zone (`ofc.example.com`)

* A [GitHub.com](https://github.com/) account

Installed below:

* Local tooling: kubectl, faas-cli, [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap) etc

## An overview

The tool that we use to configure OpenFaaS Cloud (OFC) is [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap).

![ofc-bootstrap tooling](https://github.com/openfaas/ofc-bootstrap/raw/master/docs/ofc-bootstrap.png)

> Note: that helm3 is now used, without Tiller.

The core components installed are:

* [OpenFaaS](https://github.com/openfaas/faas) - to host your functions and endpoints
* [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) - CI/CD pipeline
* OpenFaaS Cloud - multi-user dashboard
* OpenFaaS Cloud - edge-auth and edge-router for OAuth2 support and multi-user routing
* [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets) - to encrypt secrets for your repos
* [buildkit](https://github.com/moby/buildkit) - to build Docker images for your repos
* [Minio](https://min.io) - for build log storage
* [Nginx-Ingress](https://kubernetes.github.io/ingress-nginx/) - to act as the IngressController for Kubernetes
* [cert-manager](https://cert-manager.io) - to issue TLS certificates

The installation takes between 50-100s, but most of the time is going to be spent in configuring the GitHub integration, security, TLS and DNS.

## Download the tooling

Run these instructions on your laptop or local machine.

Clone ofc-bootstrap and then install its CLI:

```bash
mkdir -p ~/dev/
cd ~/dev/
git clone https://github.com/openfaas/ofc-bootstrap
cd ofc-bootstrap

curl -sLSf https://raw.githubusercontent.com/openfaas/ofc-bootstrap/master/get.sh | sudo sh
```

These instructions are also available in the [user guide](https://github.com/openfaas/ofc-bootstrap/blob/master/USER_GUIDE.md).

* [Download kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

* Download the [OpenFaaS CLI](https://github.com/openfaas/faas-cli)

```bash
curl -sSL https://cli.openfaas.com | sudo sh
```

* Download [Helm 3](https://helm.sh)

```bash
https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | sudo bash
```

## Create an overrides file

We can configure the `ofc-bootstrap` tool through a YAML file, this can be committed to git for later use, it covers everything from:

* Your secrets for things like: GitHub/GitLab and your Docker image registry
* The OAuth secret ID and client ID
* Your domain name for the private cloud
* Your preferences for OpenFaaS Cloud governance - read-only functions, memory limits, Dockerfile support and custom templates

Some secrets are read from files, some are generated from scratch and others are taken from a literal value.

Fortunately, you do not need to edit the whole file, you can create a set of override files with just the changes you need.

* Decide your domain, I'm picking `ofc.example.com`, so create a new file and add:

Contents of: `ofc.example.com.yaml`

```yaml
root_domain: ofc.example.com
```

We still have work to do, but this now would allow us to run `ofc-bootstrap apply -f example.init.yaml -f ofc.example.com.yaml`, which takes both the defaults for the current version of OFC and our domain override. We can also override each secret in the same way.

## Configure your Docker registry

All images built by OFC will be stored in a Docker registry before being deployed, you can use the Docker Hub which is the default, or use a private registry.

Let's log into our Docker registry and create a credentials file:

```bash
export USERNAME="docker-username"
ofc-bootstrap registry-login --username $USERNAME --password-stdin
```

By default this will use your [Docker Hub account](https://hub.docker.com), but you can also [Set up your own private TLS registry using arkade](https://blog.alexellis.io/get-a-tls-enabled-docker-registry-in-5-minutes/), use an existing registry with `--server`, or use AWS ECR (see the notes in the repo for this).

After running this command we'll have a file in `credentials/.config.json`, which you can see that the example.init.yaml file will look for on disk, and use to create a Kubernetes secret later.

Add a line for your registry into the overrides file:

```yaml
registry: docker.io/alexellis/
```

## Create your GitHub App

Now let's generate a GitHub App, which is how users will enroll a repo into our private cloud.

```bash

# We need to run this from the git repo, to access some templates
cd ~/dev/ofc-bootstrap

export DOMAIN="ofc.example.com"
export GH_APP_NAME="Our Team OFC"
ofc-bootstrap create-github-app \
  --name "$GH_APP_NAME" \
  --root-domain $DOMAIN
```

> Note: If you don't want to use TLS, you can specify `--insecure` to use HTTP URLs

After running this command you will be redirected to GitHub, where a GitHub app will be created for you, and then YAML will be printed out which you can save into your overrides file `ofc.example.com.yaml`.

```yaml
secrets:
- name: github-webhook-secret
  literals:
  - name: github-webhook-secret
    value: cb539f01e7f06e0dbc60bc1c532ac4b3cb77d6e2
  namespace: openfaas-fn
  filters:
  - scm_github
- name: private-key
  literals:
  - name: private-key
    value: |
      -----BEGIN RSA PRIVATE KEY-----
      -----END RSA PRIVATE KEY-----
  namespace: openfaas-fn
  filters:
  - scm_github
root_domain: ofc.example.com
github:
  app_id: "55667"
```

The private-key is used to authenticate on behalf of each user and repository to update GitHub status checks and build logs. It also allows the use of private repositories where the token is used to clone the repository.

You should also note down your GitHub App URL, this is how each member of your team will enroll repos for CI/CD.

```
GitHub App result received.
App: Our Team OFC       URL: https://github.com/apps/our-team-ofc
```

Visit your App's configuration page at https://github.com/settings/apps

Now click the "Active" button, sub-heading "We will deliver event details when this hook is triggered."

## Create the OAuth integration

To make sure that only authorized users can access dashboards and the cloud, we can integrate with GitHub via OAuth.

* [Create an OAuth app](https://docs.openfaas.com/openfaas-cloud/self-hosted/github/#create-a-github-oauth-integration-optional)

Our example Authorization URL is `https://auth.system.example.com/`

Now update your overrides file:

Add this secret, replacing the contents of `value: etc` with the *client secret*

```yaml
- name: "of-client-secret"
  literals:
    - name: of-client-secret
      value: "4c8246da512c296861b7cd499a32f8194ca8945c"
  filters:
    - "auth"
  namespace: "openfaas"
```

Add your Client ID on a new line along with `enable_oauth`:

```yaml
oauth:
  client_id: 8219a0399a231b94175f
enable_oauth: true
```

## Configure a list of users

Now configure a list of users who you want to have access to log in, the easiest way to do this is through a Kubernetes secret, create a file named `credentials/CUSTOMERS` and then add the two secrets to the YAML overrides file:

```
echo alexellis > credentials/CUSTOMERS
echo openfaas >> credentials/CUSTOMERS
```

Now edit the overrides file:

```yaml
- name: "of-customers"
  files:
    - name: "of-customers"
      value_from: "credentials/CUSTOMERS"
  namespace: "openfaas"
  filters:
    - "default"
- name: "customers"
  files:
    - name: "customers"
      value_from: "credentials/CUSTOMERS"
  namespace: "openfaas-fn"
  filters:
    - "default"
```

By default OFC will read the list of customers from a HTTPS URL, but since we have overridden this, let's configure the bootstrap tool to use the Kubernetes secret.

Add the following to your overrides file:

```yaml
customers_secret: true
```

## Auditing via Slack

You can set up auditing and monitoring via a Slack webhook. Simply create a public or private channel in your Slack workspace, then create an incoming URL.

Set the Slack URL in your overrides file:

```yaml
slack:
  url: http://slack.com/secret-url-goes-here
```

## Governance

You can add additional overrides for the various features made available in example.init.yaml, including memory and CPU limits.

See the [ofc-boostrap user-guide](https://github.com/openfaas/ofc-bootstrap/blob/master/USER_GUIDE.md) or the `example.init.yaml` file for more.

## Configure TLS and DNS

ofc-bootstrap can configure TLS and DNS automatically so that every user and org in your cluster gets their own sub-domain.

For instance, if I deployed a webhook receiver called `stripe-payment` to a GitHub account linked under my user account (`alexellis`), my URL would be:

https://alexellis.ofc.example.com/stripe-payment

So called, *pretty URLs* are also available through the [ingress-operator project](https://github.com/openfaas-incubator/ingress-operator), so that if we wanted we could add a custom domain like: `stripe.example.com`

Decide whether you are going to use AWS Route53, GCP Cloud DNS, DigitalOcean, or Cloudflare for DNS, then configure your user account [as per the cert-manager docs](https://cert-manager.io/docs/configuration/acme/dns01/). We will be using the DNS01 ACME challenge, so that we can obtain a wildcard certificate for all our team's functions.

I'm going to use DigitalOcean for TLS for my domain `ofc.example.com`, it's simply enough to use an API token from the dashboard, AWS and GCP configuration is slightly more involved.

Now update the overrides file:

```yaml
tls: true
tls_config:
  dns_service: digitalocean
  issuer_type: "staging"
  email: "your@email.com"
```

Set your `email`, and an `issuer_type` of `staging` for the initial installation. This can be changed to `prod` after you are sure everything is configured correctly.

If you look at the `example.init.yaml` file you'll see a section with secrets for DNS, you can either create your DigitalOcean API token in that location, or customise it by adding a new secret to your overrides file.

Default location:

```yaml
- name: "digitalocean-dns"
  files:
    - name: "access-token"
      value_from: "~/Downloads/do-access-token"
  filters:
    - "do_dns01"
  namespace: "cert-manager"
```

You may want to customise it as follows:

```yaml
- name: "digitalocean-dns"
  files:
    - name: "access-token"
      value_from: "credentials/do-access-token"
  filters:
    - "do_dns01"
  namespace: "cert-manager"
```

## Deploy your OpenFaaS Cloud

Take a few moments to review your overrides file and the tutorial post so far, if you think you have everything configured correctly, and have checked it against GitHub, then go ahead and run `ofc-bootstrap`

```bash
cd ~/dev/ofc-bootstrap

ofc-bootstrap apply \
 -f example.init.yaml \
 -f ofc.example.com.yaml
```

You can now monitor the progress as a series of helm charts are installed, secrets are created and templated Kubernetes YAML files are applied.

Here's the full example of my overrides file:

```yaml
secrets:
- name: github-webhook-secret
  literals:
  - name: github-webhook-secret
    value: cb539f01e7f06e0dbc60bc1c532ac4b3cb77d6e2
  namespace: openfaas-fn
  filters:
  - scm_github
- name: private-key
  literals:
  - name: private-key
    value: |
      -----BEGIN RSA PRIVATE KEY-----
      -----END RSA PRIVATE KEY-----
  namespace: openfaas-fn
  filters:
  - scm_github
- name: "of-client-secret"
  literals:
    - name: of-client-secret
      value: "4c8246da512c296861b7cd499a32f8194ca8945c"
  filters:
    - "auth"
  namespace: "openfaas"
- name: "of-customers"
  files:
    - name: "of-customers"
      value_from: "credentials/CUSTOMERS"
  namespace: "openfaas"
  filters:
    - "default"
- name: "customers"
  files:
    - name: "customers"
      value_from: "credentials/CUSTOMERS"
  namespace: "openfaas-fn"
  filters:
    - "default"
- name: "digitalocean-dns"
  files:
    - name: "access-token"
      value_from: "credentials/do-access-token"
  filters:
    - "do_dns01"
  namespace: "cert-manager"

root_domain: ofc.example.com
github:
  app_id: "55667"

oauth:
  client_id: 8219a0399a231b94175f

enable_oauth: true

slack:
  url: http://slack.com/secret-url-goes-here

tls: true
tls_config:
  dns_service: digitalocean
  issuer_type: "staging"
  email: "your@email.com"
```

## Post-install

Our first task is to find the IP address of the LoadBalancer created for the IngressController. This is the Public IP that will be used for all incoming traffic.

> Note: if you are running in a private VPC, or a local on-premises cluster, or a laptop, then you can obtain a public Virtual IP through [inlets-pro](https://docs.inlets.dev/#/get-started/quickstart-ingresscontroller-cert-manager?id=expose-your-ingresscontroller-and-get-tls-from-letsencrypt).

Create three DNS entries, if you are using AWS you will create CNAME records instead of A records.

* `*.ofc.example.com` - to serve each user / org function
* `system.ofc.example.com` - the dashboard
* `auth.system.ofc.example.com` - used for OAuth

## Deploy your first application or function

Now head over to the [OFC User Guide](https://docs.openfaas.com/openfaas-cloud/user-guide/) which will show you how to deploy a function using Node.js.

An example of CI/CD:

![CI/CD](https://docs.openfaas.com/images/openfaas-cloud/welcome-05.png)

The user-level dashboard:

![Overview](https://docs.openfaas.com/images/openfaas-cloud/welcome-09.png)

Details for an endpoint:

![Details](https://docs.openfaas.com/images/openfaas-cloud/welcome-10.png)

Runtime logs are also available:

![Logs](https://docs.openfaas.com/images/openfaas-cloud/welcome-13.png)

Alternative, you can [browse the blog](https://www.openfaas.com/blog/) or [the docs](https://docs.openfaas.com/).

## Troubleshooting and support

You can pay an engineer from OpenFaaS Ltd to setup OpenFaaS Cloud on your preferred cloud, reach out [sales@openfaas.com](mailto:sales@openfaas.com) to arrange a call. Likewise, if you have features in mind, you [can check the roadmap](https://trello.com/b/5OpMyrBP/2020-openfaas-roadmap), or reach out about support.

See [the troubleshooting guide in our docs](https://docs.openfaas.com/openfaas-cloud/self-hosted/troubleshoot/)

Ask for assistance in #openfaas-cloud [on Slack](https://slack.openfaas.io/)

## Wrapping up

We have now deployed a private cloud using OpenFaaS cloud, we can invite our team and users, who will each have their own dashboard to monitor and manage functions or microservices. 

Everything we have deployed is stateless, and is running on Open Source software from the CNCF landscape, this means that disaster recover is easy, just run `ofc-bootstrap` against a cluster, and `git push`.

### Get OFC even quicker than that

Do you want to try OpenFaaS Cloud before installing it yourself?

Apply for free access to the [OpenFaaS Cloud Community Cluster](https://github.com/openfaas/community-cluster/)

Or install OFC for local development by skipping TLS and OAuth, this reduces the time to around 15 minutes:

[OpenFaaS Cloud for Development](https://blog.alexellis.io/openfaas-cloud-for-development/)

Are you an EKS user? We have a specific guide for you that covers IAM, Route53, and role management: [Build your own OpenFaaS Cloud with AWS EKS](https://www.openfaas.com/blog/eks-openfaas-cloud-build-guide/)

### Source code / GitHub

You can fork/star/browse the code on GitHub:

* [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap)
* [openfaas-cloud](https://github.com/openfaas/openfaas-cloud)

We also have a video recording from KubeCon covering some customer case-studies and community projects that are running on OpenFaaS Cloud: [OpenFaaS Cloud + Linkerd: A Secure, Multi-Tenant Serverless Platform - Charles Pretzer & Alex Ellis](https://www.youtube.com/watch?v=sD7hCwq3Gw0)
