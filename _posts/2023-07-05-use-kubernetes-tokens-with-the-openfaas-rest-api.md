---
title: "How to authenticate to OpenFaaS using Kubernetes JWT tokens"
description: "Learn how Kubernetes service account token projection can be used for machine to machine authorization with IAM for OpenFaaS"
date: 2023-07-05
categories:
- authorization
- iam
- enterprise
- security
- connectors
- multi-tenancy
dark_background: true
author_staff_member: han
image: ""
hide_header_image: true
---

Learn how Kubernetes service account token projection can be used for machine to machine authorization with IAM for OpenFaaS.

Projected Service Account Tokens can be used to obtain short-lived tokens to use to present for authentication to other Kubernetes services. Unlike the prior generation of tokens, they can be set to expire in as little as 10 minutes making them ideal for use for machine to machine communication.

In this article we will see how these tokens can be used to authenticate with the OpenFaaS API.

We'll be discussing OpenFaaS for IAM, you can get a quick overview of how it works here:  [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/).

To try out the examples yourself make sure you have a working OpenFaaS deployment with IAM enabled.

## Integrate with the OpenFaaS API using tokens

IAM for OpenFaaS supports using OIDC and JSON Web Tokens (JWT) to authenticate with the OpenFaaS REST API.

To authenticate with the API your app will need to:

1. Obtain an id_token. You can either read it from disk if you are using service account token projection or perform an authentication flow with your identity provider.
2. Exchange the token for an OpenFaaS token through the OpenFaaS gateway.
3. Repeat the previous two steps when the OpenFaaS token expires.

The id_token can be exchanged for an OpenFaaS token by making an OAuth 2.0 Token Exchange request according to [RFC 8693](https://www.rfc-editor.org/rfc/rfc8693.html).

The actual token exchange request might look like this:

```
POST /oauth/token HTTP/1.1
Host: gateway.example.com
Content-Type: application/x-www-form-urlencoded

subject_token=your-id-tokent&
subject_token_type=urn:ietf:params:oauth:token-type:id_token&
grant_type=urn:ietf:params:oauth:grant-type:token-exchange
```

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

The access_token returned by the code exchange request must be sent in the `Authorzation` header when making requests to protected resources in the OpendFaaS REST API.

### Use a projected service account token to access the OpenFaaS REST API

If your app is deployed in a Kubernetes cluster, service account token projection can be used to obtain the initial ID token.

The token will have an expiry time and additional fields like `issuer` and `audience`. The desired properties of the token such as audience and validity duration can be specified in the Pod spec.

To get an access token for the OpenFaaS REST API the application needs to read the token from the configured file path. Next it needs to perform the token exchange request described in the previous section to exchange the token for an OpenFaaS token.

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

### Use the Go SDK for OpenFaaS to access the API with a Projected ServiceAccount Token

If your application is written in Go consider using the official [OpenFaaS go-sdk](https://github.com/openfaas/go-sdk). It will handle the token exchange and renewal when the OpenFaaS token has expired for you.

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

OpenFaaS services like the connectors can also use service account token projection to authenticate to the OpenFaaS API with least privileges.

In this section we will show you how to deploy the cron-connector in an OpenFaaS cluster with IAM enabled.

### Deploy the cron connector

Create cron-connector.yaml with the helm configuration for the connector:

```yaml
openfaasPro: true

iam:
  enabled: true
  systemIssuer:
    url: "https://gateway.openfaas.example.com"
  resource:
    - "dev:*"
```

By default the cron-connector operates on all namespaces: `resource: ["*"]`. In this example we will limit it to only look at functions in the `dev` namespaces.

Deploy the connector with helm:

```bash
helm upgrade --install --namespace openfaas \ 
  cron-connector \
  openfaas/cron-connector \
  -f ./cron-connector.yaml
```

The Helm chart will take care of creating a `Policy`, `Role` and `ServiceAccount` for the connector release. This allows you to quickly deploy multiple instances of the same connector with different access scopes e.g. an instance of the cron-connector that only operates on the dev namespace and a second instance that operates on the staging namespace.

Useful for multi-tenant OpenFaaS clusters where you would want connectors to be scoped to the resources of a single tenant.

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
    - Function:Read
    effect: Allow
    resource:
    - dev:*
    sid: 1-fn-r
```

The Policy restricts permission for the connector. Connecters only need to be able to list functions in a namespace. In this case the connector only has permissions to read functions in the `dev` namespace.

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

1. Create a staging-cron-connector.yaml file:

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

## Wrapping up

IAM for OpenFaaS supports using OIDC and JSON Web Tokens (JWT) to authenticate with the OpenFaaS REST API. We showed how you can obtain an ID token using Kubernetes service account token projection and exchange it for an OpenFaaS access token that can be used to authenticate with the API.

For an overview of how IAM works see:  [Walkthrough of Identity and Access Management (IAM) for OpenFaaS](https://www.openfaas.com/blog/walkthrough-iam-for-openfaas/).

Connectors can now authenticate to the OpenFaaS API with least privilege. It possible to deploy multiple instances of a connector each operating on specific namespaces. The is useful if you are using OpenFaaS for multiple tenants.

You can read more about multi-tenancy with OpenFaaS in: [Build a Multi-Tenant Functions Platform with OpenFaaS ](https://www.openfaas.com/blog/build-a-multi-tenant-functions-platform/)

