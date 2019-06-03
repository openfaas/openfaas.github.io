---
title: "Introducing Serverless with Hashicorp Nomad, Consul, and Vault"
description: Learn how to deploy Serverless Functions on Hashicorp Nomad, Consul, and Vault with faas-nomad, a provider maintained by Andrew Cornies.
date: 2019-06-03
image: /images/openfaas-on-nomad/ian-dooley-407846-unsplash-nomad.jpg
categories:
  - nomad
  - vault
  - hashicorp
  - providers
author_staff_member: andrew
dark_background: true
---

Learn how to deploy Serverless Functions on Hashicorp Nomad with faas-nomad, a provider maintained by Andrew Cornies.

*Introduction by [Alex Ellis](https://twitter.com/alexellisuk), Founder of OpenFaaS.*

Early in the evolution of the OpenFaaS project, I decided to build a modular system, which allowed any component to be replaced easily. This was achieved through the use of loosely-coupled components and interfaces. The RESTful interface of OpenFaaS allows platform developers to build their FaaS provider whilst being able to take advantage of the full ecosystem. The provider interface can be implemented very quickly using a Golang SDK called [faas-provider](https://github.com/openfaas/faas-provider).

Back in February 2017, Nic Jackson from [Hashicorp](https://www.hashicorp.com) heard Alex speaking at the Cloud Native, London meet-up about the OpenFaaS architecture and went on to build [faas-nomad](https://github.com/hashicorp/faas-nomad). `faas-nomad` brings OpenFaaS Functions to the Hashicorp ecosystem.

In 2018 Andrew Cornies from Tucows took over the maintenance of faas-nomad, and writes for us today. I like the simplicity of Nomad and how well the faas-nomad project leverages the entire suite of Hashicorp products - from using Vagrant for the bootstrap, to Vault for secrets to Consul for service discovery.

> Author bio: [Andrew Cornies](http://acornies.com) is a principal engineer for Tucows Inc. Prior to that, between 2009 and a successful exit in 2012, he helped build up Rakuten Kobo to a world-class e-book seller. His experience includes full-stack web development, SRE/DevOps, multi-cloud tooling, config management as well as team leadership.

## Why Nomad?

Hashicorp Nomad is currently trusted by companies such as Jet and CircleCI. It integrates well with Docker and other Hashicorp products such as Consul and Vault. In this post, I'll share my reasons for choosing Nomad and take you through faas-nomad's Vault integration.

I work in a very heterogeneous environment and we did consider moving to Kubernetes, but:

- we had virtually no in-house production experience with Kubernetes at the time (early 2018) and timelines were short
- we already used HashiCorp Vault and Consul in production
- we felt that the mixed nature of our systems and legacy storage would benefit from a more agnostic scheduler that handled not only Docker/container workloads, but other executables such as binaries and JAR files

For these reasons, we saw Nomad as the most appropriate choice for us at the time.

## The Serverless Draw

I was drawn to the OpenFaaS project because, from my perspective, one the main benefits of the Serverless movement is the idea of increased velocity between a developer's code and a desired endpoint. I had a keen interest in adopting Serverless tech but in an on-premise capacity since our company culture favours running private infrastructure. Another goal of mine was to provide a more structured process for hosting miscellaneous scripts and services that are needed for CI, monitoring and SRE tasks in production.

As the project name suggests, the OpenFaaS architecture is designed to be open and work with any backend or Docker-supported scheduler. This makes it very appealing to organizations who operate their own proprietary systems and infrastructure. Project founder Alex Ellis and the team have done an amazing job building out OpenFaaS on Kubernetes and Docker Swarm experience.

I stumbled upon the prior work of by Nic Jackson and his [blog post](https://www.hashicorp.com/blog/functions-as-a-service-with-nomad) describing his work. I know then, that I had to try it out.

I got OpenFaaS and all the required components launched in my own local Nomad + Vagrant + Docker environment in about 15 minutes (including `vagrant up`). One of the first things I tried to get working was the [kafka-connector](https://github.com/openfaas-incubator/kafka-connector), which can be used to trigger functions from Kafka topics.

While attempting to trigger my first function via a Kafka topic, I ran into my first snag. The Nomad provider had not been maintained for several months and lacked the support for adding annotations to topics. Annotations were essential for the kafka-connector. I saw an opportunity to contribute to the ecosystem.

After posting my first issue, I was pleasantly surprised by the quick response from Alex and his invitation to the [OpenFaaS Community](https://docs.openfaas.com/community/). Members from both OpenFaaS and HashiCorp were already present on OpenFaaS Slack in the #faas-provider channel and I got answered my questions very quickly. This, combined with my yearning to learn Go provided all the incentive I needed to step-up my contributions.

The OpenFaaS providers are written in Golang, and it is easy to get started with your own backend using the [faas-provider](https://github.com/openfaas/faas-provider) SDK. Alex outlines what the interface looks like [in this blog post](https://blog.alexellis.io/the-power-of-interfaces-openfaas/).

I had very little experience in Go prior to this project, so I quickly brushed up on some Golang fundamentals and started on some tasks. In a short period of time I took over as the maintainer of the provider. 

<iframe width="560" height="315" src="https://www.youtube.com/embed/JxlmPkxC7-A?start=260" frameborder="0" allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>

Alex invited me to present the Nomad provider to the OpenFaaS community on the regular contributors call.

## OpenFaaS Secrets and Vault

My next task as the new maintainer for faas-nomad after adding annotation support for functions, was to add support for secrets.

[![OpenFaaS Nomad and Vault Integration](http://img.youtube.com/vi/DObWEaO4etE/0.jpg)](http://www.youtube.com/watch?v=DObWEaO4etE)

*Video: how OpenFaaS integrates with Nomad and Vault*

Nomad only provides scheduling functionality. In order to support secrets management and service discovery, faas-nomad requires both Consul and Vault as well. Using this combination of components allows us to build a fully featured OpenFaaS provider for Nomad. Consul provides the service discovery and powers the function proxy. Vault is used in conjunction with Nomad for providing secrets to the functions as well as the newly released API for managing secrets with the faas-cli.

![openfaas-fargate](/images/openfaas-on-nomad/openfaas_nomad_vault.png)

Pre-requisites for the following Vault integration:

- a running Consul server
- a running Nomad server/client w/ Docker driver
- a running Vault server

Let's look at the Vault integration more closely.

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

1) Enable the `approle` auth backend in Vault:

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

With the release of Nomad 0.9, expect to see me revamping the provider to add support for:

- Scaling to zero using the [faas-idler](https://github.com/openfaas-incubator/faas-idler)
- Provider configuration using .yaml and .hcl files
- Support for `direct_functions` (invoking functions directly from the API Gateway)
- E2E TLS examples using Consul Connect
- Vault secrets v2

### Going back to the Kafka connector...

Since support for annotations were added to the Nomad provider in the fall of 2018, I can now trigger functions via the [Kafka connector](https://github.com/openfaas-incubator/kafka-connector). Given that we use Kafka at Tucows, it will pave the way for some very interesting integrations in the future.

## Wrapping up

I really identify with the overall mission of OpenFaaS (Serverless Functions Made Simple) and how well it aligns with the HashiCorp workflows. I had been looking for an open source project to sink my teeth into and I'm grateful for the support from Alex, the OpenFaaS community, and from HashiCorp.

If you already use Hashicorp tooling such as Nomad, Vault or Consul, then a great Serverless experience is only one step away with faas-nomad, and I'd love to help you out with your journey.

See also: Alex's post on OpenFaaS extensibility: [The power of interfaces in OpenFaaS](https://blog.alexellis.io/the-power-of-interfaces-openfaas/).

## Get connected

Now over to you to get connected with the community on Slack. Comments, questions and suggestions are all welcome.

* [Slack](https://docs.openfaas.com/community)

* [github.com/hashicorp/faas-nomad](https://github.com/hashicorp/faas-nomad)

* [github.com/openfaas/faas](https://github.com/openfaas/faas)

* [@openfaas on Twitter](https://twitter.com/openfaas)
