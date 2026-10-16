---
title: "Protect your OpenFaaS functions with built-in OAuth - Part 2"
description: "Learn how to use identity claims, apply access rules, and add sign-out to your OpenFaaS functions."
date: 2026-10-16
author_staff_member: han
categories:
  - oauth
  - functions
  - security
dark_background: true
# image: "/images/2026-10-oauth-for-functions-part-2/background.png"
hide_header_image: true
---

In [part one](/blog/oauth-for-functions-part-1/) of this OAuth for functions series, we configured the OpenFaaS watchdog to add Google login to a function without changing its code. The watchdog handles sign-in and validates each session before forwarding requests.

Part one covered authentication (AuthN), which establishes who the visitor is. In this post, we will cover how to handle authorization (AuthZ) to decide what that visitor may access.

For example, you may want to:

- Limit an internal dashboard to members of your team.
- Give selected users access to a demo or prototype.
- Allow everyone on a project to view data, but only its owners to make changes.

After login, the watchdog copies selected identity claims from the provider’s verified ID token into a JWT it issues. Depending on the provider, these can include:

- `sub`: the visitor's user ID.
- `fed:email`: their email address.
- `fed:name`: their display name.
- `fed:groups`: the groups they belong to.

A function can read and use these claims to apply its own access rules.

```text
┌─────────┐  request + cookie   ┌────────────────────────────┐
│ Browser │────────────────────▶│          Watchdog          │
│         │                     │                            │
│         │                     │      Validate session      │
│         │◀────────────────────│                            │
└─────────┘      response       └────────────────────────────┘
                                        │            ▲
                                 cookie │            │ response
                                        ▼            │
                                ┌────────────────────────────┐
                                │      Function handler      │
                                │                            │
                                │    Read identity claims    │
                                │     Apply access rules     │
                                └────────────────────────────┘
```

In this post, we will build a Python function that reads session claims, uses an email allowlist to control access, and lets visitors sign out through the watchdog.

## Create a function

We'll start with a Python function that displays the visitor's session claims, then use those claims to control access to a web page.

Pull the [Python HTTP template](https://docs.openfaas.com/languages/python/) and create a function:

```bash
faas-cli template store pull python3-http
faas-cli new --lang python3-http authz-demo
```

We'll add two libraries:

- [PyJWT](https://pyjwt.readthedocs.io/en/stable/) is used to decode the session JWT into a Python dictionary.
- [Jinja2](https://jinja.palletsprojects.com/) renders HTML templates with data supplied by the handler.

Add both packages to `authz-demo/requirements.txt`. They will be installed when the function image is built:

```text
Jinja2==3.1.6
PyJWT==2.15.1
```

## Enable OAuth authentication for the function

We'll use Google as the identity provider, but other OpenID Connect providers work too. Register a new OAuth client with the `Web application` type, or reuse the app from part one. See [Create an OAuth app](/blog/oauth-for-functions-part-1/#create-an-oauth-app) for the detailed steps.

Make sure to set the function's callback URL as an authorized redirect URI, for example:

```text
https://gateway.example.com/function/authz-demo/auth/callback
```

Note the app's client ID and save its client secret in a file called `client-secret-value`. Create an OpenFaaS secret from the file:

```bash
faas-cli secret create authz-demo-google-client-secret \
  --from-file=./client-secret-value
```

Create a signing key used by the watchdog to issue signed JWTs:

```bash
faas-cli secret generate | faas-cli secret create authz-demo-signing-key
```

Update the function's `stack.yaml` entry to configure OAuth:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: https://gateway.example.com
functions:
  authz-demo:
    lang: python3-http
    handler: ./authz-demo
    image: ${REGISTRY:-ttl.sh}/${OWNER:-openfaas-examples}/authz-demo:${TAG:-latest}
    environment:
      oauth_enabled: "true"
      oauth_base_url: https://gateway.example.com/function/authz-demo
      oauth_client_id: 123456789012-abcdefghijklmnopqrstuvwxyz012345.apps.googleusercontent.com
      oauth_issuer_url: https://accounts.google.com
      oauth_scopes: openid email profile
      oauth_signing_key: authz-demo-signing-key
      oauth_client_secret: authz-demo-google-client-secret
    secrets:
      - authz-demo-signing-key
      - authz-demo-google-client-secret
```

The key OAuth settings are:

- `oauth_enabled` turns on browser login and session validation.
- `oauth_base_url` is the function's public URL.
- `oauth_issuer_url` identifies the OIDC provider.
- `oauth_scopes` requests `openid` for an ID token, `email` for the visitor's email address, and `profile` for details such as their name. Request all three to get the identity claims used in this example.

Make sure to configure and mount both the OAuth client secret and the JWT signing key.

See [part one](/blog/oauth-for-functions-part-1/#enable-oauth-authentication-for-the-function) for the full OAuth configuration walkthrough.

## Read the session claims

After a successful login, the watchdog creates its own signed JWT and stores it in an HttpOnly session cookie. The JWT includes selected identity claims from the provider’s verified ID token, but never the original ID token itself. The function handler can read the cookie and parse the JWT to use these claims.

We'll start with a simple handler that returns the parsed session claims for inspection:

```python
import json
import os
from http.cookies import SimpleCookie

import jwt


def handle(event, context):
    # Read the watchdog's session cookie (of_session by default).
    cookies = SimpleCookie(event.headers.get("Cookie", ""))
    session = cookies[os.getenv("oauth_cookie_name", "of_session")]

    # Decode the claims without verifying the signature again:
    # the watchdog already verified it before forwarding the request.
    claims = jwt.decode(session.value, options={"verify_signature": False})

    # Display the decoded claims as formatted JSON.
    return {
        "statusCode": 200,
        "body": json.dumps(claims, indent=2),
        "headers": {
            "Content-Type": "application/json",
            "Cache-Control": "private, no-store",
        },
    }
```

The watchdog validates the cookie JWT before forwarding the request, so the handler can safely decode its claims without validating the JWT. The default cookie name used by the watchdog is `of_session`.

Build and deploy the function:

```bash
faas-cli up --tag=digest
```

Open the function URL in a browser and sign in. You should see a response like this, with your own identity:

```json
{
  "iss": "https://gateway.example.com/function/authz-demo",
  "sub": "fed:123456789012345678901",
  "aud": ["https://gateway.example.com/function/authz-demo"],
  "exp": 1800003600,
  "iat": 1800000000,
  "typ": "session",
  "fed:iss": "https://accounts.google.com",
  "fed:email": "alice@example.com",
  "fed:email_verified": true,
  "fed:name": "Alice"
}
```

The `fed:` prefix marks federated claims, identity information supplied by the configured provider. It distinguishes these from the watchdog's own session claims. For example, `fed:iss` identifies the original identity provider.

| Claim | Meaning |
| --- | --- |
| `fed:iss` | The identity provider's issuer URL. This depends on the configured provider. For Google, it is `https://accounts.google.com`. |
| `fed:name` | The user's display name. |
| `fed:email` | The user's email address. |

See the [session cookie documentation](https://docs.openfaas.com/reference/function-oauth/#session-cookie) for a full overview of the available claims.

## Restrict access to the function

Signing in proves who the visitor is. If you are a Google Workspace user, you can restrict sign-in to members of your organisation, which may be enough. But if you are using a different auth provider or want to restrict access to a subset of users, you can implement custom authorization logic in the function handler.

In this section we'll update our function and use the claims to implement an access rule. The handler will check the visitor's email against a list of allowed_emails. Allowed visitors will see an identity page, other signed-in visitors will see an access-denied page.

Start by creating the folder for the HTML templates:

```bash
mkdir -p authz-demo/templates
```

Add `authz-demo/templates/index.html`. This is the main page that displays the visitor's name, email, user ID, and provider.

{% raw %}
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Your identity</title>
  </head>
  <body>
    <h1>Your identity</h1>
    {% if claims.get('fed:name') %}
    <p>Welcome, {{ claims['fed:name'] }}.</p>
    {% endif %}
    <dl>
      <dt>Email</dt><dd>{{ claims['fed:email'] }}</dd>
      <dt>User ID</dt><dd>{{ claims['sub'] }}</dd>
      <dt>Provider</dt><dd>{{ claims['fed:iss'] }}</dd>
    </dl>
  </body>
</html>
```
{% endraw %}

Also create a template at `authz-demo/templates/unauthorized.html`. This page will be displayed to users outside the allowlist.

{% raw %}
```html
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Access denied</title>
  </head>
  <body>
    <h1>Access denied</h1>
    <p>Your account is not allowed to view this page.</p>
  </body>
</html>
```
{% endraw %}

Update `authz-demo/handler.py` to check the visitor's email against `allowed_emails` and render the appropriate page:

```python
import os
from http.cookies import CookieError, SimpleCookie
from pathlib import Path

import jwt
from jinja2 import Environment, FileSystemLoader, select_autoescape

FUNCTION_DIR = Path(__file__).resolve().parent

# Load templates with HTML escaping enabled.
templates = Environment(
    loader=FileSystemLoader(str(FUNCTION_DIR / "templates")),
    autoescape=select_autoescape(["html"]),
)

# Read the comma-separated allowlist, ignoring whitespace and letter case.
allowed_emails = {
    email.strip().casefold()
    for email in os.getenv("allowed_emails", "").split(",")
    if email.strip()
}

session_cookie_name = os.getenv("oauth_cookie_name", "of_session")


def read_session(cookie_header):
    try:
        # Extract the watchdog's session JWT from the request cookie.
        cookies = SimpleCookie(cookie_header or "")
        cookie = cookies.get(session_cookie_name)

        if cookie is None:
            return None

        # Decode the claims, the watchdog has already verified the signature.
        return jwt.decode(cookie.value, options={"verify_signature": False})
    except (CookieError, jwt.InvalidTokenError):
        return None


def handle(event, context):
    # Read the visitor's email, using an empty string if it is missing.
    session_claims = read_session(event.headers.get("Cookie")) or {}
    email = session_claims.get("fed:email", "")

    # Show the identity page only when the email is in the allowlist.
    authorized = email.strip().casefold() in allowed_emails
    template = templates.get_template(
        "index.html" if authorized else "unauthorized.html"
    )

    return {
        "statusCode": 200 if authorized else 403,
        "body": template.render(claims=session_claims),
        "headers": {
            "Content-Type": "text/html; charset=utf-8",
            # Prevent caching pages that contain a visitor's identity.
            "Cache-Control": "private, no-store",
            "Vary": "Cookie",
        },
    }
```

The handler compares `fed:email` with the comma-separated list read from the `allowed_emails` environment variable. A match returns `index.html` with HTTP `200`, an unlisted email returns `unauthorized.html` with HTTP `403`.

Add `allowed_emails` to the function's `environment` section in `stack.yaml`, replacing the example addresses with the users you want to allow:

```diff
       oauth_signing_key: authz-demo-signing-key
       oauth_client_secret: authz-demo-google-client-secret
+      allowed_emails: "alice@example.com,bob@example.com"
     secrets:
       - authz-demo-signing-key
       - authz-demo-google-client-secret
```

For permissions that need to survive an email address change, you could use the stable `sub` claim together with `fed:iss` instead.

## Add logout to the function

Signing out requires clearing the session cookie. Because it is HttpOnly, page JavaScript cannot remove it.

The watchdog provides a `/auth/logout` endpoint that accepts `POST` requests, clears the session cookie, and redirects the visitor to the login page. The function only needs a form that submits to this endpoint.

Add this form inside the `<body>` of both the HTML templates, so visitors can sign out from either page:

{% raw %}
```html
<form method="post" action="{{ logout_url }}">
  <button type="submit">Sign out</button>
</form>
```
{% endraw %}

Update `authz-demo/handler.py` in two places: define the logout URL, then pass it to the template in the handler's response:

```diff
@@
 session_cookie_name = os.getenv("oauth_cookie_name", "of_session")
+base_url = os.environ["oauth_base_url"]
+logout_url = f"{base_url.rstrip('/')}/auth/logout"
@@
     return {
         "statusCode": 200 if authorized else 403,
-        "body": template.render(claims=session_claims),
+        "body": template.render(
+            claims=session_claims,
+            logout_url=logout_url,
+        ),
         "headers": {
```

Clicking *Sign out* submits the form to the watchdog. The next visit to the function requires a new login. This ends the function's session.

## Deploy and try it out

Build, push, and deploy the function.

```bash
faas-cli up --tag=digest
```

Open `https://gateway.example.com/function/authz-demo` in your browser. An account listed in `allowed_emails` sees its own name, email, user ID, and provider.

![Identity page showing the signed-in visitor's name, email, provider, and a redacted user ID, with a Sign out button](/images/2026-10-oauth-for-functions-part-2/authz-demo-identity.png)

An account outside the list gets the access-denied page.

![Access-denied page showing that the account is not allowed to view the page, with a Sign out button](/images/2026-10-oauth-for-functions-part-2/authz-demo-access-denied.png)

Clicking *Sign out* returns you to the login page. Visiting the function again requires signing in.

## Conclusion

We built a Python function that displays the visitor's identity, applies an email allowlist, and provides sign-out. The watchdog handles the login flow and validates sessions, while the function controls access to its content.

We created a simple example that compares an email address against an allowlist, but claims can also support more advanced use cases where you need to decide both what a visitor can do and what content to show them. For example:

- Use `sub` together with `fed:iss` to look up a user's account in a database, then query their saved reports, orders, or project data.
- Use `fed:groups`, when supplied by your provider, to give some users read-only access and let others make changes.
- Record the user's identity alongside actions, such as approving a request, to keep an audit trail.

See the [OAuth documentation](https://docs.openfaas.com/reference/function-oauth/) for the available claims and provider configuration options.
