---
title: "A Reintroduction to OpenFaaS on Nomad"
description: Andrew Cornies reintroduces the faas-nomad provider. Learn why running OpenFaaS on Nomad is a compelling alternative to start your Serverless journey.
date: 2019-03-18
image: /images/openfaas-on-nomad/abstract-blaze-bonfire-211157.jpg
categories:
  - nomad
  - vault
  - hashicorp
  - providers
author_staff_member: andrew
dark_background: true
---

While Kubernetes dominates the chatter in cloud-native circles, HashiCorp's Nomad is quickly becoming its own trusted, agnostic scheduler. It is trusted by Jet, CircleCI and has first-class integration with Docker, Consul and Vault make it a compelling solution to run mixed workloads, including Serverless architectures like the OpenFaaS platform. In this post, I'll share my reasons for choosing Nomad and take you through faas-nomad's Vault integration.

> Author bio: [Andrew Cornies](http://acornies.com) is a principal engineer for Tucows Inc. Prior to that, between 2009 and a successful exit in 2012, he helped build up Rakuten Kobo to a world-class e-book seller. His experience includes full-stack web development, SRE/DevOps, multi-cloud tooling, config management as well as team leadership.

## Why Nomad?

I work in a very heterogeneous environment, so the idea of moving everything to Kubernetes didn't quite make sense due to a few factors:

- Virtually no in-house production experience with Kubernetes at the time (early 2018) and timelines were short
- HashiCorp's Vault and Consul were already in use in production
- The mixed nature of our systems and legacy storage would benefit from a more agnostic scheduler that handled not only Docker/container workloads, but other executables as well

I saw Nomad as the best tool for deploying services.

## The Serverless Draw

I was drawn to the OpenFaaS project because, from my perspective, one the main benefits of the Serverless movement is the idea of increased velocity between a developer's code and a desired endpoint. I had a keen interest in adopting Serverless tech but in an on-premise capacity since our company culture favours running private infrastructure. Another goal of mine was to provide a more structured process for hosting miscellaneous scripts and services that are needed for CI, monitoring and SRE tasks in production.

As the project name suggests, the OpenFaaS architecture is designed to be open and work with any backend or Docker-supported scheduler. This makes it very appealing to organizations who operate their own proprietary systems and infrastructure. Project founder Alex Ellis and the team have done an amazing job building out OpenFaaS on Kubernetes and Docker Swarm experience.

However, Nomad was missing from the officially supported offerings. I then stumbled upon a project started by Nic Jackson (HashiCorp Developer Advocate) and his [initial post](https://www.hashicorp.com/blog/functions-as-a-service-with-nomad) about the OpenFaaS Nomad provider. I immediately had to try it out.

I got OpenFaaS and all the required components launched in my own local Nomad + Vagrant + Docker environment in about 15 minutes (including `vagrant up`). One of the first things I tried to get working was the [Kafka connector](https://github.com/openfaas-incubator/kafka-connector), which is in incubation. While attempting to trigger my first function via a Kafka topic, I ran into my first snag. The Nomad provider had fallen behind, and did not support all the feature of an official OpenFaaS provider. Taking this as a sign that development had stalled, I saw an opportunity to contribute and even take up ownership of the provider.

After posting my first issue, I was pleasantly surprised by the quick response from Alex and his invitation to the Slack community. Members from both OpenFaaS and HashiCorp were present in Slack and answered my questions promptly. This, combined with my yearning to learn Go provided all the incentive I needed to get involved.

OpenFaaS providers are written in Golang, and it is easy to get started with your own backend using the [faas-provider library](https://github.com/openfaas/faas-provider). I had very little experience in Go prior to this project, so I quickly brushed up on some Golang fundamentals and started on some tasks. How hard could it be?

[![OpenFaaS Nomad and Vault Integration](http://img.youtube.com/vi/DObWEaO4etE/0.jpg)](http://www.youtube.com/watch?v=DObWEaO4etE)

*This video demonstrates the use of HashiCorp Vault secrets in your OpenFaaS functions using the faas-nomad provider.*

## OpenFaaS Secrets and Vault

Nomad only provides scheduling functionality. In order to support secrets management and service discovery, faas-nomad requires both Consul and Vault as well. Using this combination of components allows us to build a fully featured OpenFaaS provider for Nomad. Consul provides the service discovery and powers the function proxy. Vault is used in conjunction with Nomad for providing secrets to the functions as well as the newly released API for managing secrets with the faas-cli.

![openfaas-fargate](/images/openfaas-on-nomad/openfaas_nomad_vault.png)

Pre-requisites for the following Vault integration intructions:

- a running Consul server
- a running Nomad server/client w/ Docker driver
- a running Vault server

Let's look at the Vault integration more closely:

### Vault faas-nomad startup arguments

| arg  |  description |
|---|---|
| vault_addr | default from Nomad agent. Overrides the URL of the Vault service. |
| vault_default_policy | default: openfaas. The name of the Vault policy to limit OpenFaaS' access to Vault. |
| vault_secret_path_prefix | default: secret/openfaas. The preconfigured kv v1 secrets backend path. |
| vault_app_role_id | default: empty. The preconfigured app roll ID used with the Vault approle backend. |
| vault_app_secret_id | default: blank. The preconfigured app roll secret ID used with the approle backend. |
| vault_tls_skip_verify | default: false. Skips TLS verification for calls to Vault. Not recommend in production. |

Let's provision a Vault instance so that is can support using secrets with OpenFaaS:

Reference example:
[https://raw.githubusercontent.com/hashicorp/faas-nomad/master/provisioning/scripts/vault_populate.sh](https://raw.githubusercontent.com/hashicorp/faas-nomad/master/provisioning/scripts/vault_populate.sh)

1) Enable the approle auth backend in Vault:

```bash
vault auth enable approle
```

2) Create a policy for faas-nomad and OpenFaaS functions:
   
```bash
vault policy write openfaas policy.hcl
```
   
   Policy file example: [https://raw.githubusercontent.com/hashicorp/faas-nomad/master/provisioning/scripts/policy.hcl](https://raw.githubusercontent.com/hashicorp/faas-nomad/master/provisioning/scripts/policy.hcl)

   It is important that the policy contain: create, update, delete and list capabilities that match your secret backend prefix. In this case, path "secret/openfaas/*" will work with the default configuration.

   Also, faas-nomad takes care of renewing it's own auth token, so we need to make sure the policy uses path "auth/token/renew-self" and has the "update" capability.

3) Setup the approle itself:  
```bash
curl -i \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --request POST \
  --data '{"policies": ["openfaas"], "period": "24h"}' \
  https://${VAULT_HOST}/v1/auth/approle/role/openfaas
```
   This creates the role attached to the policy we just created. The "period" property and duration is important for renewing long-running service Vault tokens.
```bash
curl -i \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  https://${VAULT_HOST}/v1/auth/approle/role/openfaas/role-id
```
Produces the role_id needed for -vault_app_role_id cli argument.
```bash
curl -i \
  --header "X-Vault-Token: ${VAULT_TOKEN}" \
  --request POST \
  https://${VAULT_HOST}/v1/auth/approle/role/openfaas/secret-id
```
   Produces the secret_id needed for -vault_app_secret_id cli argument.

Let's assume the Vault parameters have been populated in the run args ([hcl example](https://github.com/hashicorp/faas-nomad/blob/master/nomad_job_files/faas.hcl)), and you're now running faas-nomad along with the other OpenFaaS components. Now, try out the new faas-cli secret commands:

```bash
faas-cli secret create grafana_api_token --from-literal=foo \
  --gateway ${FAAS_GATEWAY}
```

Now we can use our newly created secret “grafana_api_token” in a new function we want to deploy:
```bash
faas-cli deploy --image acornies/grafana-annotate \
  --name grafana-annotate --secret grafana_api_token \
  --env grafana_url=http://grafana.service.consul:3000
```

As you can see, this workflow allows a developer to quickly write, test and deploy a function which auto-scales, using secrets derived from Vault, managed by the faas-cli. A truly empowering experience that is sure to increase velocity in any development cycle.

## What's next for the faas-nomad provider

With imminent release of Nomad 0.9, expect to see a revamp of this provider including support for:

- Scaling to zero using the faas-idler
- .yaml and .hcl file provider configuration
- Documentation on enabling "direct_functions" using HAProxy, Traefik or Envoy
- E2E TLS examples using Consul Connect
- Vault secrets v2

### Going back to the Kafka connector...
Since support for annotations and labels were added to the Nomad provider in the fall of 2018, I can now trigger functions via the [Kafka connector](https://github.com/openfaas-incubator/kafka-connector), paving the way for some very interesting integrations in the future.

## Wrapping up
I've really identified with the overall mission of OpenFaaS as well as the HashiCorp workflows. I had been looking for an open source project to sink my teeth into and I'm grateful for the support from members of the OpenFaaS community as well as HashiCorp.

OpenFaaS on Nomad provides an alternative path to on-premise or cloud-based Serverless tech. Combined with Consul and Vault, it is quite a compelling stack to start your Serverless journey.

## Get connected
Get connected, ask questions, make comments and suggestions on:

[github.com/hashicorp/faas-nomad](https://github.com/hashicorp/faas-nomad)

[github.com/openfaas/faas](https://github.com/openfaas/faas)

[Slack](https://docs.openfaas.com/community)

[Twitter](https://twitter.com/openfaas)
