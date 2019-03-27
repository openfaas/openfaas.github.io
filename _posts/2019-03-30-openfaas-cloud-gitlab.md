---
title: "Host your own OpenFaaS Cloud with GitLab"
description: Learn how to host your own OpenFaaS Cloud connected to a self-hosted GitLab instance.
# date: 2019-03-30
date: 2019-03-26
image: /images/openfaas-cloud-gitlab/palms-1.jpg
categories:
  - cloud
  - cicd
  - gitops
author_staff_member: alex
dark_background: true
---

In this post, I'll walk you through to host your own OpenFaaS Cloud connected to a self-hosted GitLab instance.

[OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/) provides a managed version of the OpenFaaS experience along with OAuth2, CI/CD, TLS via LetsEncrypt and a personalized dashboard for each user's repo or project in your GitLab instance.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Announcing <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> cloud at <a href="https://twitter.com/DevNetCreate?ref_src=twsrc%5Etfw">@DevNetCreate</a> <a href="https://twitter.com/hashtag/TeamServerless?src=hash&amp;ref_src=twsrc%5Etfw">#TeamServerless</a> <a href="https://twitter.com/hashtag/Serverless?src=hash&amp;ref_src=twsrc%5Etfw">#Serverless</a> <a href="https://t.co/n6hhcRK0I5">pic.twitter.com/n6hhcRK0I5</a></p>&mdash; Jock Reed (@JockDaRock) <a href="https://twitter.com/JockDaRock/status/983779290100613120?ref_src=twsrc%5Etfw">April 10, 2018</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

## Tutorial

We will configure an existing GitLab installation and then use the `ofc-bootstrap` tool to install OpenFaaS Cloud in around 100 seconds.

### Pre-requisites

* A domain-name

You should have a domain name registered - this can be new or existing. You will need to set its nameservers configured to point at either DigitalOcean, Google Cloud or AWS. I recommend using DigitalOcean because it is free at time of writing.

This constraint is due to the use of wild-card TLS certificates and cert-manager and the DNS01 challange.

* A Kubernetes v1.10 or newer cluster

Your cluster can be private and self-hosted, but in post we will install TLS via LetsEncrypt so I recommend you use a managed service such as DigitalOcean, Amazon EKS or Google's GKE.

* A self-hosted GitLab CE or EE instance

You may already have a GitLab installation, if you don't you can [install it easily](https://about.gitlab.com/install/) or use a the official [helm chart](https://docs.gitlab.com/ee/install/kubernetes/gitlab_chart.html).

* `faas-cli`

On MacOS:

```
brew install faas-cli
```

On Linux:

```
# sudo is optional, but moves the binary into your PATH
curl -sLS cli.openfaas.com | sudo sh
```

* `kubectl`

If you haven't already then install `kubectl` from https://kubernetes.io/docs/tasks/tools/install-kubectl/

* `helm`

Install the helm CLI only from https://github.com/helm/helm

### Get `ofc-bootstrap`

The `ofc-bootstrap` tool is used to install OpenFaaS Cloud in a single click. You will need to configure it will all the necessary secrets and configuration beforehand using a YAML file.

```
mkdir -p ~/dev/ofc/
cd ~/dev/ofc/
git clone https://github.com/openfaas-incubator/ofc-bootstrap
cd ~/dev/ofc/ofc-bootstrap
```

Now fetch the latest release from: https://github.com/openfaas-incubator/ofc-bootstrap/releases and save it in `/usr/local/bin/`

Create a new init.yaml file with this command:

```
cp example.init.yaml init.yaml
```

Look for the `### User-input` section of the file

### Plan your DNS records

OpenFaaS Cloud requires 3x A records to be set up, we will point each at the LoadBalancer created later in the tutorial. These URLs will be:

* auth.system.domain.com
* system.domain.com
* *.domain.com

The final entry `*.domain.com` is for each GitLab user or project i.e. `alexellis.domain.com`

In `init.yaml` set your `root_domain` i.e. `domain.com`.

### Configure GitLab

* Edit `init.yaml` and set `gitlab_instance:` to the public address of your GitLab instance.

#### Create an access token

You will need to create an access token with `sudo` permissions and API access.

* Go to your Personal profile
* Click *Access Tokens*
* Create a token
* Name: OpenFaaS Cloud
* Scopes: `api, read_repository, sudo, read_user`

You will be given an API token at this time and must enter it into init.yaml.

Look for: `"gitlab-api-token"` and set the `value` to the value from the UI

#### Create the system hook

This hook will publish events when there is a `git push` into a repo.

* Go to your Admin area.
* Click *System Hooks*
* Enter the URL `https://system.domain.com/gitlab-event` replacing `domain.com` with your domain
* Enter no value for *Secret Token* at this time

![System hooks](/images/openfaas-cloud-gitlab/system-hook.png)

#### Create an OAuth application

The OAuth application will be used for logging in to your dashboard.

* Click Admin Area then Applications
* Click New application
* Under Name enter "OpenFaaS Cloud for GitLab"
* In Redirect URI enter "https://auth.system.domain.com/oauth2/authorized"

* Add the scopes as pictured below

![System hooks](/images/openfaas-cloud-gitlab/scopes.png)

After creating your application you will get a client_id and client_secret.

Set your client_secret in `init.yaml` under: `"of-client-secret"`.

Set your client_id in `init.yaml` under: `oauth` and `client_id`

Set `oauth_provider_base_url` to `https://gitlab.domain.com`, where this is the domain of your GitLab instance.

Set `enable_oauth` to `true`

Under `tls_config` change `issuer_type` to `prod` and `email` to your email.

#### Configure your TLS secret

* Turn on TLS by setting `tls: true`

A secret is required by cert-manager to obtain a wildcard TLS certificate using a DNS01 challenge.

If using DigitalOcean, save an access token to:

```
~/Downloads/do-access-token
```

#### Authenticate to your registry

* Open the Docker Desktop settings and make sure you have “Store my credentials in a key-chain” set to false
* Now run `docker login` and login with your Docker Hub account

If you don't have an account you can sign-up at: https://hub.docker.com

Edit `init.yaml` and set `registry:` to `docker.io/ofctest/` replacing `ofctest` with your username on the Docker Hub.

#### Configure your CUSTOMERS ACL

The CUSTOMERS ACL list containers a list of projects and users for which CI/CD can be triggered.

* Create a public GitLab repo
* Add a CUSTOMERS plain-text file and enter each name on a new line
* Find the Raw URL from the UI
* Edit the line that says `customers_url` and enter the URL

You can edit this file at any time.

#### Run the tool

Make sure your `kubectl` is pointing to the correct cluster.

```
ofc-bootstrap
```

If anything goes wrong you can reset using the `./scripts/reset.sh` bash script found in the GitHub repo which we cloned earlier.

### Post-installation tasks

* Find the IP address of your Kubernetes LoadBalancer for the IngressConroller (Nginx)

```
kubectl get svc/nginxingress-nginx-ingress-controller -o wide
```

Now create your DNS A records as follows all pointing at the same IP:

* auth.system.domain.com
* system.domain.com
* *.domain.com

Now find the generated webhook secret:

```
echo $(kubectl get secret -n openfaas-fn gitlab-webhook-secret -o jsonpath="{.data.gitlab-webhook-secret}" | base64 --decode; echo)
```

Update your "Payload secret" on the System Hooks page. This secret is used to verify the sender of webhooks.

### Create your first functions or microservices

OpenFaaS Cloud will now manage your serverless functions and microservices.

* Create a new repo called `openfaas-cloud-test`

Now add a tag to the repo so that OpenFaaS Cloud knows that it can manage this repository.

* Click Settings and General
* Now Click "General project" and Expand
* Enter a tag of "openfaas-cloud" and hit *Save Changes*.

![](/images/openfaas-cloud-gitlab/repo-tags.png)

> Note: this is not a `git tag` but a GitLab-specific feature

* Clone the repo and enter the directory

* Create a new function:

```
faas-cli template store pull node10-express
faas-cli new --lang node10-express timezone-shift --prefix=dockerhub_username
```

Now let's create a quick function to shift timezones for meetings:

```
cd timezone-shift
npm install --save moment
```

Enter into `handler.js`:

```
"use strict"
const moment = require('moment');
module.exports = (event, context) => {
    let meeting = moment.utc(event.body.meeting)
    let adjusted = meeting.clone().utc().add(-8, 'hours');
    context
        .status(200)
        .succeed({ meeting: meeting.format(), adjusted: adjusted.format() });
}
```

We need to rename our function’s YAML file to stack.yml, so that it can be picked up by the OpenFaaS Cloud CI/CD pipeline.

```
mv timezone-shift.yml stack.yml
```

Push the code:

```
git add .
git commit
git push origin master
```

The function will appear on your dashboard:

![](/images/openfaas-cloud-gitlab/dashboard.png)

And you'll get detailed feedback on your details page, by clicking on the row on the dashboard:

![](/images/openfaas-cloud-gitlab/details.png)

Invoke the function and find out what time your meeting at 5pm in London will be in over in San Francisco:

```
https://username.domain.com/timezone-shift -H "Content-type: application/json" -d ' {"meeting": "2019-02-18T17:00:00"}'; echo

{"meeting":"2019-02-18T17:00:00Z","adjusted":"2019-02-18T09:00:00Z"}
```

You can also use secrets for your functions by encrypting them or "sealing" them using Bitnami's SealedSecrets. [Read more](https://docs.openfaas.com/openfaas-cloud/self-hosted/secrets/).

### Invite your team

You are the first user for your installation, now you can invite your team, colleagues and friends, or keep the environment for yourself. You can enroll new users by adding their usernames or top-level projects to your CUSTOMERS file at any time.

## Wrapping up

We installed OpenFaaS Cloud and enabled CI/CD, TLS and OAuth2 on any repo without any complicated configuration or pipelines or maintenance overhead.
