---
title: "Configure your OpenFaaS functions for staging and production"
description: "Learn how to configure your OpenFaaS functions for different environments"
date: 2021-12-09
image: /images/2021-12-environments/background.jpg
categories:
 - environments
 - configuration
 - secrets
author_staff_member: alex
dark_background: true

---

Learn how to configure your OpenFaaS functions for different environments

## Overview

In this article I'll explain the differences between confidential and non-confidential configuration options in OpenFaaS. You'll learn when and how to use both to provide separate configuration for staging and production.

What kinds of things do we need to configure?

Functions are stateless and may make use of external services to store state or synchronise messages:

* Databases - to update or store state
* Queues - for message passing between other parts of your system
* Storage such as S3-compatible endpoints

Functions may also have configuration describing how they should operate such as:

* Log verbosity - do we want more or less detail in staging vs production?
* Timeouts - should we have a lax timeout for local development, but be strict in production?
* Authentication mode - could authentication get in the way of fast, local iteration?
* Faking it - should we be able to fake dependencies on other systems like Stripe or a third-party API?

A third type of configuration may be data stored in a database or a separate system. That's out of scope for this article, and I'll focus just on what you can input via the OpenFaaS API.

For the first set of use-cases, we're primarily talking about confidential data. Things that we would not want in the hands of a hostile actor.

* A password for a Mongo database
* A secret API key for connecting to AWS

For the second set of use-cases, it's less important if this data were to leak or be compromised:

* Is debugging verbose or quiet?
* What is the URL for an internal REST API?
* What timeout is valid for this function?

There may still be an argument for making some of these things confidential, and there's no hard and fast rule.

I'm just going to make you aware of the difference, and then show you how to set up either for different environments.

### The use-case

Let's imagine that we have created some marketing automation that collects emails in return for a coupon code for an eBook. During local testing, I can install Postgresql using `arkade install postgresql` - it'll be completely free for me to run this on my laptop. For production I will use DigitalOcean's managed Postgresql service with backups enabled and highly-availability - it'll cost me several hundred dollars per month. 

The database will have:

* Database name
* Endpoint - DNS endpoint and TCP port
* Whether SSL is enabled
* Username and password

![Staging configuration](/images/2021-12-environments/staging.png)
> The Staging configuration for our database and marketing function uses a disposable, local database.

So how do we configure this using the standard [OpenFaaS CLI](https://github.com/openfaas/faas-cli) and its [stack.yaml file](https://docs.openfaas.com/reference/yaml/)?

### Confidential configuration

In OpenFaaS confidential configuration is defined through a secret. The value of a secret cannot be retrieved by the OpenFaaS API, and when using Kubernetes, its backing store (etcd) can encrypt the data.

Secrets are attached to containers via files under `/var/openfaas/secrets/NAME`.

It's debatable whether the URL for your database is confidential. For argument's sake, let's say that we only want to protect the password.

```bash
faas-cli secret create \
    marketing-db-password \
    --from-file marketing-db-password.txt \
    --trim
```

You must first create a secret, then you can attach it to your function via its YAML file:

```yaml
  list:
    lang: python
    handler: ./list
    image: ghcr.io/example/marketing-list:0.2.0
    secrets:
      - marketing-db-password
```

Then we can consume the string from our code by reading the file:

```python
read_secret(key):
    with open('/var/openfaas/secrets/{}'.format(key), 'r') as f:
        return f.read().strip()

    return value
```

How do we have separate values for production and staging?

We can either set different OpenFaaS gateway URLS and text files for the source password:

```bash
faas-cli secret create \
    marketing-db-password \
    --gateway https://staging.example.com \
    --from-file marketing-db-password-stag.txt \
    --trim

faas-cli secret create \
    marketing-db-password \
    --gateway https://prod.example.com \
    --from-file marketing-db-password-prod.txt \
    --trim
```

With this approach, we only need one `stack.yaml` file with the secret listed, and change the gateway field.

Or we use different namespaces within the same cluster and OpenFaaS URL:

```bash
faas-cli secret create \
    marketing-db-password \
    --gateway https://prod.example.com \
    --namespace staging \
    --from-file marketing-db-password-stag.txt \
    --trim

faas-cli secret create \
    marketing-db-password \
    --gateway https://prod.example.com \
    --namespace prod \
    --from-file marketing-db-password-prod.txt \
    --trim
```

With this approach, we can still use one `stack.yaml` file, but we need to change the namespace field using a flag.

### Non-confidential configuration

For non-confidential configuration, we can use the `environment` section of the stack.yaml file:

```yaml
  list:
    lang: python
    handler: ./list
    image: ghcr.io/example/marketing-list:0.2.0
    environment:
      DB_HOST: postgresql.svc.local:5432
```

But how can we make `DB_HOST` take two different values? One for my local Postgresql installed with arkade, and one for the DigitalOcean version?

From speaking to users, I learned of many workarounds for this, but we do have a way to support this in the project already.

![Production configuration](/images/2021-12-environments/prod.png)
> The Production configuration for our database and marketing function uses an expensive, highly available, managed database.

First, `environment` can be changed to `environment_file` to source the data from an external file:

db_envs.yaml

```yaml
environment:
    DB_HOST: postgresql.svc.local:5432
```

```yaml
  list:
    lang: python
    handler: ./list
    image: ghcr.io/example/marketing-list:0.2.0
    environment_file:
      - db_envs.yaml
```

This makes the actual value external to the file, but we still need two copies.

> That's where a very simple but powerful feature comes in. Environment variable substitution.

`db_envs_stag.yaml`

```yaml
environment:
    DB_HOST: postgresql.svc.local:5432
    DB_MODE: ""
    DB_NAME: postgresql
```

`db_envs_prod.yaml`

```yaml
environment:
    DB_HOST: todo-pg11-do-user-2197152-0.b.db.ondigitalocean.com:25060
    DB_MODE: sslmode=require
    DB_NAME: defaultdb
```

Then notice how the filename for `environment_file` changes:

```yaml
  list:
    lang: python
    handler: ./list
    image: ghcr.io/example/marketing-list:0.2.0
    environment_file:
      - db_envs_${OF_ENV:-stag}.yaml
```

The text `db_envs_${OF_ENV:-stag}.yaml` will evaluate to `stag` by default, unless the environment variable `OF_ENV` is set.

```bash
# Deploy to staging using the default
faas-cli deploy

# Deploy to staging using an override
OF_ENV=stag faas-cli deploy

# Deploy to production
OF_ENV=prod faas-cli deploy
```

To add more environments, simply add more named files.

### Alternative ways to deploy functions

We've now explored how to define confidential and non-confidential configuration for functions for multiple environments using `faas-cli`.

Some other ways you can deploy:

* [Using `kubectl apply` and the OpenFaaS Function Custom Resource](https://www.openfaas.com/blog/manage-functions-with-kubectl/)
* [Using ArgoCD](https://www.openfaas.com/blog/bring-gitops-to-your-openfaas-functions-with-argocd/)
* [Using Flux v2](https://www.openfaas.com/blog/upgrade-to-fluxv2-openfaas/)

OpenFaaS also has a REST API which is documented in [Serverless For Everyone Else](http://store.openfaas.com/l/serverless-for-everyone-else) along with examples on usage.

## Wrapping up

I have a few questions for you:

* How does your team configure your functions for different environments?
* What CI/CD tools do you use to deploy your code?
* Have you implemented any additional tooling or optimizations? What would make life easier for you?

You may also like my tutorial on building and deploying multi-arch functions via GitHub Actions: [Build at the Edge with OpenFaaS and GitHub Actions](https://www.openfaas.com/blog/edge-actions/)

If you have questions, comments or suggestions, please reach out via Twitter [@alexellisuk](https://twitter.com/alexellisuk)
