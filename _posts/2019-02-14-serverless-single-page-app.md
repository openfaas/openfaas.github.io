---
title: "How to build a Serverless Single Page App"
description: Alex outlines an architecture for building a Single Page App (SPA) with Serverless Functions using Vue.js for the front-end, Postgres for storage, Go for the backend and OpenFaaS with Kubernetes for a resilient scalable compute platform.
date: 2019-02-14
image: /images/single-page/beach-clouds-daytime-994605-crop.jpg
categories:
  - end-user
  - single-page-app
  - tutorial
  - kubernetes
  - openfaas-cloud
author_staff_member: alex
dark_background: true
---

Whatever the term "Serverless"  means for you, it is *very much here*. You may be wondering where that leaves you when you need to build and ship a Single Page App for a customer, a client or for an internal project.

My aim in this post is to outline the architecture and patterns I applied in a real-world example. You can then cookie-cut the code and change whatever you need for your own use-case or business problem. The concepts are portable whether you are using OpenFaaS, Lambda or another platform.

## Background to the application

With the number of [OpenFaaS](https://github.com/openfaas/) contributors growing over 350% in 12 months and around a dozen [GitHub repos](https://github.com/openfaas/), it became ever more complicated to accurately say how many people had contributed, how many GitHub stars we had or how many commits were in the project, and where. One of the earliest contributors to OpenFaaS is [Ken Fukuyama](https://twitter.com/kenfdev), he wrote an OpenFaaS provider to bring Serverless to Rancher 1.x and since then he’s been instrumental in building and maintaining the visual aspects of the UI in the project.

Between the two of us we came up with an idea to [make a function](https://github.com/kenfdev/faas-github-stats/blob/master/github-stats/handler.js) to give us an accurate count of contributors, commits and stars etc. This was really useful for me in the first 12 months of the project where I needed to be able to present accurate data on how we were growing and gaining traction. I would invoke the function with `curl` before a presentation and then update my slides or reply to an analyst/editor with that data. The statistics felt flat and hard to parse as text, so Ken put together [a page](https://github.com/kenfdev/faas-github-stats/tree/master/assets/github-stats-page) with [Vue.js](https://vuejs.org) to render a leaderboard and a number of charts to show the breakdown of each repository.

![v1 of the leaderboard](/images/single-page/leaderboard-v1.png)

Use can use [this link](https://kenfdev.o6s.io/github-stats-page#/) to view the statistics of the OpenFaaS project, rather than a single component.

Around a year and a half ago I started [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/) to provide a managed and automated OpenFaaS experience. One of my primary goals was to allow the community to build and deploy functions with HTTPS, without having to worry about managing or paying for a [Kubernetes](https://kubernetes.io) cluster. We have deployed Ken’s function to the Community Cluster and it’s publicly accessible. 

## Today’s application

Our application will show a leaderboard of engagement comprising of all the GitHub users who have opened a GitHub issue or who have commented on an issue. It’s designed to measure and reflect engagement on GitHub issues as it happens.

![](/images/single-page/leaderboard-v2.png)

*Our Single Page App, when done will look like this with live data.*

### Why Serverless?

There are a number of benefits to using a Serverless approach with OpenFaaS for this application:

* Portable to any cloud
* Same experience on a cluster as on your laptop
* Simple workflow backed by [Kubernetes](https://kubernetes.io)
* Developer-friendly UX
* Open Source & MIT licensed
* Write code in any programming language

Now, you may very well be able to do all of the above using a micro-services framework such as Spring, but what a micro-services framework will not do for you is automate all the boilerplate entrypoint code, timeouts, retries, health-checks, logging, metrics, Dockerfile creation and maintenance or auto-scaling. We found that around 300 lines of YAML were required to define a basic HTTP service correctly on Kubernetes, with the OpenFaaS [stack.yaml file](https://docs.openfaas.com/reference/yaml/) this was reduced to 4-6 lines.

Much of the benefit of using a framework like OpenFaaS is being able to move faster because you only have to care about writing your code. We’ll also cover some of the benefits of using OpenFaaS Cloud as a managed platform whether that is self-hosted or through the Community Cluster or another vendor.

### Architecture

Conceptual design:

![](/images/single-page/architecture.svg)

We will have three functions:

* [leaderboard-page](https://github.com/alexellis/leaderboard-app/tree/master/leaderboard-page) which is a Single Page App written in [Vue.js](https://vuejs.org) and served by a Node.js function as a static website. It makes a GET request using `axios` to the `leaderboard` function. They are both served from the same domain so there are no concerns about CORS.
* [leaderboard](https://github.com/alexellis/leaderboard-app/tree/master/leaderboard) which is a Golang function that executes a [Postgres](https://www.postgresql.org) function to query the current statistics.
* [github-sub](https://github.com/alexellis/leaderboard-app/tree/master/github-sub) which is our pub-sub function written in Golang and connected to a webhook on our GitHub organisation or repo. It receives events, validates them with HMAC and then performs an insert for new users and activities.

So whilst today’s application is inspired by the GitHub API stats function Ken and I wrote, but it has evolved in several ways:

* Rather than querying REST APIs, burning through our rate-limit and dealing with pagination, our new code receives webhooks from GitHub through pub-sub.
* Each webhook is parsed then ingested into two Postgres tables - one for users and one for the events.
* The leaderboard is rendered from a Postgres function (aka. Stored procedure).
* Instead of measuring commits per person, we’re measuring engagement. This is a great way to make the end result more inclusive to those who don’t write code, but who do give user support on GitHub.

You can view the complete code at the end of the post, but here are examples of functions using the templates we are using today. OpenFaaS also allows you to customize and build your own templates to suit your needs which includes writing templates for other languages such as Swift, Rust, Erlang or even Bash.

* [node10-express](https://github.com/openfaas-incubator/node10-express-template)

This template allows custom HTTP headers to be written back to the caller and uses a handler which is similar to Node.js for AWS Lambda.

When you generate a new function using `faas-cli new` this is the handler you get:

```js
"use strict"

module.exports = (event, context) => {
    let err;
    const result =             {
        status: "You said: " + JSON.stringify(event.body)
    };

    context
        .status(200)
        .succeed(result);
}
```

* [golang-middleware](https://github.com/openfaas-incubator/golang-http-template#20-golang-middleware)

The Golang middleware template allows us to use a persistent connection to Postgres or to take advantage of connection-pools.

When you generate a new function using `faas-cli new` this is the handler you get:

```go
package function

import (
	"fmt"
	"io/ioutil"
	"net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := ioutil.ReadAll(r.Body)

		input = body
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Hello world, input was: %s", string(input))))
}
```

Both templates, and many more are available in the Template Store via `faas cli template store list / pull` commands.

### The infrastructure

When applying a Serverless approach, we should assume that functions are stateless and ephemeral, storage will be managed separately from compute. In this example OpenFaaS manages the compute on Kubernetes and DigitalOcean will provide the storage. In any case, you'll notice that we need to have very little concern for infrastructure such as VMs, Dockerfiles and TCP ports compared to traditional monolithic or microservice development.

* Compute, monitoring, security CI & CD, secrets management

In this example I am using the OpenFaaS Cloud Community Cluster which provides all of the above for free without us having to manage or worry about servers. You can deploy your own self-hosted OpenFaaS Cloud in 100 seconds using the off-bootstrap tool. Alternatively you can deploy OpenFaaS to your laptop and build and deploy using the `faas-cli` tool.

* Ingress, rate-limiting, load-balancers, HTTPS and auto-scaling

When pushing code to a Git repo managed by OpenFaaS Cloud, you do not have to worry about configuring infrastructure.

As part of the OpenFaaS Cloud installation tool the following are configured:

* An IngressController pre-configured with rate limiting
* Wild-card TLS certificates for HTTPS via LetsEncrypt using cert-manager
* Auto-scaling rules and memory limits for each function
* OAuth2

See all of this and more provisioned in 100 seconds using [ofc-bootstrap](https://docs.openfaas.com/openfaas-cloud/intro/#self-hosted)

{% include youtube.html id="Sa1VBSfVpK0" %}

* CI/CD

OpenFaaS Cloud has native integrations into GitHub, all I have to do is install the GitHub App using the official link and I’m good to go. From there I’ll get updates via GitHub checks and commit statuses, including function build logs and unit test results.

* Secrets management & configuration

We need several pieces of configuration - the non-confidential data will use environment variables and the confidential data such as the Postgres hostname, username and password will be secrets. We also need another secret for the GitHub webhook secret, so that we can validate data is really coming from GitHub and not a bad actor.

The [OpenFaaS CLI](https://github.com/openfaas/faas-cli) allows secrets to be created for Swarm, Kubernetes or Nomad by typing `faas-cli secret create`, but when running on OpenFaaS Cloud we can encrypt our secrets using [Bitnami’s SealedSecrets project](https://github.com/bitnami-labs/sealed-secrets) and then leave them in our GitHub repo as a `secrets.yaml` file. Upon git push these secrets will be read into the cluster, decrypted (unsealed) and attached to our functions.

I used this command to create the secrets we needed for the app:

```sh
faas-cli cloud seal --name=alexellis-leaderboard-app-secrets \
--literal username="$PG_USER" \
--literal password="$PG_PASSWORD" \
--literal host="$PG_HOST" \
--literal webhook-secret="$GH_WEBHOOK_SECRET" \
--cert=./pub-cert.pem
```

If you want to try the example you'll need to run the command to re-generate the secrets for your own account.

At runtime OpenFaaS secrets are made available via `/var/openfaas/secrets/<name>`.

* Postgres

In this example I am using [Postgres 10](https://www.postgresql.org/docs/10/index.html) hosted on [DigitalOcean](https://www.digitalocean.com/) using the new DBaaS service. It costs around 15 USD at time of writing and gives a node which can accept 22 concurrent connections and has 1GB RAM, 10GB storage.

You can read the DigitalOcean press-release here: [Announcing Managed Databases starting with Postgres](https://blog.digitalocean.com/announcing-managed-databases-for-postgresql)

![](/images/single-page/do-postgres-cluster.png)

If you are following along then head over to your [DigitalOcean dashboard](https://www.digitalocean.com/) or use these [free credits](https://m.do.co/c/8d4e75e9886f) to sign-up today and provision your Postgres instance. Take a note of all the parameters needed to connect and secure your database.

When running locally, you can just [install Postgres with helm](https://github.com/helm/charts/tree/master/stable/postgresql) and then update the hostname to use in-cluster DNS.

## Check it out

* Pushing code

Each time I push code, GitHub gives me detailed feedback through the Checks page including Docker build logs and unit test results.

![](/images/single-page/commit-statuses.png)

You can view the test results on the checks page, or via your dashboard using the Build Logs button.

![](/images/single-page/docker-build.png)

* Getting an overview

The personalized dashboard shows you your functions as deployed in the cluster. It uses OAuth2 to delegate authorization and authentication to either GitHub or GitLab. At time of writing I'm using a private GitHub repo for the demo as you can see from the icon.

You can see the three functions appeared after my last commit to the repository.

![](/images/single-page/overview-dashboard.png)

* Digging into the detail

On my dashboard I can see specific details including a breakdown of invocations and any errored requests. I can even download my image to deploy locally on my own cluster or laptop.

![](/images/single-page/details-dashboard.png)

Each function is automatically secured with HTTPS to encrypt traffic.

### Read the code

You can find the code for all three functions in the following GitHub repo. Fork or star the repo and share with your network.

* [alexellis/leaderboard-app](https://github.com/alexellis/leaderboard-app)

Functions:

* [github-sub](https://github.com/alexellis/leaderboard-app/tree/master/github-sub) - the GitHub event ingestion function in Go using the [database/sql](https://golang.org/pkg/database/sql/) and [github.com/lib/pq](https://github.com/lib/pq) packages. We create the connection in the `init()` function of the handler so that a persistent connection is available.
* [leaderboard](https://github.com/alexellis/leaderboard-app/tree/master/leaderboard) - the Go function for rendering the latest statistics as JSON
* [leaderboard-page](https://github.com/alexellis/leaderboard-app/tree/master/leaderboard-page) - the Vue.js dashboard. The client folder contains the `src` and `dist` folders, and the `handler.js` acts merely to serve the static assets when deployed.

Other files:

* `stack.yml` - defines the functions and is generated by the `faas-cli`
* `secrets.yaml` - defines encrypted or "sealed" secrets generated by `faas-cli cloud seal`

The database schema is written in the README.md file at the root.

Contributions are welcome, but must follow the [contribution guide](https://github.com/alexellis/leaderboard-app/blob/master/CONTRIBUTING.md).

### What's left?

The schema is now tracking issue comments and issues opened, but should also cover pull requests opened and pull request comments along with any other interesting events that measure community engagement.

In our v1 leaderboard we didn't store any data, but let GitHub's API handle that, if we publish our application and plan to use it to store personally identifiable information (PII) then we need to do two things:

* Validate that our usage of data is valid with [GitHub's data usage policy](https://help.github.com/articles/github-terms-of-service/)
* Create a privacy policy and [GDPR statement](https://eugdpr.org), then make surface that to users
* Create a data-retention plan in line with regional data protection laws

## Over to you

Now it’s over to you to test it out, read the code and create your own complete applications using Serverless technology. Using the approaches outlined here you can create code that can be deployed just as easily to a proprietary platform such as Azure functions or AWS Lambda or to an Open Source platform such as [OpenWhisk](https://github.com/apache/incubator-openwhisk), [Knative](https://github.com/knative/) or [OpenFaaS](https://github.com/openfaas/faas).

One size does not fit all, so if it’s important to you that your functions framework is lightweight, simple to operate and easy to understand, you can start your journey with us today by [joining us on Slack](https://docs.openfaas.com/community)

* Find out how to try OpenFaaS Cloud or self-host in 100 seconds on Kubernetes: [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/)

* Is this all new? Get started with our hands-on labs [openfaas/workshop](https://github.com/openfaas/workshop), which is tried and tested material for learning at your own pace.
