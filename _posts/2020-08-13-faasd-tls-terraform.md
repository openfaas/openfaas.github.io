---
title: "Bring a lightweight Serverless experience to DigitalOcean with Terraform and faasd"
description: "In this post, you'll provision a DigitalOcean Droplet using Terraform, once it's up and running, a TLS certificate will be installed and you can start deploying code with faasd"
date: 2020-08-13
image: /images/2020-08-13-faasd-tls-terraform/vintage-palm.jpg
categories:
  - microservices
  - serverless
  - faasd
  - containerd
author_staff_member: alex
dark_background: true

---

In this post, you'll provision a DigitalOcean Droplet using Terraform, once it's up and running, a TLS certificate will be installed and you can start deploying code with faasd.

## Before we start

Before we start the tutorial, let's start with a bit more background. faasd is a slimmed-down distribution of OpenFaaS that can run on a single virtual-machine, is easy to automate, and has almost no need for maintenance. It's not that OpenFaaS needed a diet, it was just that to even run a single function, you required a whole Kubernetes cluster, and some people were understandably put off by that idea.

> [Read my introduction to faasd](https://www.openfaas.com/blog/introducing-faasd/)

If all you need is a few functions, webhook-receivers, or web pages, then why run a 3-5 node Kubernetes cluster, when you can run a single 5-10 USD VPS instead?

This tutorial will use a combination of Terraform and cloud-init to setup a new host on [DigitalOcean](https://m.do.co/c/8d4e75e9886f), however it is not limited to any one provider. If your favourite cloud provider supports cloud-init and has a Terraform module, then with a few tweaks, you can deploy faasd there too. You can even deploy faasd manually, if you so wish.

A TLS certificate will be provided by [LetsEncrypt](https://letsencrypt.org), using [Caddy](https://caddyserver.com).

### Overview

Before you start, you'll need to run through the pre-requisites:

* To [create an account on DigitalOcean](https://m.do.co/c/8d4e75e9886f) for this tutorial
* To generate an API key/token and save it somewhere on your computer using the DigitalOcean dashboard
* To register a domain - [namecheap](https://www.namecheap.com) and [Google Domains](https://domains.google.com/) are both cheap and easy to use
* Install [Docker](https://www.docker.com/) to build and push local images
* Install [faas-cli](https://docs.openfaas.com/tutorials/cli-with-node/#get-the-cli)
* Install [Terraform](https://www.terraform.io)

Then here's the outline of what we'll do next:

* Initialise Terraform and have it download any modules required
* Edit a `.tfvars` file
* Run terraform plan and apply
* Wait a few moments for our Droplet to start
* Create a DNS A record for the IP of the Droplet
* Wait a few moments for [Caddy](https://caddyserver.com) to set up the TLS certificate
* Log into our new faasd host with TLS enabled

## Tutorial

### Initialise Terraform

Download the GitHub repo:

```bash
git clone https://github.com/openfaas/faasd
cd faasd/docs/bootstrap/digitalocean-terraform
```

> Make sure that you're using [Terraform 0.12.0](https://www.terraform.io/downloads.html), and not 0.13.0 or newer. If you ignore this instruction, don't complain if it doesn't work for you :-)

Now run:

```
terraform init
```

Open `main.tfvars`, and remove the line `do_token`.

Now set the following:

```hcl
do_domain         = "example.com"
letsencrypt_email = "webmaster@example.com"
```

The `do_domain` field will be prepended with "faasd", so if you enter `example.com`, the actual host will be `faasd.example.com` and so on.

Now prepare an environment variable for your DigitalOcean access token:

```
export TF_VAR_do_token="$(cat ~/Downloads/do-access-token)"
```

Plan with Terraform, and then apply it:

```
terraform plan -var-file=main.tfvars
terraform apply -var-file=main.tfvars
```

### Check the output

The output should be as follows, and if you need it again run `terraform output`.

```
droplet_ip = 165.232.76.94
gateway_url = https://faasd.example.com/
login_cmd = faas-cli login -g https://faasd.example.com/ -p 6b1be68a8feba552c11beb2eeb7fcc7edee4627f
password = 6b1be68a8feba552c11beb2eeb7fcc7edee4627f
```

OpenFaaS will be starting up, but it won't be served on a public adapter, it will only be available via Caddy on port 80 and 443.

There is a bit more work required before Caddy can get a TLS certificate for us though.

### Create a DNS A record

Create a DNS A record in your admin panel, or with the DigitalOcean CLI:

```bash
doctl compute domain create \
  faasd.example.com \
  --ip-address 165.232.76.94
```

At this point, in the background Caddy will be trying to create a TLS certificate for us. Finally, the DNS name `faasd.example.com` will resolve correctly, and Caddy will be able to go through a proper exchange with LetsEncrypt and obtain a certificate.

### Check that it worked

The next step is to check that everything worked, you can verify this with the `faas-cli login` command, using the output from `terraform output`

```bash
# Prefix with two spaces, to prevent tracking in your bash
# history, or save to a file and use cat.
  echo 6b1be68a8feba552c11beb2eeb7fcc7edee4627f | faas-cli \
    login -g https://faasd.example.com/ --password-stdin

Calling the OpenFaaS server to validate the credentials...
credentials saved for admin https://faasd.example.com
```

Next, try out the UI using the HTTPS URL from above along with the password you used to log in.

![The dashboard](/images/2020-08-13-faasd-tls-terraform/ui-1.png)

Deploy a function from the store:

![The dashboard](/images/2020-08-13-faasd-tls-terraform/ui-2.png)

And invoke it, in this instance, you can see that we're running on a 1GB droplet:

![The dashboard](/images/2020-08-13-faasd-tls-terraform/ui-3.png)

You can now access faasd just like any other OpenFaaS gateway.

### Deploy a function

Now that you have faasd deployed, you can deploy a function in Node.js for instance.

```bash
# Customise as per your Docker Hub account or external registry
export OPENFAAS_PREFIX="alexellis2"

faas-cli new --lang node12 private-api
```

This generates three files:

```
private-api.yml
private-api/handler.js
private-api/requirements.json
```

Here's our handler.js:

```js
'use strict'

module.exports = async (event, context) => {
  return context
    .status(200)
    .succeed(
        {'status': 'Received input: ' + JSON.stringify(event.body)}
    )
}
```

To install dependencies, just cd into the `private-api` folder and run `npm install --save`.

Let's create a secret API token for the function.

```bash
# Generate a secret token in token.txt
echo $(head -c 16 /dev/urandom |shasum |cut -d "-" -f1) > token.txt
```

Now point your CLI to your gateway and create the secret:

```bash
export OPENFAAS_URL=https://faasd.example.com/

faas-cli secret create private-api-token --from-file token.txt

Creating secret: private-api-token
Created: 200 OK
```

Let's update the code so that it does a simple switch depending on whether the user passes in a matching header in the HTTP request for the token value.

> Note: in OpenFaaS, secrets are read from `/var/openfaas/secrets/`.

Edit `handler.js`:

```js
'use strict'

const fs = require('fs');
const fsPromises = fs.promises;

module.exports = async (event, context) => {
  let secret = await fsPromises.readFile("/var/openfaas/secrets/private-api-token", "utf8")

  // Headers are made lowercase due to the use of Caddy
  let auth = event.headers["authorization"]
  if(auth && auth == "Bearer: " + secret) {
    return context
            .status(200)
            .succeed("authorized")
  }
  return context
    .status(401)
    .succeed("unauthorized")
}
```

To request the new secret from your OpenFaaS function, edit the `private-api.yml` file and add the secret below:

```yaml
...
functions:
  private-api:
    ...
    secrets:
    - private-api-token
```

Now run:

```bash
# Log into your Docker registry
docker login

# Followed by 
faas-cli up
```

The `faas-cli up` command builds a local container image, pushes it to your registry, and then requests faasd to deploy it as an endpoint.

Try the API out:

See the 401:

```bash
curl -i https://faasd.example.com/function/private-api

unauthorized
```

Try to add your key:

```bash
curl -i -H "Authorization: Bearer: $(cat token.txt)" \
  https://faasd.example.com/function/private-api

authorized
```

Try changing the successful login message, and then run `faas-cli up` again.

Force a change of the version of the code by editing private-api.yml and editing the `image: ` field.

```yaml
    image: alexellis2/private-api:latest
# To
    image: alexellis2/private-api:0.1.0
```
#### Testing and debugging

The easiest way to test and debug code is to write tests. If you want to add unit tests, they are run at the build-time on your local computer, or in your CI pipeline. Here's a simple example using Mocha.js: [openfaas-node12-mocha-unit-test](https://github.com/alexellis/openfaas-node12-mocha-unit-test).

You can also add `console.log` to your code, and then view the results via `faas-cli logs private-api`.

When you run `faas-cli build`, a local Docker image is stored on your computer, you can also run that with Docker and access it.

```bash
# Build the latest code
faas-cli build -f private-api.yml 

Successfully built 49b896c2f235
Successfully tagged alexellis2/private-api:0.2.1
Image: alexellis2/private-api:0.2.1 built.
[0] < Building private-api done in 0.36s.
[0] Worker done.

Total build time: 0.36s

# Make a temporary secret to mount into the container
mkdir -p /tmp/secrets
cp token.txt /tmp/secrets/private-api-token

# Run the container
docker run -p 8080:8080 \
  -v /tmp/secrets/:/var/openfaas/secrets/ \
  -ti alexellis2/private-api:0.2.1
```

Then run `curl http://127.0.0.1/` instead of your full OpenFaaS URL.

You can even couple this with docker-compose for a live-reloading experience: [Rapid OpenFaaS hacking with Node.js and docker-compose](https://studio.youtube.com/video/I9_S4vpiCho/edit/basic)

## Wrapping up

In a very short period of time, using standard infrastructure automation tools we were able to create a lightweight Serverless deployment. faasd provides both a cost effective starting-point, and a serverless experience that's very easy to manage. You can use VM backups, or even just delete your instance and re-create it, you have very little else to worry about, just run `faas-cli up` again against the new machine.

If you want to remove your host, just run `terraform destroy`, but at ~5 USD / mo, you may as well keep it up and keep learning.

### Taking it further

There are many other OpenFaaS templates for different languages, and faasd can even run regular containers, as long as they accept HTTP traffic on port 8080.

You'll also find a few differences in faasd vs OpenFaaS on Kubernetes, find out more [in the faasd repo](https://github.com/openfaas/faasd)

You can learn more about OpenFaaS at:

* In the docs: [docs.openfaas.com](https://docs.openfaas.com)
* On the blog: [openfaas.com/blog](https://openfaas.com/blog)

The OpenFaaS [Slack workspace](https://slack.openfaas.io/) is a good place to connect with the community. You can ask questions, get involved, and contribute if you want to.

See other posts from the community on faasd:

* [OpenFaaS with TLS via Faasd and Terraform on Openstack by Mark Sharpley](https://markopolo123.github.io/posts/openfaas-openstack/)
* [Tracking Stripe Payments with Slack and faasd by Mehdi Yedes](https://myedes.io/stripe-serverless-webhook-faasd/)
