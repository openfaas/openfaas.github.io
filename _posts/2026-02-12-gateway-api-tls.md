---
title: "TLS for OpenFaaS with the Kubernetes Gateway API"
description: "Learn how to expose the OpenFaaS gateway and dashboard with TLS using the Kubernetes Gateway API and cert-manager."
date: 2026-02-12
categories:
- kubernetes
- ingress
- tls
- gateway-api
dark_background: true
# image: "/images/2026-02-gateway-api-tls/background.png"
hide_header_image: true
---

Learn how to expose the OpenFaaS gateway and dashboard over HTTPS using the Kubernetes Gateway API with automated TLS certificates from Let's Encrypt.

## Introduction

Whilst Ingress has served the community well for many years, the [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) is now the recommended successor. It offers a more expressive and role-oriented model for managing traffic into your cluster.

The Gateway API separates concerns into distinct resources:

- **GatewayClass** - Defines the type of gateway controller (provided by the implementation).
- **Gateway** - Declares a load balancer with one or more listeners, including TLS configuration.
- **HTTPRoute** - Binds hostnames and paths to backend services.

This separation means that a cluster operator can manage TLS termination and listener configuration in a Gateway, while application teams define routing via HTTPRoute resources. It also means that the same configuration works across [many conformant implementations](https://gateway-api.sigs.k8s.io/implementations/#conformant) including Envoy Gateway, Traefik, NGINX Gateway Fabric, and Istio.

In this post, we'll walk through:

1. Installing a gateway controller
2. Configuring cert-manager for automated Let's Encrypt certificates
3. Creating a Gateway and HTTPRoutes for the OpenFaaS dashboard and gateway

## Prerequisites

You'll need:

- A Kubernetes cluster with OpenFaaS installed via Helm
- A domain name with the ability to create DNS records
- A public IP address or load balancer (i.e. a managed Kubernetes service like EKS, GKE, or AKS)

## Installing a Gateway controller

[Envoy Gateway](https://gateway.envoyproxy.io/) makes it easy to use Envoy Proxy as a Kubernetes API Gateway. It implements and extends the Kubernetes Gateway API, and is one of the [conformant implementations](https://gateway-api.sigs.k8s.io/implementations/#conformant).

In this guide we focus on Envoy Gateway but the Gateway and HTTPRoute resources we are going to create should work with any conformant Gateway controller implementation. If you prefer a different controller, adjust the `gatewayClassName` accordingly.

[Install Envoy Gateway using Helm](https://gateway.envoyproxy.io/docs/install/install-helm/#install-with-helm). The chart includes the Gateway API CRDs, so no separate CRD installation is needed:

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.0 \
  -n envoy-gateway-system \
  --create-namespace
```

Wait for Envoy Gateway to become available:

```bash
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```

Create a GatewayClass so that Gateway resources can reference the Envoy Gateway controller:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
```

Verify that the GatewayClass is accepted:

```bash
kubectl get gatewayclass

NAME    CONTROLLER                                      ACCEPTED
eg      gateway.envoyproxy.io/gatewayclass-controller    True
```

## Install cert-manager

[cert-manager](https://cert-manager.io) automates TLS certificate management in Kubernetes. It integrates with the Gateway API to automatically create certificates for Gateway listeners.

Install cert-manager with Gateway API support enabled:

```bash
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true
```

> Note: The Gateway API CRDs must be installed before cert-manager starts. If you installed them after cert-manager, restart the controller with: `kubectl rollout restart deployment cert-manager -n cert-manager`

## Create a cert-manager Issuer

Create an Issuer in the `openfaas` namespace that uses Let's Encrypt with an HTTP-01 challenge. cert-manager will use this Issuer to automatically obtain certificates for any Gateway listener that references it.

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-prod
  namespace: openfaas
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: openfaas-gateway
            namespace: openfaas
            kind: Gateway
```

Notice that the solver uses a [`gatewayHTTPRoute`](https://cert-manager.io/docs/configuration/acme/http01/#configuring-the-http-01-gateway-api-solver) instead of the `ingress` class used in a traditional Ingress-based setup. This tells cert-manager to create a temporary HTTPRoute attached to a Gateway to solve the ACME HTTP-01 challenge.

The `parentRefs` field points to the Gateway we'll create in the next step, so cert-manager knows which Gateway to attach the challenge route to. The referenced Gateway must have a listener on port 80, since the HTTP-01 challenge requires Let's Encrypt to reach a well-known URL over plain HTTP. In our setup, we will include this HTTP listener directly on the same Gateway that serves HTTPS traffic. Alternatively, the Issuer could reference a separate Gateway created specifically for solving HTTP-01 challenges, as long as that Gateway has a port 80 listener.

If you're setting this up for the first time, consider using the staging issuer to avoid rate limits. Change the server URL to `https://acme-staging-v02.api.letsencrypt.org/directory` and the issuer name to `letsencrypt-staging`.

## Expose the OpenFaaS gateway with TLS


### Create the Gateway

The Gateway resource defines a load balancer with listeners for your domains. When a Gateway is created, the referenced GatewayClass controller provisions or configures the underlying load balancing infrastructure. The `gatewayClassName` field is required and must reference an existing GatewayClass - in our case the `eg` GatewayClass we created earlier for Envoy Gateway.

Start with a single HTTPS listener for the OpenFaaS gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: openfaas-gateway
  namespace: openfaas
  annotations:
    cert-manager.io/issuer: letsencrypt-prod
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  - name: gateway
    hostname: "gw.example.com"
    port: 443
    protocol: HTTPS
    allowedRoutes:
      namespaces:
        from: Same
    tls:
      mode: Terminate
      certificateRefs:
      - name: openfaas-gateway-cert
```

The `cert-manager.io/issuer` annotation tells cert-manager to watch this Gateway and automatically create a Certificate resource for each HTTPS listener. The certificate will be stored in the Secret referenced by `certificateRefs`.

The first listener on port 80 is the HTTP listener referenced by the Issuer we created earlier to resolve HTTP-01 challenges.

The second listener serves HTTPS traffic for `gw.example.com` on port 443. The `tls.mode: Terminate` setting means TLS is terminated at the Gateway and traffic is forwarded to the backend as plain HTTP. The `certificateRefs` field references the Secret where cert-manager will store the issued certificate.

### Create the DNS record

Find the external IP address assigned to the Gateway:

```bash
$ kubectl get gateway -n openfaas openfaas-gateway

NAME               CLASS   ADDRESS          PROGRAMMED
openfaas-gateway   eg      203.0.113.10     True
```

Create an A record (or CNAME if you see a hostname) in your DNS provider pointing `gw.example.com` to this address.

### Verify the certificate

Check that cert-manager has issued the certificate. Note that it might take a while for DNS to propagate and the certificate to become ready. 

```bash
$ kubectl get certificate -n openfaas

NAME                     READY   SECRET                   AGE
openfaas-gateway-cert    True    openfaas-gateway-cert    2m
```

If the certificate is not become ready, check the cert-manager logs:

```bash
kubectl logs -n cert-manager deploy/cert-manager
```

### Create the HTTPRoute

While the Gateway defines listeners and TLS termination, it is the HTTPRoute that binds hostnames and paths to backend services.

Create an HTTPRoute that routes traffic from the Gateway to the OpenFaaS gateway service:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: openfaas-gateway
  namespace: openfaas
spec:
  parentRefs:
  - name: openfaas-gateway
  hostnames:
  - "gw.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: gateway
      port: 8080
```

The `parentRefs` field defines which Gateway this route wants to be attached to, in this case the `openfaas-gateway` Gateway. The `hostnames` field filters requests by the Host header before rules are evaluated, ensuring only requests for `gw.example.com` are matched. The `backendRefs` field defines the backend service where matching requests are forwarded - in this case the OpenFaaS `gateway` service on port 8080.

### Log in to OpenFaaS

Once the certificate is issued and DNS has propagated, you can log in:

```bash
export OPENFAAS_URL=https://gw.example.com

PASSWORD=$(kubectl get secret -n openfaas basic-auth \
  -o jsonpath="{.data.basic-auth-password}" | base64 --decode; echo)
echo -n $PASSWORD | faas-cli login --username admin --password-stdin

faas-cli list
```

## Add the OpenFaaS dashboard

If you're using OpenFaaS Standard or OpenFaaS for Enterprises and have the [OpenFaaS dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/) enabled you'll probably want to expose it as well.

### Add a listener to the Gateway

Add a second HTTPS listener for the dashboard domain to the existing Gateway:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: openfaas-gateway
  namespace: openfaas
  annotations:
    cert-manager.io/issuer: letsencrypt-prod
spec:
  gatewayClassName: eg
  listeners:
  - name: http
    port: 80
    protocol: HTTP
    allowedRoutes:
      namespaces:
        from: Same
  - name: gateway
    hostname: "gw.example.com"
    port: 443
    protocol: HTTPS
    allowedRoutes:
      namespaces:
        from: Same
    tls:
      mode: Terminate
      certificateRefs:
      - name: openfaas-gateway-cert
  - name: dashboard
    hostname: "dashboard.example.com"
    port: 443
    protocol: HTTPS
    allowedRoutes:
      namespaces:
        from: Same
    tls:
      mode: Terminate
      certificateRefs:
      - name: openfaas-dashboard-cert
```

cert-manager will detect the new HTTPS listener and automatically create a second Certificate for the dashboard domain.

### Create the DNS record for the dashboard

Create an A or CNAME record for `dashboard.example.com` pointing to the same external IP as the Gateway.

Verify both certificates are ready:

```bash
$ kubectl get certificate -n openfaas

NAME                      READY   SECRET                    AGE
openfaas-gateway-cert     True    openfaas-gateway-cert     10m
openfaas-dashboard-cert   True    openfaas-dashboard-cert   2m
```

Note that it might take a while for the DNS to propagate and the certificate to get ready.

### Create the HTTPRoute for the dashboard

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: openfaas-dashboard
  namespace: openfaas
spec:
  parentRefs:
  - name: openfaas-gateway
  hostnames:
  - "dashboard.example.com"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: dashboard
      port: 8080
```

You should now be able to access the dashboard at `https://dashboard.example.com`.

## Wrapping up

We covered:

1. Installing a gateway controller
2. Configuring cert-manager with Gateway API support for automated TLS
3. Creating a Gateway and HTTPRoutes for the OpenFaaS gateway and dashboard

If you are not ready to migrate to the Gateway API yet see the existing guide: [TLS for OpenFaaS](https://docs.openfaas.com/reference/tls-openfaas/) for how to configure TSL with the traditional Ingress-based approach and Traefik.

For questions, comments and suggestions, reach out to us via your existing communication channels, or through our [Pricing page](https://www.openfaas.com/pricing/).
