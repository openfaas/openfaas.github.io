---
title: "How to authenticate to the OpenFaaS API using Kubernetes JWT tokens"
description: "Learn how to use Kubernetes Service Account Token Projection with the OpenFaaS API"
date: 2023-07-07
categories:
- authorization
- iam
- enterprise
- security
- connectors
- multi-tenancy
dark_background: true
author_staff_member: han
author_staff_member_editor: alex
image: "/images/2023-07-k8s-jwt-iam/background.png"
hide_header_image: true
---

Learn how to use Kubernetes Service Account Token Projection with the OpenFaaS API.

With the release of Identity and Policy Management (IAM) for OpenFaaS, you can now use Kubernetes Service Account Token Projection to authenticate with the OpenFaaS API.

The benefit of these tokens is that they do not need a human to be involved for authorization, so you can use them to automate OpenFaaS without needing to store a password or API key. This also makes it possible to deploy event connectors that can only work on certain namespaces, so it's ideal for running a managed service.

For a long time, Kubernetes has had a form of JSON Web Token (JWT) tokens, however the new generation of tokens are much more flexible, allowing a custom audience and a short expiry time of as low as 10 minutes.

Learn more: [Kubernetes docs: ServiceAccount token volume projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection)

At the time of writing, IAM for OpenFaaS is very new, so you can get an overview here before reading further: [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/).

You can follow along with the examples to get a conceptual idea of how everything works, or if you've already got a license, you can try it out yourself if you've enabled IAM.

## Integrate with the OpenFaaS API using tokens

IAM for OpenFaaS uses OpenID Connect (OIDC) and JSON Web Tokens (JWT) to perform a token exchange from your identity provider to a built-in OpenFaaS provider. That final token is an access token that will be used to authorize your requests to OpenFaaS REST API.

What kinds of things can you do with the API? Create functions through an automated pipeline, invoke them through your own proxy, find their logs, manage secrets and namespaces for customers, and more. We recently covered the API and multi-tenancy in a blog post: [Build a Multi-Tenant Functions Platform with OpenFaaS](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/).

To authenticate with the API your code will need to:

1. Obtain an `id_token` from your Identity Provider (IdP) or from Kubernetes using Service Account Token Projection.
2. Exchange that `id_token` from your IdP (or Kubernetes) for an OpenFaaS `access_token` using a custom endpoint on the gateway
3. Periodically renew the `access_token` using the above steps when it expires

The `id_token` can be exchanged for an OpenFaaS token by making an OAuth 2.0 Token Exchange request. We implemented a standard flow for this as described in [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693.html).

Here's a HTTP POST to `https://gateway.example.com/oauth/token`.

```
POST /oauth/token HTTP/1.1
Host: gateway.example.com
Content-Type: application/x-www-form-urlencoded

subject_token=your-id-tokent&
subject_token_type=urn:ietf:params:oauth:token-type:id_token&
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
```

The fields are encoded as `application/x-www-form-urlencoded`.

A successful response will look like this:

```
{
  "access_token": "eyJhbGciOiJFUzI1NiIsImtpZCI6IkFSeUhCdG9SdVhSekNFcVJfOU5Scl9IUFBfczM2dkhLZjlfWF9NanBhZDR4IiwidHlwIjoiSldUIn0.eyJhdWQiOiJodHRwczovL2d3LmV4aXQud2VsdGVraS5kZXYiLCJleHAiOjE2ODg0ODEzNzEsImZlZDppc3MiOiJodHRwczovL2t1YmVybmV0ZXMuZGVmYXVsdC5zdmMuY2x1c3Rlci5sb2NhbCIsImlhdCI6MTY4ODQ3NDE3MSwiaXNzIjoiaHR0cHM6Ly9ndy5leGl0LndlbHRla2kuZGV2Iiwia3ViZXJuZXRlcy5pbyI6eyJuYW1lc3BhY2UiOiJvcGVuZmFhcyIsInBvZCI6eyJuYW1lIjoibmdpbngiLCJ1aWQiOiI0MjQ0NGVmNy1iYmU3LTRlNjQtYWFlYi1kOWVmMWUyNjdlYmMifSwic2VydmljZWFjY291bnQiOnsibmFtZSI6ImRlZmF1bHQiLCJ1aWQiOiJmZjQ5NGFmNS1jMDQwLTRiMzAtYjk0Mi1iYjNmOTdmYzE1MzkifX0sIm5iZiI6MTY4ODQ3MzU3NiwicG9saWN5IjpbImZuLXJ3Il0sInN1YiI6ImZlZDpzeXN0ZW06c2VydmljZWFjY291bnQ6b3BlbmZhYXM6ZGVmYXVsdCJ9.MHOjp3Ry-pURgkO3tB0jJzCeA9DyEl3DPxqAtijw6VY4Ts9XgffOwjXefvVsoFT8beIWFmKSHYpDoygCqkHG4Q",
  "issued_token_type": "urn:ietf:params:oauth:token-type:id_token",
  "token_type": "Bearer",
  "expires_in": 7200
}
```

- `access_token`, the OpenFaaS ID token
- `issued_token_type` will always be `urn:ietf:params:oauth:token-type:id_token`. Indicating the token is an ID Token.
- `token_type` will always be `Bearer`. Indicating the token can be presented as a bearer token to the OpenFaaS gateway API.
- `expires_in`, the validity lifetime, in seconds, of the token.

Try the request with curl and get the `access_token`:

```bash
export OPENFAAS_URL=https://gateway.example.com
export ID_TOKEN="" # Id token obtained from a trusted OIDC provider.

curl -s -X POST \
  "$OPENFAAS_URL/oauth/token?grant_type=urn:ietf:params:oauth:grant-type:token-exchange&subject_token=$ID_TOKEN&subject_token_type=urn:ietf:params:oauth:token-type:id_token" | jq -r .access_token
```

The `access_token` returned by the code exchange request must be sent in the `Authorzation` header when making requests to protected resources in the OpendFaaS REST API.

Here's an example of how to list namespaces:

```bash
export OPENFAAS_URL=https://gateway.example.com
export ACCESS_TOKEN="" # Access token obtained from the code exchange request.

curl -s $OPENFAAS_URL/system/namespaces \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

We have thorough documentation on the REST API endpoints, a Go SDK and an OpenAPI v3 specification in the docs: [Docs: OpenFaaS REST API](https://docs.openfaas.com/reference/rest-api/)

### Use a projected service account token to access the OpenFaaS REST API

If your code is running in a Kubernetes cluster, then you can get the initial `id_token` from a service account. You'll need to create a dedicated Service Account and then bind it to the Pods that need to access the OpenFaaS API.


Before tokens issued by the Kubernetes API can be exchanged for OpenFaaS tokens the Kubernetes API will have to be registered as a trusted JWT issuer with OpenFaaS:

```yaml
apiVersion: iam.openfaas.com/v1
kind: JwtIssuer
metadata:
  name: kubernetes.default.svc.cluster.local
  namespace: openfaas
spec:
  iss: https://kubernetes.default.svc.cluster.local
  aud:
    - https://gateway.example.com
  tokenExpiry: 2h
```

The audience should be the URL for your OpenFaaS gateway.

To mount a token into your application Pod you could define a Pod manifest that is similar to:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
  - image: 
    name: my-app
    volumeMounts:
    - mountPath: /var/run/secrets/tokens
      name: openfaas-token
  serviceAccountName: my-app
  volumes:
  - name: openfaas-token
    projected:
      sources:
      - serviceAccountToken:
          path: openfaas-token
          expirationSeconds: 7200
          audience: "http://gateway.example.com"
```

In this example a service account token that is valid for 2 hours and has the openfaas gateway set as the audience will be mounhted into the Pod.

The token will have an expiry time and additional fields like `issuer` and `audience`. The desired properties of the token such as audience and validity duration can be specified in the Pod spec.

The service account provides your application with a unique identity. The `sub` claim from the projected service account token can be used as the principal to match an OpenFaaS Role for your application:

```yaml
apiVersion: iam.openfaas.com/v1
kind: Role
metadata:
  name: my-app
  namespace: openfaas
spec:
  policy:
  - fn-rw
  condition:
    StringEqual:
      jwt:iss:
        - "https://kubernetes.default.svc.cluster.local"
  principal:
    jwt:sub:
      - system:serviceaccount:openfaas:my-app  
``` 

The policies associated with this role can be used to granularly control the actions your application can perform on the OpenFaaS API.

Then, to get an access token for the OpenFaaS REST API the application needs to read the token from the configured file path. Next it needs to perform the token exchange request described in the previous section to exchange the token for an OpenFaaS token.

### Use the Go SDK for OpenFaaS to access the API with a Projected ServiceAccount Token

If your application is written in Go then we've made all of the above much simpler for you. When you use our Go SDK [openfaas/go-sdk](https://github.com/openfaas/go-sdk), it'll handle the token exchange and renewal for you.

It only needs to know how to obtain the initial ID token. As this can be different for every provider you will need to implement the `TokenSource` interface. This could be as simple as reading the token from disk or more complex like performing an OAuth flow with your provider.

This is an example of a token source that reads an ID token from disk that was mounted into the pod using [ServiceAccount token volume projection](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#serviceaccount-token-volume-projection).

```go
type ServiceAccountTokenSource struct{}

func (ts *ServiceAccountTokenSource) Token() (string, error) {
	tokenMountPath := getEnv("token_mount_path", "/var/secrets/tokens")
	if len(tokenMountPath) == 0 {
		return "", fmt.Errorf("invalid token_mount_path specified for reading the service account token")
	}

	idTokenPath := path.Join(tokenMountPath, "openfaas-token")
	idToken, err := os.ReadFile(idTokenPath)
	if err != nil {
		return "", fmt.Errorf("unable to load service account token: %s", err)
	}

	return string(idToken), nil
}
```

Next use the `TokenSource` to create a new client that can be used to invoke the OpenFaaS API. 

```go
gatewayURL, _ := url.Parse("https://gateway.example.com")

auth := &sdk.TokenAuth{
    TokenURL "https://gateway.example.com/oauth/token",
    TokenSource: &ServiceAccountTokenSource{}
}

client := sdk.NewClient(gatewayURL, auth, http.DefaultClient)
```

## Token based authentication for OpenFaaS connectors

With the Community and Standard Edition of OpenFaaS where IAM is not available, event-connectors share the admin account along with every other user of the system. This means a long-lived credential is shared by everyone, and has full access to the system.

When you combine IAM for OpenFaaS with Kubernetes Service Account Token Projection you can deploy connectors that have least privilege access to the OpenFaaS API, and even lock them down to a specific namespace. That last part makes multi-tenancy possible, users can have event connectors that are only scoped to their functions.

In this section we will show you how to deploy the cron-connector in an OpenFaaS cluster with IAM enabled.

### Deploy the cron-connector

Create `cron-connector.yaml` with the helm configuration for the connector:

```yaml
openfaasPro: true

iam:
  enabled: true
  systemIssuer:
    url: "https://gateway.openfaas.example.com"
  resource:
    - "dev:*"
```

Make sure you set `openfaasPro: true`, otherwise you'll get the Community Edition which does not support IAM.

By default the cron-connector operates on all namespaces: `resource: ["*"]`. In this example we will limit it to only look at functions in the `dev` namespaces.

Deploy the connector with helm:

```bash
helm upgrade --install --namespace openfaas \ 
  cron-connector \
  openfaas/cron-connector \
  -f ./cron-connector.yaml
```

The Helm chart will take care of creating a `Policy`, `Role` and `ServiceAccount` for the connector release. This allows you to quickly deploy multiple instances of the same connector with different access scopes e.g. an instance of the cron-connector that only operates on the dev namespace and a second instance that operates on the staging namespace.

You can inspect the `Policy` and `Role` created for this deployment by running:

```bash
$ kubectl get policy cron-connector -o yaml

apiVersion: iam.openfaas.com/v1
kind: Policy
metadata:
  annotations:
    meta.helm.sh/release-name: cron-connector
    meta.helm.sh/release-namespace: openfaas
  labels:
    app.kubernetes.io/managed-by: Helm
  name: cron-connector
  namespace: openfaas
spec:
  statement:
  - action:
    - Function:List
    - Namespace:List
    effect: Allow
    resource:
    - dev:*
    sid: 1-fn-r
```

The Policy restricts permission for the connector so that it can only list namespaces, then list functions within those namespaces. This example can only work on the `dev` namespace.

The resource field will contain the list of resources configured through the `iam.resource` parameter of the chart.

```bash
$ kubectl get role.iam.openfaas.com/cron-connector -o yaml

apiVersion: iam.openfaas.com/v1
kind: Role
metadata:
  annotations:
    meta.helm.sh/release-name: cron-connector
    meta.helm.sh/release-namespace: openfaas
  labels:
    app.kubernetes.io/managed-by: Helm
  name: cron-connector
  namespace: openfaas
spec:
  condition:
    StringEqual:
      jwt:iss:
      - https://kubernetes.default.svc.cluster.local
  policy:
  - cron-connector
  principal:
    jwt:sub:
    - system:serviceaccount:openfaas:cron-connector
```

The principal field is used to match the Role only for the ServiceAccount token used by this connector release. The condition is used to only match for tokens issued by the Kubernetes API.

### Test the connector

Deploy a function and annotate it so it will be invoked by te cron connector on a schedule:

```bash
faas-cli store deploy nodeinfo \
  --namespace staging
  --annotation topic="cron-function"\
  --annotation schedule="* * * * *"
```

You can inspect the connector logs to see the function get added and is invoked by the connector.

We like the `stern` tool for trailing logs, you can install it with `arkade get stern`, or by searching for the tool on GitHub.

```
$ stern cron-connector -s 30s

+ cron-connector-695db8b77f-46j8m › cron-connector
cron-connector-695db8b77f-46j8m cron-connector Cron-Connector Pro       Version: b657abef0299fabc147d04a1a7bb0aff989abf56      Commit: 0.1.2-2-gb657abe
cron-connector-695db8b77f-46j8m cron-connector 2023-07-03T10:56:39.275Z info    cron-connector/main.go:118     Licensed to: Han <han@openfaas.com>, expires: 63 day(s) Products: [openfaas-enterprise openfaas-pro inlets-pro]
cron-connector-695db8b77f-46j8m cron-connector 2023-07-03T10:56:39.275Z info    cron-connector/main.go:135     Config  {"gateway": "http://gateway.openfaas:8080", "async_invocation": false, "rebuild_interval": 30, "rebuild_timeout": 10}
cron-connector-695db8b77f-46j8m cron-connector 2023-07-03T10:57:09.468Z info    cron-connector/main.go:241      Added   {"function": "nodeinfo.dev", "schedule": "* * * * *"}
cron-connector-695db8b77f-46j8m cron-connector 2023-07-03T10:58:00.020Z info    types/scheduler.go:54   Invoking        {"function": "nodeinfo.dev", "schedule": "* * * * *"}
cron-connector-695db8b77f-46j8m cron-connector 2023-07-03T10:58:00.031Z info    cron-connector/main.go:166      Response        {"function": "nodeinfo", "status": 200, "bytes": 109, "duration": "10ms"}
```

You can deploy the same function to the `staging` namespace to verify it does not get added and invoked by the cron connector.

```bash
faas-cli store deploy nodeinfo \
  --namespace staging
  --annotation topic="cron-function"\
  --annotation schedule="* * * * *"
```

### Deploy multiple connectors

The chart can be used to deploy multiple connectors that operate on different resources.

To deploy a second connector that operates on the staging namespaces:

1. Create a `staging-cron-connector.yaml` file:

    ```yaml
    openfaasPro: true

    iam:
      enabled: true
      systemIssuer:
        url: "https://gateway.example.com"
      resource:
        - "staging:*"
    ```

2. Deploy the connector with a different release name:

    ```bash
    helm upgrade --install --namespace openfaas \ 
      staging-cron-connector \
      openfaas/cron-connector \
      -f ./staging-cron-connector.yaml
    ```

    A separate `ServiceAccount`, `Policy` and `Role` with the name `staging-cron-connector` will be created by the helm chart.

This connector should start to invoke the function in the staging namespace we deployed in the previous step.

This is the same process that you would take to enable cron or Kafka event riggers for different users in a multi-tenant OpenFaaS cluster.

## Wrapping up

We explained how IAM for OpenFaaS supports using OIDC and JSON Web Tokens (JWT) to authenticate with the OpenFaaS REST API. We sthen howed how you can obtain an ID token using Kubernetes Service Account Token Projection and exchange it for an OpenFaaS access token that can be used to authenticate with the API.

One thing we also wanted to highlight was how the Go SDK can be used to simplify the process of obtaining and rotating an OpenFaaS access token for the API.

For this article, we converted the cron-connector to authenticate to the OpenFaaS API with least privileges, and to show how it can be deployed multiple times for different namespaces. If you are using other connectors and would like them to support IAM let us know so that we can prioritise them for your team.

For an overview of how IAM works see: [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/).

You may also like:

* [Build a Multi-Tenant Functions Platform with OpenFaaS ](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)
* [How to build functions from source code with the Function Builder API](https://www.openfaas.com/blog/how-to-build-via-api/)
* [Docs: OpenFaaS REST API](https://docs.openfaas.com/reference/rest-api/)
* [Comparison - Community Edition vs. Standard vs. for Enterprises](https://docs.openfaas.com/openfaas-pro/introduction/#comparison)
