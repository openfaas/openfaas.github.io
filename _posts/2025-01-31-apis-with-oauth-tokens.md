---
title: "How to access APIs with OAuth tokens from OpenFaaS functions"
description: "Learn how headless functions can access APIs which need to be authorized by a human in front of a keyboard for background jobs and ETL tasks"
date: 2025-01-31
author_staff_member: alex
categories:
  - oauth
  - cron
  - integration
  - apis
dark_background: true
image: /images/2025-01-apis-oauth-tokens/background.png
hide_header_image: true
---

Learn how to access APIs that require OAuth tokens from your functions, from the initial token exchange and capture, to refreshing the token periodically.

## Introduction

As we explored my previous blog post [How to integrate with OpenFaaS Functions](/blog/integrate-with-openfaas/), a very common use-case for functions is a background job triggered from a cron schedule. Most of these background jobs import, check, transform, or update some external data. This pattern is often called Extract, Transform & Load (ETL).

What kinds of use-cases are there for accessing APIs in a background job?

* Expense reconciliation - an employee has been away at a conference, and needs to submit receipts to [Concur.com](https://concur.com) or [expensify.com](https://expensify.com). The function gains access to your Gmail account, and scans for emails that have the same dollar value as the unexplained card transaction, then uploads the receipt to the expense system.
* Quota checks - your director doesn't want your cloud spend to increase beyond 10,000 USD per month, but the spending is spread across multiple cloud providers. A function obtains the credentials for each using a restrictive IAM policy, then queries cloud usage and saves it in a database. Another function runs hourly to check the total spend, and sends an alert if it's over the limit.
* Analytics / reports - an entrepreneur who sells digital products on [Gumroad](https://gumroad.com) wants to know how many sales they made in the last week vs the previous week to analyse their products' performance. With a function, they're able to enhance the Gumroad product without having to rely on the Gumroad team to build the feature.
* Notifications - you may have launched a new product, and want an alert to be sent to the team when you hit certain milestones such as 100, 1000, 10000 daily active users. Rather than building this into your product's roadmap and sprints, you could build an external function to query the API and send the alert.
* Data enrichment for a CRM - say you have people signing up for your service with their work email, a function could use a third-party API such as [Crunchbase.com](https://crunchbase.com) to look up the company, and enrich the user's profile with the company's size, funding, and other details.
* Collaboration - you may have a team that uses Slack, and you want to create a function that can be triggered from a Slack command to create a Zoom meeting, or to create a new Google Doc and invite a certain set of users.

These are just a few ideas, they typically only need one replica of copy of the code to be running. They run a request in the response to an event, or on an hourly, daily, or weekly cron schedule. They don't need to be highly available, but they do need to be secure.

External APIs exposed over HTTP tend to have their own authentication mechanisms.

**Static Access Tokens**

These are the simplest to work with, you go to an admin or settings page, and click "Generate API key" or "Generate Access Token". Sometimes you'll also select a set of scopes or permissions for what the token can access.

For instance, for a very long time, DigitalOcean the cloud provider used to offer only Read or Write tokens for [their API](https://docs.digitalocean.com/reference/api/oauth/). This meant that if you wanted to create a Droplet from a function, you'd need a Write token. Quite recently, they added much more fine-grained scopes for various operations, so if you wanted a token that can only create Droplets, but not delete them, you can do that.

Another very popular API would be [GitHub's](https://docs.github.com/en/rest/authentication/authenticating-to-the-rest-api?apiVersion=2022-11-28). They offer a number of more advanced integration options using OAuth or GitHub Apps, but the most popular due to its simplicity is the Personal Access Token. This token can be used to access the GitHub API, and can be scoped to read or write access to repositories, or even more fine-grained access.

So why are Static Access Tokens not used everywhere?

Static Access Tokens are great for single users, like a function built only to access your own account. But if you wanted to offer a service to others, you would need them to create and provide you with an access token, permissions, etc. OAuth is a standard that allows users to grant access to their data to third-party applications.

**OAuth Tokens for humans and webpages**

The first experience most people will have of OAuth may be something like a "social login" - log into a website with your Facebook.com account, without creating a username and password. Or perhaps you pay for an add-on for YouTube that creates descriptions for your videos, and it needs to access your YouTube account, it'll use an OAuth flow to obtain that permission, then save it and hold onto a credential. The website may encrypt and store the token in a browser cookie or a short-lived session.

The most typical web-based flow is the [Authorization Code Grant](https://oauth.net/2/grant-types/authorization-code/), which requires a user to be present. The user must grant the application the specific permissions/scopes and click buttons to accept the request. But what if you want to access that same API from a function?

A function triggered from Cron i.e. once per day cannot click through a web flow, type in your password, or click "Allow". So how do you get an OAuth token?

**OAuth Tokens for Functions**

The main option for headless functions to obtain an OAuth token is through a flow that uses a specific credential created in the OAuth system, namely *Client Credentials* with a *Client ID* and *Client Secret*. This flow is not much better than a Static Token, and you'll find that for some APIs, it's simply not offered in any way. Our team moved from Slack to Discord for work, and found that Discord lacked a Zoom add-on for creating meetings on the fly. We set out to build one, and were pleasantly surprised that Zoom offered a server-to-server / headless OAuth flow.

You can see how this worked in my article from the time: [Build a serverless Discord bot with OpenFaaS and Golang](https://www.openfaas.com/blog/build-a-serverless-discord-bot/)

If you need to access an API that uses OAuth, *client credentials* and similar headless flows will likely be the most convenient way to do so.

But when I was trying to interact with my bank's API, I couldn't find any kind of *client credentials* or *headless* flow. I had to come up with an alternative solution.

The hybrid approach involves an initial activation by a human user present at a keyboard:

* The function starts off in a disabled state, and cannot be used
* A human user visits a specific path such as `/function/NAME/enable` and an Authorization Code flow is initiated, with the callback being the function itself i.e. `/function/NAME/oauth2/callback`
* The user logs in, and grants the function access to their account, the function captures the Authorization Code and uses it to obtain an Access Token and Refresh Token.
* The function stores the tokens in a secure store, such as a Kubernetes Secret, or uses a symmetric encryption key to encrypt the string and store it in a database.

![User authorization and token storage](/images/2025-01-apis-oauth-tokens/user-token.png)
> User authorization and token storage, ready for subsequent invocations

Once activated with a credential, the function can be scheduled to run on a cron, or triggered by an event without anyone present.

* The function starts, and reads the token from memory or the secret
* If the token is expired, it uses the Refresh Token to obtain a new Access Token, without the user being present, the new Access Token is stored in the same way as during activation.
* The function can now access the API on behalf of the user, until the token expires again.

## Example Function in Go

We'll use Go for the example, since that's the language I tend to use the most for OpenFaaS, and OpenFaaS itself is built in Go. However, you could port the example to our Node or Python template in a matter of minutes, you could even use an LLM to do that for you.

This function will be used to fetch the last recorded sale of an eBook, software subscription, or a physical product from a vendor's store on Gumroad. What you do with the API, is very much down to your own use-case, we're just showing how to do something with the token to show it works.

I used the documentation at [https://gumroad.com/api](https://gumroad.com/api) to help me write the example.

The below will mostly cover the setup adn configuration of the function, with a brief mention of the handler, the rest is on GitHub since the code spans a number of pages.

Create a new function, setting `OPENFAAS_PREFIX` to your account or repository on a container registry:

```bash
export OPENFAAS_PREFIX="alexellis2"

faas-cli new --lang golang-middleware etl-oauth
```

Navigate to the API in question and create an OAuth App (sometimes called an "Application"), you will be given a *Client ID* and a *Client Secret*. Make sure you provide a callback URL to the function i.e. `https://example.com/function/etl/oauth2/callback`.

![](/images/2025-01-apis-oauth-tokens/create-app.png)
> Create an OAuth App

Edit `stack.yaml` and include a `secrets:` section:

```yaml
functions:
  etl-oauth:
    secrets:
    - oauth2-client-id
    - oauth2-client-secret
    - oauth2-access-token
    - oauth2-refresh-token
```

Create secrets for the function:

```bash
faas-cli secret create oauth2-client-id --from-literal=""
faas-cli secret create oauth2-client-secret --from-literal ""

# These will be obtained later
faas-cli secret create oauth2-access-token --from-literal "empty"
faas-cli secret create oauth2-refresh-token --from-literal "empty"
```

There are a number of places where the token can be stored once obtained, for the purposes of this example, we'll use the OpenFaaS REST API to store the token in a Kubernetes Secret.

Create a secret for the function with the admin password for the gateway in the `openfaas-fn` namespace so it's accessible from the function:

```bash
PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath='{.data.basic-auth-password}'|base64 --decode)
faas-cli secret create basic-auth-password --from-literal $PASSWORD
```

Now add the following to the `stack.yaml` file:

```yaml
functions:
  etl-oauth:
    secrets:
    - basic-auth-password
```

Your function now has the static secrets it needs to perform a token exchange, plus dynamic secrets to be updated later, and the gateway's password to store the updated Access Token and Refresh Token.

This function will not need to scale beyond a single replica, it's task will be a fairly simple background ETL job, so we can limit its scaling to 1 replica:

```yaml
functions:
  etl-oauth:
    labels:
      com.openfaas.scale.min: "1"
      com.openfaas.scale.max: "1"
```

Most OAuth flows are fairly standard, but you will find variances. This is unfortunate and cannot be changed, so if you find that the API you're working with wants an additional header passing in, a different content-type, etc, then you should be able to adapt the code with relative ease.

Here is an example token I received with the `view_sales` scope.

Perhaps your function collects all the sales of the past week, and sums them up for an insightful weekly email breaking down the sales by region, or performance vs the previous week.

```json
{
"access_token":"",
"token_type":"Bearer",
"refresh_token":"",
"scope":"view_sales",
"created_at":1738322858
}
```

The code ended up being quite long for this function, so instead of quoting it all in this webpage, you can explore the [handler on GitHub](https://github.com/alexellis/etl-oauth/blob/master/etl-oauth/handler.go).

The handler is responsible for routing the incoming request based upon the HTTP path and the current state, such as whether a token is available or not.

If a token is not available, and a user visits the URL, they'll be redirected to a page that will then redirect them to Gumroad to authorize the application. Once the user has authorized the application, they'll be redirected back to the function, where the function will capture the Authorization Code, and use it to obtain an Access Token and Refresh Token.

```go
package function

func Handle(w http.ResponseWriter, r *http.Request) {
	if r.Body != nil {
		defer r.Body.Close()
	}

	if r.Method != http.MethodGet {
		w.WriteHeader(http.StatusMethodNotAllowed)
		return
	}

	if r.URL.Path == "/enable" {
		handleEnable(r, w)
		return
	} else if r.URL.Path == "/oauth2/callback" {
		handleCallback(r, w)
		return
	}

	// If the default path is hit before a token is available, then redirect to the enable path
	if oauth2AccessToken == "empty" {
		redirect, _ := url.Parse(publicURL)
		redirect.Path = path.Join(redirect.Path, "/enable")
		http.Redirect(w, r, redirect.String(), http.StatusTemporaryRedirect)
		return
	}
}
```

Once authorized, and a token is available in the secret, the handler will fall through into the logic of the job itself:

```go
    // Continued from handler.go

	// Look back around 7 days
	after := time.Now().Add(time.Hour * -24 * 7)

	lastSale, err := getLastSaleValue(after)
	if err != nil {
		log.Printf("error getting last sale value: %s", err.Error())
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	fmt.Fprintf(w, `<!DOCTYPE html>
<html><head><title>Last sale</title></head>
<body><h1>Last sale</h1>
<p>%+v</p>
</body></html>`, lastSale)
}
```

Whilst I was exploring the API, I noticed that:

* There was no `expires_in` field in the token
* There was no documentation on how to refresh the token (if it ever expires)
* There was no documentation on how to refract the specific token

Copy the handler.go file from the sample repository into your function's directory.

Deploy the function with:

```bash
faas-cli up --tag=digest --publish
```

When you visit the function's URL, it will redirect you to the `/enable` path, where you can log in and grant the function access to your account. The function will then store the Access Token and Refresh Token in the Kubernetes Secret.

`https://example.com/function/etl-oauth`


![Authorizing the account](/images/2025-01-apis-oauth-tokens/authorize-app.png)
> Authorize the application to access your account for the specific scope

The function will then store the Access Token and Refresh Token in the Kubernetes Secret using the OpenFaaS API and give a success message:

![The success message](/images/2025-01-apis-oauth-tokens/fn-enabled.png)
> The success message from the function after the token exchange

Then, whenever you visit the function's URL again, it will perform the query and print out the results in the HTTP response. Ideally, you should move these to log statements, or take some other action based upon the data you find. The example leaks the data deliberately, so that you can see it's working.

![Data from the REST API](/images/2025-01-apis-oauth-tokens/last-sale.png)
> Data from the REST API obtained with the Access Token

The values are held in cents, so you can see that for this particular transaction the user paid 24.99 USD and the fee taken was 3.75 USD, roughly 15% of my revenue.

## Further work

**Opaque vs JWT Access Tokens**

Some APIs like Gumroad will return an opaque token which cannot be parsed or unpacked by your function. Others are returned as JSON Web Tokens (JWTs) which can be parsed with a special library to extract what claims they have, when they were issued, who they were issued to, and when they'll expire.

**PKCE extension to OAuth2**

An extension was built for the Authorization Code Grant called [Proof Key for Code Exchange (PKCE)](https://oauth.net/2/pkce/). When we built the [Single-Sign On (SSO) integration for OpenFaaS](https://docs.openfaas.com/openfaas-pro/sso/overview/), we found that just like Gumroad, Google didn't support the PKCE flow either. Ultimately, whilst OAuth2 is a standard, you will find a lot of variance.

The code example I've included doesn't use the PKCE flow, but it is not much more code or work to implement it, an LLM could probably suggest the changes for you.

As a bonus, a Function that uses the PKCE flow to obtain an Access Token won't typically need a *Client Secret*, which is one less thing to manage and update over time.

**Secure storage of the Access Token**

Once we've obtained an *Access Token* and *Refresh Token*, we need to store them securely. In some cases they will expire, so the risk has an expiry date, but some are perpetual, and so there is an ongoing risk, but not any worse than creating a *Personal Access Token* and attaching that to a function.

If we use the OpenFaaS API itself to store functions in Kubernetes secrets, then there is a potential security risk, since another function in the same namespace could mount the secret and read it to use the API. As a workaround, you could deploy the function into its own dedicated namespace, preventing the secret from being mounted by other functions.

An alternative may be to add a secret to the function with a symmetric encryption key, and to use this to encrypt the value before storing it in a database, or in some other storage mechanism like NATS JetStream's KV store.

One other idea is to create a one-off ServiceAccount, RBAC permissions within the Kubernetes API for a specific named secret, then to grant the function access to store the secret in the Kubernetes API directly. This is the most complex option of them all, but could suit some power users.

**Access to the function**

When a function holds an *Access Token**, you now need to think about how to authenticate the function itself, otherwise the function could be invoked by any unauthorized user.

*Invoking from a cron schedule*

One option is to return no data to an invoker, but have the function perform its work silently, querying & updating any state found from the API, and sending off emails, Slack/Discord messages, etc

*Invoking from a headless service*

If this particular function needs to be invoked by another headless service, then you'll need to implement some form of authentication, such as a shared secret, RSA Public Key cryptography, or a JWT token.

*Invocation by a user directly*

Have a look at the built-in function authentication [IAM for OpenFaaS](https://docs.openfaas.com/openfaas-pro/iam/function-authentication/), which supports JWT tokens, and can be used to authenticate a user before they can invoke the function.

**Refreshing the token**

We didn't cover token refreshing in this example because it appears as if the Access Token may have an unlimited lifespan.

You can learn a bit more about refresh tokens in the spec: [IETF RFC6749](https://datatracker.ietf.org/doc/html/rfc6749#section-1.5) and on this page at [OAuth.com](https://www.oauth.com/oauth2-servers/access-tokens/refreshing-access-tokens/)

**Other considerations**

The URL in the code sample will need to be changed from "https://gumroad.com" to something else such as "https://api.xero.com".

Most APIs come terms and conditions and stringent rate-limits, so make sure you understand these before you start accessing them from your function.

Before the Twitter became X, the API used to be free of cost, but had a very restrictive rate limit. When I was developing a function, it needed to gather some data when it started up, which meant every time I built a new version of the code, it would eat away at the rate limit until there was nothing left.

## Conclusion

External data often requires some form of API token or password; some support long-lived Static Access Tokens, for others you will need to use OAuth. OAuth is a standard that allows users to grant access to their data to third-party applications, a Client Credentials or Server to Server flow is best suited for a function. But we showed that it is possible to obtain, store, and use an OAuth token obtained from a web flow in a function, for later invocation from a Cron schedule or event trigger.

We approached the function primarily as a background job that would run against our own data or account using a single token that was captured, however you could build a multi-user function in a very similar way. You would simply need to store an Access Token per user, rather than a single token. Encryption is paramount, and you should consider the full lifecycle of the token, from obtaining it, to storing it, to refreshing it, and finally to revoking it if the user no longer wants the function to access their data.

If you'd like to discuss this article further, we have a [weekly call for community](https://docs.openfaas.com/community/) or you can [get in touch via this page](https://openfaas.com/pricing/).

