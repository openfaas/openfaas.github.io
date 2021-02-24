---
title: "Enable Single Sign-on (SSO) for OpenFaaS with Okta and OpenID Connect"
description: "Bring enterprise authentication and Single Sign-on (SSO) to OpenFaaS with Okta and OpenID Connect"
date: 2020-09-16
image: /images/2020-09-oidc-okta/concentrate.jpg
categories:
  - kubernetes
  - oauth2
  - security
  - sso
  - oidc
author_staff_member: alex
dark_background: true

---

Bring enterprise authentication and Single Sign-on (SSO) to OpenFaaS with Okta and OpenID Connect

## Enterprise authentication 

OpenID Connect is a common standard that builds upon OAuth2 to enable authentication to services and applications. Solutions like [Okta](https://www.okta.com) can be used to enable Single Sign-On across a number of third-party and in-house applications. This reduces the burden on IT administrators - fewer requests to reset passwords, fewer employees will share credentials and policy can enforced in one place.

In this tutorial, I'll show you how to setup Okta and [OpenFaaS with the OIDC / OAuth2 authentication module](https://docs.openfaas.com/reference/authentication/). The OIDC auth module for OpenFaaS is a commercial add-on included in our [OpenFaaS PRO Subscription](https://www.openfaas.com/support).

If you don't have an active [OpenFaaS PRO Subscription](https://www.openfaas.com/support), then you will need to apply for a trial key here: [Apply for a 14-day trial](https://forms.gle/mFmwtoez1obZzm286).

## Tutorial overview

* Create a developer account with Okta
* Register a domain or DNS sub-zone
* Create an App in Okta
* Collect OIDC URLS, IDs and credentials
* Setup OpenFaaS with TLS, Ingress and the authentication module
* Configure your DNS
* Test out logging into OpenFaaS with Okta

### Create a developer account with Okta

Head over to [developer.okta.com](https://developer.okta.com) and create a developer account.

### Register a domain or DNS sub-zone

You will need to register a domain, or to setup a sub-zone if you already own a domain.

I'll be using the zone `.oauth.openfaas.pro` and then adding two entries later on in a later step.

[Google Domains](https://domains.google.com) provide a cost-effective option.

### Create an App in Okta

We will have two URLs for OpenFaaS:

* `gw.oauth.openfaas.pro` - the OpenFaaS gateway
* `auth.oauth.openfaas.pro` - the OpenFaaS OIDC connector

You will note that we are using the second domain here: `auth.oauth.openfaas.pro`

A valid redirect domain of `http://127.0.0.1:31111/oauth/callback` is also required if you plan to use the `faas-cli` to authenticate to OpenFaaS.

![Create the app](/images/2020-09-oidc-okta/create-app.png)

### Collect OIDC URLs, IDs and credentials

Collect your various URLs, IDs and credentials

Get the `client_id` and `secret` values:

![Get the app secrets](/images/2020-09-oidc-okta/client-secrets.png)

I was assigned a random domain of `dev-624219`, the corresponding URLs will be `dev-624219.okta.com`.

```bash
export yourOktaDomain=dev-624219.okta.com
export authServerId=default

curl -s https://${yourOktaDomain}/oauth2/${authServerId}/.well-known/openid-configuration
```

If you pipe the result to `jq`, or save it as JSON and format it, you'll see the important URLs that OpenFaaS needs:

```
{
  "issuer": "https://dev-624219.okta.com/oauth2/default",
  "authorization_endpoint": "https://dev-624219.okta.com/oauth2/default/v1/authorize",
  "token_endpoint": "https://dev-624219.okta.com/oauth2/default/v1/token",
  "userinfo_endpoint": "https://dev-624219.okta.com/oauth2/default/v1/userinfo",
  "registration_endpoint": "https://dev-624219.okta.com/oauth2/v1/clients",
  "jwks_uri": "https://dev-624219.okta.com/oauth2/default/v1/keys"
}
```

You should set the `cookieDomain` to the domain or DNS-zone that was created. 

Fill out the following and save it as `install.sh`, but do not run it yet.

```bash
export PROVIDER=""              # Set this to "azure" if using Azure AD.
export LICENSE=""
export OAUTH_CLIENT_SECRET=""
export OAUTH_CLIENT_ID=""
export ROOT_DOMAIN="oauth.openfaas.pro"
export yourOktaDomain="dev-624219.okta.com"

arkade install openfaas \
  --set oauth2Plugin.enabled=true \
  --set oauth2Plugin.provider=$PROVIDER \
  --set oauth2Plugin.license=$LICENSE \
  --set oauth2Plugin.insecureTLS=false \
  --set oauth2Plugin.scopes="openid profile email" \
  --set oauth2Plugin.jwksURL=https://$yourOktaDomain/oauth2/default/v1/keys \
  --set oauth2Plugin.tokenURL=https://$yourOktaDomain/oauth2/default/v1/token \
  --set oauth2Plugin.audience=https://gw.$ROOT_DOMAIN \
  --set oauth2Plugin.authorizeURL=https://$yourOktaDomain/oauth2/default/v1/authorize \
  --set oauth2Plugin.welcomePageURL=https://gw.$ROOT_DOMAIN \
  --set oauth2Plugin.cookieDomain=.$ROOT_DOMAIN \
  --set oauth2Plugin.baseHost=https://auth.$ROOT_DOMAIN \
  --set oauth2Plugin.clientSecret=$OAUTH_CLIENT_SECRET \
  --set oauth2Plugin.clientID=$OAUTH_CLIENT_ID
```

If you're using a GitOps tool or helm to install OpenFaaS, then the above options can be written into your `values.yaml` file instead. The `clientSecret` is a confidential value, so don't commit this to a public repo.

For instance:

```yaml
...
oauth2Plugin:
  enabled: true
  jwksURL: https://dev-624219.okta.com/oauth2/default/v1/keys
...
```

### Setup OpenFaaS with TLS, Ingress and the auth plugin

Before running the `install.sh` script, you'll either need a public Kubernetes cluster, or a private/on-premises cluster using [inlets PRO](https://inlets.dev) to provide a LoadBalancer with a public IP.

Install an IngressController if you don't already have one:

```bash
arkade install ingress-nginx
```

Install cert-manager if you don't already have it:

```bash
arkade install cert-manager
```

Install OpenFaaS using `install.sh`. Note that if you have got a setting wrong, you can edit install.sh and run it again at any time.

Create a TLS and Ingress record for the gateway:

```bash
arkade install openfaas-ingress \
 --email alex@oauth.openfaas.pro \
 --domain gw.oauth.openfaas.pro
```

We need one more Ingress record for the OIDC provider, but arkade can't do that for us yet.

Export the gateway's YAML file, edit the domain and name and apply it again:

```bash
kubectl get -n openfaas ingress/openfaas-gateway -o yaml \
  --export > oauth2-plugin.yaml
```

Edit `oauth2-plugin.yaml`

Change the name from `openfaas-gateway` to `oauth2-plugin`, domain to `auth.oauth.openfaas.pro`, the host to `oidc`, and the secretName to `oauth2-plugin`.

Alternatively use `sed`:

```bash
sed -ie s/openfaas-gateway/oauth2-plugin/g oauth2-plugin.yaml
sed -ie s/gw./auth./g oauth2-plugin.yaml
sed -ie s/gateway/oauth2-plugin/g oauth2-plugin.yaml
```

Apply the changed file, forcing the namespace to `openfaas`:

```bash
kubectl apply -f oauth2-plugin -n openfaas
```

### Configure your DNS

Your TLS certs cannot be issued until you create some DNS records.

Run the following:

```bash
kubectl get svc ingress-nginx-controller
```

If you have an IP address showing under `EXTERNAL-IP`, then create two A records for the two subdomains. If you see a DNS record, as per AWS EKS, then create a CNAME for them instead.

* `gw.oauth.openfaas.pro`
* `auth.oauth.openfaas.pro`

Check that the DNS entries have propagated using `ping -c 1 gw.oauth.openfaas.pro`

In a few moments you should see both certificates created:

```bash
kubectl get cert -n openfaas
```

If you think there's a problem, run `kubectl describe -n openfaas order`

### Test out logging into OpenFaaS with Okta

We have now configured a Kubernetes cluster with an IngressController, cert-manager and OpenFaaS with the OIDC auth add-on. It's time to try logging in.

Head over to the gateway's UI in a browser:

```
https://gw.oauth.openfaas.pro
```

> Note: If you're seeing a certificate error and the "Kubernetes Ingress Controller Fake Certificate" CA, then you need to go back to the previous step and double-check everything. Even if the DNS configuration is correct, it can take a few minutes for the certificate to be issued.

You should be redirected to your Okta developer domain, where you will be asked to log in with the user in Okta.

![Log in](/images/2020-09-oidc-okta/login.png)

View the portal:

![Portal](/images/2020-09-oidc-okta/portal.png)

You can also log into OpenFaaS using the CLI for use on your laptop using the `faas-cli auth` command to obtain and store a token.

```bash
export CLIENT_ID="0oazbx89opTdXdOql4x6"
faas-cli auth \
  --client-id $CLIENT_ID \
  --auth-url https://dev-624219.okta.com/oauth2/default/v1/authorize \
  --gateway https://gw.oauth.openfaas.pro \
  --grant implicit-id
```

> Note: some OIDC providers like Azure Active Directory require "localhost" instead of 127.0.0.1 to be given for this flow. You can provide `--redirect-host=localhost` when using Azure.

```bash
Starting local token server on port 31111

credentials saved for https://gw.oauth.openfaas.pro

Example usage:
  # Use an explicit token
  faas-cli list --gateway "https://gw.oauth.openfaas.pro" --token "REDACTED"

  # Use the saved token
  faas-cli list --gateway "https://gw.oauth.openfaas.pro"
```

Then you can use `faas-cli` from your machine using the token:

```bash
faas-cli list --gateway "https://gw.oauth.openfaas.pro"
Function                      	Invocations    	Replicas
nodeinfo                      	0              	1    
```

When you need to use a token from CI, we provide instructions for the `clients_credentials` flow in the OpenFaaS documentation (referenced in the summary).

Now you can invite your team and co-workers to collaborate with you and build serverless functions.

Use the User panel to add new users to Okta, or if they are already in your Okta account, setup a new OpenFaaS Group and add them to that.

![Adding a new user](/images/2020-09-oidc-okta/add-user.png)

## Wrapping up

In a relatively short period of time, we've been able to authenticate to OpenFaaS using Okta and a single login. Any OIDC provider should work and I've tested the code with GitLab, Auth0 and GitLab so far. From here, it's easy to add other users to the OpenFaaS app, and to send them an invite over email to join.

### What about authorization?

Today the authorization piece is still limited. Any valid users who are in the correct group for the OpenFaaS App in Okta will be administrators in OpenFaaS. So whilst they won't have `kubectl` access, they will be able to perform CRUD operations on functions using `faas-cli`, the UI and the REST API.

OpenFaaS has multiple-namespace support, and adding authorization is within sights. Do you want to see authorization on a per namespace basis? Do you need it per function? Would read-only roles be a valuable addition?

Perhaps just adding OpenID Connect with Okta, Auth0, or GitLab to your corporate OpenFaaS deployment is enough, or maybe you need finer-grained authorization. I'd like to hear from you.

You can contact me at [alex@openfaas.com](mailto:alex@openfaas.com)

See also:

* [Multiple namespace support](https://docs.openfaas.com/reference/namespaces/)
* [Join the Slack community](https://slack.openfaas.io/)
* [Authentication documentation](https://docs.openfaas.com/reference/authentication/)
