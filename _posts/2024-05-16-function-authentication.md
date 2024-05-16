---
title: Introducing built-in authentication for OpenFaaS Functions
description: 
date: 2024-05-16
categories:
- kubernetes
- faas
- functions
- authentication
- authorization
dark_background: true
image: "/images/2024-05-function-auth/background.png"
author_staff_member: alex
hide_header_image: true
---

A long standing request from OpenFaaS users has been to add built-in authentication for functions. This would allow you to secure your function endpoints without having to write any additional code.

Once a function deployed via the OpenFaaS gateway, it will become available on the gateway via the path: `/function/NAME` and `/async-function/NAME`. This means that anyone with access to the gateway can invoke the function, and the function's handler is responsible for any authentication or authorization.

In this blog post we'll show you how to use a pre-release version of [IAM for OpenFaaS](https://docs.openfaas.com/openfaas-pro/iam/overview/) to create a Policy that restricts access to a function only to authorized users with JSON Web Token (JWT) authentication.

You'll need to have [OpenFaaS for Enterprises](https://docs.openfaas.com/openfaas-pro/introduction/) pre-installed and configured to integrate with your existing Identify Provider (IdP) such as Okta, Keycloak, or Google.

We will perform the initial one-time setup process:

* Create a function to secure, and understand how the watchdog performs the authentication
* Create a new OAuth/OIDC client for use with OpenFaaS
* Create a Policy to restrict access to a function
* Create a Role to bind a Policy to a given OAuth Client or user

Then we'll obtain a token and use it to invoke the function:

* Obtain an OAuth2 token from your IdP using the client credentials flow (other flows are supported for human users)
* Perform a token exchange for a Function Token
* Invoke the function with the Function Token


![Conceptual diagram showing Function Authentication flow](/images/2024-05-function-auth/conceptual.png)
> Conceptual diagram showing Function Authentication flow from IdP to function invocation.

*What if I'm running another version of OpenFaaS?*

Feel free to [reach out to us](https://openfaas.com/pricing) if you'd like to try out OpenFaaS for Enterprises.

Alternatively, you can still [write custom code in your function's handler](https://docs.openfaas.com/reference/authentication/) to validate or authenticate requests using a mechanism like HMAC or an API token mounted via a secret.

## Create a new function to secure

When secured, a Function Token has to be presented via the Authorization header to invoke a function. This is a short-lived JWT token that is obtained through a token exchange process.

The token is validated by the OpenFaaS watchdog, and the initial release will only cover the newer of-watchdog, with support for the classic watchdog coming in a future release.

We'll deploy a function from the OpenFaaS store called `printer` which pretty prints incoming HTTP requests to the logs of the function.

```yaml
provider:
  name: openfaas

  printer:
    skip_build: true
    image: ghcr.io/openfaas/printer:latest
```

Add the following environment variable:

```yaml
    environment:
      jwt_auth: "true"
```

OpenFaaS injects two environment variables into the function:

* `OPENFAAS_NAME` - the name of the function i.e. `printer`
* `OPENFAAS_NAMESPACE` - the namespace of the function i.e. `openfaas-fn`

For each request to the function, the watchdog combines the OPENFAAS_NAME and OPENFAAS_NAMESPACE, then evaluates the value against the permissions encoded in the OpenFaaS Function Token.

## Create a new OAuth/OIDC Client

Setup a new OAuth or OIDC application or client to be used by OpenFaaS in your IdP. Since the token will be obtained by a machine, you'll need to use the client credentials flow.

Sometimes this will mean checking additional settings like "Client credentials". In Keycloak, check the "Client authentication" and "Service accounts roles" checkboxes on the Create client page.

Save the client_secret as `./client-secret.txt`

Take a note of client_id, for the following steps.

Create a JWT Issuer and apply it to your cluster:

```yaml
---
apiVersion: iam.openfaas.com/v1
kind: JwtIssuer
metadata:
  name: keycloak.example.com
  namespace: openfaas
spec:
  iss: https://keycloak.example.com/realms/openfaas
  aud:
    - openfaas
  tokenExpiry: 1h
```

## Create or update a Policy for a function

The following policy will allow the `env` function in the `dev` namespace to be invoked, and any function in the `openfaas-fn` namespace.

```yaml
apiVersion: iam.openfaas.com/v1
kind: Policy
metadata:
  name: invoke-policy
  namespace: openfaas
spec:
  statement:
  - sid: 1-invoke-policy
    action:
      - "Function:Invoke"
    effect: Allow
    resource:
      - "openfaas-fn:*"
      - "dev:env"
```

Save the file as invoke-policy.yaml and apply it to your cluster with `kubectl apply -f invoke-policy.yaml`.

## Create a Role

You'll need to create a Role to map the Policy to a user or group. In this example, we'll create a role called `invoke-role`.

For a machine account, it's recommended that you created a dedicated OAuth client application with its own client_id. Then make the Role match on the issuer and on the client_id field.

```yaml
apiVersion: iam.openfaas.com/v1
kind: Role
metadata:
  name: invoke-role
  namespace: openfaas
spec:
  policy:
  - invoke-policy
  condition:
    StringEqual:
      jwt:iss: ["https://keycloak.example.com/realms/openfaas"]
      jwt:client_id: ["openfaas"]
```

Note: if you add client_credentials to an existing OAuth/OIDC application, you will need additional conditions to match on the specific subject, user, email, or group, etc, otherwise anyone with a valid account for the client_id will be able to obtain a token.

## Obtain an OAuth2 token from your identify provider

Form a curl statement:

```bash
export IDP_TOKEN_URL=https://keycloak.example/realms/openfaas/protocol/openid-connect/token
export CLIENT_ID="openfaas"
export CLIENT_SECRET="$(cat ./client-secret.txt)"

curl -S -L -X POST "${IDP_TOKEN_URL}" \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode "client_id=${CLIENT_ID}" \
    --data-urlencode "client_secret=${CLIENT_SECRET}" \
    --data-urlencode 'scope=email' \
    --data-urlencode 'grant_type=client_credentials'
```

Run the above, to obtain a token.

It will look something like this:

```json
{"access_token":"REDACTED","expires_in":300,"refresh_expires_in":0,"token_type":"Bearer","not-before-policy":0,"scope":"profile email"}
```

Save the result as token.txt.

## Perform a token exchange for an Function Token

There are two types of token exchange supported in OpenFaaS for Enterprises:

1. Exchange an OAuth2 token for an OpenFaaS API Token
2. Exchange an OAuth2 token for an OpenFaaS Function Token

The reason there are separate tokens for different uses, is so that a token with API access isn't used to invoke function, where it could be used to escalate privileges.

Now you have an OAuth2 token from your IdP, we'll exchange it for a Function Token.

Update the `IDP_TOKEN_URL` to your OpenFaaS gateway URL, with the suffix `/oauth/token`.
Make sure that token.txt file exists from the previous step. If the IdP token has expired, you will need to repeat the previous step.

```bash
export IDP_TOKEN_URL="https://gateway.example.com/oauth/token" 
export TOKEN="$(cat token.txt)"

curl -S -L -X POST "${IDP_TOKEN_URL}" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode "subject_token=${TOKEN}" \
--data-urlencode "subject_token_type=urn:ietf:params:oauth:token-type:id_token" \
--data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' \
--data-urlencode 'scope=function'
```

The resulting token will look like this:

```json
{"access_token":"REDACTED","expires_in":300,"token_type":"Bearer","scope":"function"}
```

Save the text from the "access_token" field as function-token.txt.

It will look something like this:

```json
{
  "iss": "https://openfaas.example.com",
  "sub": "fed:a9e0e67a-5758-4373-a4ba-23957fa66e6b",
  "aud": [
    "https://openfaas.example.com"
  ],
  "exp": 1715892121,
  "iat": 1715848921,
  "function": {
    "permissions": [
      "openfaas-fn:*",
      "dev:env"
    ]
  }
}
```

As you can see, the union of permissions from the Policy are encoded into the Function Token.

If you wish to restrict the token so that it can only be used to invoke a single function, or a subset of functions, you can request a specific audience when you exchange the token.

```bash
curl -S -L -X POST "${IDP_TOKEN_URL}" \
--header 'Content-Type: application/x-www-form-urlencoded' \
--data-urlencode "subject_token=${TOKEN}" \
--data-urlencode "subject_token_type=urn:ietf:params:oauth:token-type:id_token" \
--data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:token-exchange' \
--data-urlencode 'scope=function' \
--data-urlencode 'audience=openfaas-fn:env' \
--data-urlencode 'audience=openfaas-fn:figlet'
```

Here's how the token looks, with the audience also specified.

```json
{
  "iss": "https://openfaas.example.com",
  "sub": "fed:a9e0e67a-5758-4373-a4ba-23957fa66e6b",
  "aud": [
    "https://openfaas.example.com"
  ],
  "exp": 1715892177,
  "iat": 1715848977,
  "function": {
    "permissions": [
      "openfaas-fn:*",
      "dev:env"
    ],
    "audience": [
      "openfaas-fn:env",
      "openfaas-fn:figlet"
    ]
  }
}
```

## Invoke the function with the Function Token

You now have a token that can be used to invoke a function. You can use it with curl or any HTTP client.

First of all, check the function cannot be invoked without a token:

```bash
curl https://gateway.example.com/function/env
```

Now invoke the function with the token:

```bash
curl -i https://gateway.example.com/function/env \
    -H "Authorization: Bearer $(cat function-token.txt)"
```

You should see a successful response from the function.

## Conclusion

If you already have IAM for OpenFaaS installed and configured for Single-Sign On, then there isn't a lot of additional work to do to secure your functions with Function Tokens. In most cases, you'll just set an additional environment variable on your protected functions and create a Policy and Role for any user that needs to invoke them.

### Q&A

Q: Are Function Tokens production-ready? When will I be able to use them in production?

A: Function Tokens, once released will be suitable for use in production. They are an extension of the already released IAM for OpenFaaS features and use the same underlying technology for the new type of Function Token. The work is currently pre-release and available for testing, once it's released you will have access to it via the Helm chart.

Q: I use another version of OpenFaaS i.e. faasd, what can I do to authenticate functions?

A: OpenFaaS functions serve HTTP, therefore [you can use any standard authentication mechanism](https://docs.openfaas.com/reference/authentication/) such as Basic Auth, HMAC, API tokens, or OAuth2. We do not recommend using an API gateway or reverse proxy to implement authentication, as functions can be invoked directly at the Pod level, or via the OpenFaaS gateway's internal address, bypassing the proxy.

Q: Can I bypass authentication by invoking a Function's Pod directly by its ClusterIP?

A: Function Authentication is implemented in the OpenFaaS watchdog, which means that you cannot bypass it by invoking the function directly. The watchdog will always intercept the request and enforce the policy.

Q: How long do Function Tokens last?

A: This is configurable at the JWT Issuer level using the `tokenExpiry` field of the `JwtIssuer`.

Q: Can a function access the API if I send it a normal OpenFaaS API Access Token?

A: You can exchange your OpenFaaS API Access Token for a Function Invoke token, but you cannot use the API Access Token to invoke a function directly.

Q: Can I invoke authenticated functions from another microservice or backend application?

A: Yes, you can use the OAuth2 client credentials flow to obtain a token for a machine account, and then exchange it for a Function Token. If your application runs within Kubernetes, then you can use the Kubernetes service account to obtain a token. See also: [How to authenticate to the OpenFaaS API using Kubernetes JWT tokens](https://www.openfaas.com/blog/kubernetes-tokens-openfaas-api/)

Q: Can a function invoke another function which has Function Authentication enabled?

A: In order to invoke an Function with Authentication enabled, you will need to obtain a token from an IdP, then exchange it for a Function Token. This means that a function can invoke another function, but only if it has the necessary permissions.

Q: Can the queue-worker invoke functions using Function Tokens?

A: The queue-worker can invoke functions using Function Tokens, so long as you pass in the token as a header.

Q: Does the queue-worker's 'X-Callback-Url' work with Function Authentication?

A: The queue-worker can send the result of an invocation to another function by passing in a header of `X-Callback-Url`. This will continue to work for functions without authentication, but is out of scope for the initial version when Function Authentication is used.

Q: Are the cron-connector, kafka-connector, and other connectors supported?

A: These connectors will require additional work to support Function Tokens, and will be supported in a future release. Let us know if you need this feature.

Q: Can I invoke functions via the OpenFaaS Dashboard with Function Tokens?

A: A future version of the OpenFaaS Dashboard will be able to exchange your OpenFaaS Access Token for a Function Token, and then use it to invoke functions. For the initial release, you'll need to use curl or another HTTP client.

Q: Can the CLI invoke functions with Function Tokens?

A: The initial release includes changes to the OpenFaaS CLI to obtain Function Tokens on your behalf to invoke functions via `faas-cli invoke`.

Q: If I deploy a web page as a function, can I use Function Tokens through a web-browser?

A: If you need to secure a web page hosted on OpenFaaS, to be accessed by a human user, then you should use an OAuth2 middleware or Basic Authentication. 

Q: Can I use Function Tokens with the classic watchdog?

A: The initial release will only support the of-watchdog, with support for the classic watchdog coming in a future release.

How do I try it out?

This tutorial is based upon a pre-release version of OpenFaaS for Enterprises, and the final implementation may differ. The of-watchdog will be supported first, and you will need to update your templates to use the latest available version to enable the feature.

Please reach out to us if you'd like a demo, or to try it out in your own environment.

