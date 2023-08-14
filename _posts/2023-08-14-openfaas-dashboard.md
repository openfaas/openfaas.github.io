---
title: "Meet the next-gen dashboard we built for OpenFaaS in production"
description: "Learn why we built a new UI dashboard using React, what's different and how you can make use of it."
date: 2023-08-14
categories:
- dashboard
- ui
- production
dark_background: true
image: "/images/2023-08-dashboard/background.png"
author_staff_member: alex
hide_header_image: true
---

Learn why we built a new UI dashboard using React, what's different and how you can make use of it.

You may be familiar with the original UI that I built for [OpenFaaS](https://docs.openfaas.com/) in 2017. It was focused on both invoking functions and deploying new ones from the Function Store. It used the original 1.x version of Angular.js and was built within the first year of the project, it served us well, but the underlying UI frameworks have moved on considerably since its inception.

![Classic UI portal](/images/2023-08-dashboard/classic.png)

> The classic UI, which is part of faasd and OpenFaaS Community Edition (CE) is now in code-freeze which means it isn't receiving changes. That's generally not an issue for its intended audience of personal users and hobbyists.
> If you're using OpenFaaS CE at work, it may be time to check out [what kind of value we've been building](https://docs.openfaas.com/openfaas-pro/introduction/) over the past few years.

I think it was a key part of the adoption and developer love that we saw around the project. People like to see things, but many developers who are attracted to the kind of back-end coding that FaaS frameworks, or Kubernetes controllers bring have an aversion to - or lack of skill in front-end development.

So that's where we come in. As the stewards, and full-time team behind OpenFaaS. We decided to release a new dashboard, with a fresh approach, fresh UI framework (React) and a different approach.

## A new dashboard built for production

The new dashboard is geared around running OpenFaaS in production - so it's for [commercial teams](https://github.com/openfaas/faas/blob/master/ADOPTERS.md) who want more visibility and control over their functions.

OpenFaaS has its own REST API and Grafana dashboards, there's also lots of monitoring options for Kubernetes itself, so what value can we add?

In a word - consolidation - bringing together the most important things you need within one UI for proactive use. For passive monitoring of throughput, scaling, errors and the duration of functions, we'd recommend using the [Grafana dashboards we supply to customers](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/).

Let's take a quick tour of the new features, why we think you'll find them useful, and how you can try each of them out. 

### More options for invocations

We built a brand new experience for invoking functions using a code editor to format the input and output, and a dedicated tab for the response headers. This is a big improvement over the old UI which had a single text box for input and output.

![Invoking figlet from the store](/images/2023-08-dashboard/invoke-figlet.png)

Here's the view showing the response headers:

![The response headers from an invocation](/images/2023-08-dashboard/invoke-headers.png)

You can also supply your own list of headers for the invoke, the method such as GET or POST, an additional path or a query-string. All of this is new.

### Single Sign On (SSO)

One of the biggest concerns I've had is watching commercial teams sharing a single password for their whole OpenFaaS installation. Now we've offered SSO with various OpenID Connect (OIDC) providers for several years, but with our new [IAM for OpenFaaS](https://docs.openfaas.com/openfaas-pro/iam/overview/) feature it's really well integrated.

Here's an example of the redirect to Keycloak, a popular open source project hosted by the Cloud Native Computing Foundation (CNCF):

![Logging in with Keycloak](/images/2023-08-dashboard/keycloak-login.jpg)
> Logging in with Keycloak, which can be federated to OIDC, LDAP and SAML providers.

When combined with the [new IAM feature](https://docs.openfaas.com/openfaas-pro/iam/overview/), you can also restrict access to read-only roles, or even to specific namespaces, or remove access all together from other company employees outside of your group.

![Don't allow everyone with a company email to log in!](/images/2023-08-dashboard/not_authorized.png)
> SSO is fine-grained, so not everyone with a company email can just log in an manage your functions.

Authorized users will gain access to their own namespaces, which is a useful way to do multi-tenancy or just to organise internal teams with OpenFaaS.

![Multiple namespaces](/images/2023-08-dashboard/multiple-namespaces.png)
> Above: You can use a single Kubernetes cluster for multiple stages of our application like production and staging, or for multiple tenants.

Learn more:

* [Docs: IAM for OpenFaaS](https://docs.openfaas.com/openfaas-pro/iam/overview/)
* [Docs: Single Sign-On setup](https://docs.openfaas.com/openfaas-pro/sso/overview/)

### Save your credentials for next time

For those of you who don't use an Identity Provider (IdP) in your organisation, we've gone one better over the previous Basic Authentication approach.

![Your password can now be remembered by a password manager or the browser](/images/2023-08-dashboard/remember-password.png)
> A login form is used with TLS encryption instead of more rudimentary browser-based Basic Authentication.

Your password can now be remembered by a password manager or the browser itself, which makes it easy to manage multiple environments like dev, staging and production.

### Built it for how it'll be used

We know you don't want to deploy functions through the UI in production, so we simply don't offer it. Instead, you can use Helm, [ArgoCD](https://www.openfaas.com/blog/argocd-image-updater-for-functions/), [Flux](https://www.openfaas.com/blog/upgrade-to-fluxv2-openfaas/), kubectl along with the [Function CRD](https://www.openfaas.com/blog/manage-functions-with-kubectl/), the CLI via a CI/CD job, or even the [REST API](https://docs.openfaas.com/reference/rest-api/) to deploy functions.

With the popularity of Infrastructure as Code (IaaC) and GitOps, we are sure that 90% of you will be releasing code from a git repository, with an associated SHA and URL.

With the growing understanding of the dangers of Common Vulnerabilities and Exposures (CVEs) in containers, it's important to know when a function was last deployed.

![SHA, link to repo and deployment date](/images/2023-08-dashboard/sha-overview.png)
> Above: Git SHA, link to the repository, and the date of the last deployment.

You can now hot link directly to a code diff to see what changed in production, if a function is behaving unexpectedly.

![Direct hot-link to the code diff](/images/2023-08-dashboard/diff.png)

> The direct hot-link into GitHub or GitLab will show you the precise change that has made its way into production.

Add the metadata by clicking "Set metadata" on the details page, or by adding the [labels and annotations specified in the documentation](https://docs.openfaas.com/openfaas-pro/dashboard/).

### Bubble up key metrics

The old dashboard had a list of functions, where you'd need to click on each one to find out what was a very limited set of data.

Now, the new dashboard shows: replica count, RAM, CPU, 1hr and 24 hr success vs. error rates, and metadata from CI/CD.

![A much richer overview of what you need to know](/images/2023-08-dashboard/overview-details.png)
> A much richer overview of what you need to know about a function at a glance.

### Logs help you find out what's going wrong

You can now use the new dashboard to view the logs of a function without needing kubectl or faas-cli installed on your machine. That means you can use your iPad, phone, or a more restrictive environment to debug a problem with a function too.

I wrote a very simply function in Go using the `golang-middleware` template to show you how it works.

```golang
package function

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		input = body
	}

	headers := ""
	for k, v := range r.Header {
		headers += fmt.Sprintf("%s=%s, ", k, v)
	}
	headers = strings.TrimRight(headers, ", ")

	log.Printf("Input headers: %v", headers)

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(fmt.Sprintf("Body: %s", string(input))))
}
```

The headers from the request will be logged to stderr and shown on the "Logs" page.

![Invoke input headers](/images/2023-08-dashboard/invoke-input-headers.png)
> The headers being inputted into the invocation

The resulting logs in the dashboard:

![Resulting headers printed into the logs](/images/2023-08-dashboard/logs-headers.png)
> The headers printed into the logs

If you've used an earlier version of this page, then you may have noticed that we've added a new drop-down where you can pick the age of the logs to show going back up to one day.

## Wrapping up

That was a quick tour of the new OpenFaaS dashboard designed for use in production and in commercial settings. You can try it out with OpenFaaS Standard and OpenFaaS for Enterprises by enabling the dashboard in the Helm chart.

Coming up next, we're looking at combining some of the recommendations from the [OpenFaaS config-checker tool](https://github.com/openfaas/config-checker) with the dashboard to show you how to get the most value out of the platform.

The chances are that if you're running in production, you may also benefit from: multiple namespaces, fine-grained permissions, parallelism with JetStream for OpenFaaS, Scale to Zero, the Kafka event connector, and our set of Grafana dashboards for observability.

We find that the OpenFaaS Dashboard is useful for immediate feedback, and the Grafana Dashboards provide us with more proactive monitoring.

![Auto-scaling and usage metrics](https://docs.openfaas.com/images/grafana/overview-dashboard.png)
> Understand if a function has a memory leak, or is consuming excessive CPU, how many replicas are running, how long requests take to process, and how many errors are being generated.

In one recent case, a customer was going to promote a Go function to production, the dashboard showed him a memory leak which he was unaware of - that swiftly got fixed before it cause any potential outage.

In a second case, we noticed on a support call that a function was using 6 vCPU at idle - not just requesting, but actually consuming that amount. The customer was completely unaware, and the UI dashboard helped them to identify the problem.

If you'd like to try out the dashboard for your team, or want to talk to us, [get in touch here](https://openfaas.com/pricing).
