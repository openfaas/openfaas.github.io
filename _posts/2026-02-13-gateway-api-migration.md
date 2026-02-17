---
title: "How to Migrate OpenFaaS to Gateway API"
description: "Learn how to migrate OpenFaaS to the Kubernetes Gateway API with TLS certs from Let's Encrypt"
date: 2026-02-13
categories:
- kubernetes
- ingress
- tls
- gateway-api
author_staff_member: han
author_staff_member_editor: alex
dark_background: true
image: "/images/2026-02-gwapi/background.png"
hide_header_image: true
---

In this post we'll walk through the current options for getting traffic into OpenFaaS on Kubernetes, the latest Gateway API, and how to migrate from Ingress.

Table of contents:

* [Preamble: The unfortunate double-whammy](#preamble-the-unfortunate-double-whammy)
* [Introduction to Gateway API](#introduction-to-gateway-api)
* [Prerequisites](#prerequisites)
* [Check and update Gateway API CRDs](#check-and-update-gateway-api-crds)
* [Install a Gateway API Implementation](#install-a-gateway-api-implementation)
* [Install cert-manager](#install-cert-manager)
* [Create a cert-manager Issuer](#create-a-cert-manager-issuer)
* [Expose the OpenFaaS gateway with TLS](#expose-the-openfaas-gateway-with-tls)
* [Add the OpenFaaS dashboard](#add-the-openfaas-dashboard)
* [Final thoughts and next steps](#final-thoughts-and-next-steps)

## Preamble: The unfortunate double-whammy

For as long as we can remember, Ingress has been the de facto standard for exposing HTTP services from Kubernetes clusters. It has always had a very simple syntax, and has only gone through one major change, graduating from `extensions/v1beta1` to `networking.k8s.io/v1` in Kubernetes 1.19 (around 2019). The key change was the introduction of the `pathType` field for precise path matching and the `IngressClass` (instead of annotations) resource for consistent controller configuration.

Honestly, we don't need to explain how Ingress works, it's so well understood and widely used.

But there was a glint in the eyes of the Kubernetes maintainers, and they wanted to provide something that was much more ambitious in its scope, that addressed needs that OpenFaaS customers don't tend to have. The [Istio service mesh](https://istio.io/) was a precursor for this, with its own set of add-ons with similar names, and was eventually crystallised into the *Gateway API*.

Most OpenFaaS and Inlets customers we've encountered have been using Ingress (many moved away from Istio and service meshes) preferring simplicity and ease of use. They tended to always be using the [ingress-nginx](https://kubernetes.github.io/ingress-nginx/) controller. A brief history: Ingress Nginx started off as a hobby project for a single maintainer, who was unable to find corporate sponsorship or support from the CNCF, and had to give it up in 2019. Shortly after 2-3 maintainers stepped up and ran it reasonably well as a spare-time project, but without sustainable backing as part of a day job, the same thing started to happen again. More issues were raised, than there were people ready to fix and test them.

So the Kubernetes maintainers made a judgement call, they decided to announce project would be officially mothballed in March 2026. No further updates, or security patches. That's a big deal.

**Why is this a double whammy?**

The announcement had some choice words: "if you must continue to use Ingress" - sounds a bit like you're in the wrong if you are using something that fits your needs. It has an undertone of Ingress being a legacy or inappropriate solution, potentially something that may eventually go the way of ingress-nginx. We focus on simple solutions that work well for our users, however, reading between the lines, we want to make sure you're prepared for the future.

**So if we're pragmatic, we have a couple of options:**

1. try to move to an Ingress Controller like Traefik which can support some of the behaviours and settings of Ingress Nginx,
2. or move to Gateway API (the developing, but approved future standard).

Rather than installing one chart, and creating a basic Ingress resource, and adding 1-2 annotations, we have a much more varied path. Gateway API intends to provide an agnostic overlay, shying away from annotations as extensions, and focusing on a new set of decoupled API objects.

**It's only a bit of YAML, how hard could it be?**

For OpenFaaS customers, we're trying to make this transition as simple as possible, starting with this guide that converts YAML for like for like. But one of our other products [Inlets Uplink](https://docs.inlets.dev/uplink/) integrates ingress-nginx much more deeply and relies on its annotations, that is going to be significantly more work both for the controller itself, and for users needing to upgrade.

**Gateways everywhere**

The core of OpenFaaS is the OpenFaaS Gateway. This was created in 2016 and has nothing to do with the Gateway API for Kubernetes. Unfortunately, the terms are overloaded, so many of you will end up with "openfaas-gateway" (Gateway API object) and a "gateway" (Service object for the OpenFaaS Gateway), and both may well be in the OpenFaaS namespace.

We're sorry, there's not much we could do about this, but if you can think of a better name or a more descriptive term, we would appreciate your input.

## Introduction to Gateway API

[Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) is an add-on to Kubernetes, which:

* Aims to abstract vendor implementations under one set of APIs
* Acts as an add-on, rather than a native feature
* Attempts to split the roles of cluster administrator and application developer through different resources.
* Covers the main use-cases of Ingress Controllers, such as TLS termination, path-based routing, and load balancing.

From the perspective of OpenFaaS, there are three Gateway API resources we need:

- **GatewayClass** - maps to IngressClass - i.e. whether you're using Kgateway, Istio, Envoy Gateway, or another implementation.
- **Gateway** - maps to a LoadBalancer Service with one or more listeners and handles TLS configuration.
- **HTTPRoute** - binds paths and/or hostnames to backend services.

This separation means that a cluster operator can manage TLS termination and listener configuration in a Gateway, while application teams define routing via HTTPRoute resources. It also means that the same configuration works across [many conformant implementations](https://gateway-api.sigs.k8s.io/implementations/#conformant) including Envoy Gateway, Traefik, NGINX Gateway Fabric, and Istio.

The `openfaas` chart has built-in support to generate Ingress objects. Once we have enough feedback from customers, we'll know if and how you want us to add support for Gateway API resources into the chart. For now, this guide shows how to create the resources through manual YAML files, which we think is more useful for building understanding.

We'll: Install a Gateway API implementation, configure cert-manager, and define a Gateway and HTTPRoute both the OpenFaaS Gateway and Dashboard.

For any of the YAML examples, you can either create a file, and run `kubectl apply -f ./name.yaml` or `kubectl apply -f -` then paste in the snippet directly and hit enter then Control + D.

## Prerequisites

- A Kubernetes cluster with OpenFaaS installed via Helm
- A domain name with the ability to create DNS records
- A public IP address or load balancer (i.e. EKS, GKE, or AKS), or [inlets-operator](https://github.com/inlets/inlets-operator) which does the same for any private or NAT'd or firewalled Kubernetes cluster

## Check and update Gateway API CRDs

Some Kubernetes distributions ship their own version of the Gateway API CRDs, which may not match those your implementation wants to use.

Check with:

```bash
$ kubectl get crd | grep gateway.networking.k8s.io

backendtlspolicies.gateway.networking.k8s.io          2026-02-13T15:06:49Z
gatewayclasses.gateway.networking.k8s.io              2026-02-13T15:06:49Z
gateways.gateway.networking.k8s.io                    2026-02-13T15:06:49Z
grpcroutes.gateway.networking.k8s.io                  2026-02-13T15:06:49Z
httproutes.gateway.networking.k8s.io                  2026-02-13T15:06:49Z
referencegrants.gateway.networking.k8s.io             2026-02-13T15:06:49Z
tcproutes.gateway.networking.k8s.io                   2026-02-13T15:07:31Z
tlsroutes.gateway.networking.k8s.io                   2026-02-13T15:07:31Z
udproutes.gateway.networking.k8s.io                   2026-02-13T15:07:31Z
```

For this example, it's best to let Envoy Gateway handle the CRD installation with versions it supports, so remove all CRDs that may be preloaded in your cluster:

```bash
# example: replace v1.1.0 with the version you want
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
kubectl delete -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/experimental-install.yaml
```

## Install a Gateway API Implementation

Early feedback from customers suggests that [Envoy Gateway](https://gateway.envoyproxy.io/) may well end-up being the equivalent of "ingress-nginx" in the Gateway API world. It is one of the many [conformant implementations](https://gateway-api.sigs.k8s.io/implementations/#conformant).

> `gatewayClassName` is similar to the old `ingressClassName` in the Ingress API. It is a string that identifies the Gateway API implementation that should be used to manage the Gateway and HTTPRoute resources. So if you want to use a different implementation, just change the `gatewayClassName` in any examples and install it using its documentation, instead of that of Envoy Gateway.
> 
> Watch out for this gotcha: many tools such as cert-manager, may require additional settings or flags to turn on Gateway API support. 

Install Envoy Gateway using [its Helm chart](https://gateway.envoyproxy.io/docs/install/install-helm/#install-with-helm). The chart includes the Gateway API CRDs, so no separate CRD installation is needed.

Bear in mind that Envoy Gateway maintains its own [compatibility matrix](https://gateway.envoyproxy.io/news/releases/matrix/).

```bash
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.7.0 \
  -n envoy-gateway-system \
  --create-namespace
```

Since this post will be valid for quite some time, you can find alternative versions of the chart by running `arkade get crane`, then `crane ls envoyproxy/gateway-helm`. See also: [arkade](https://github.com/alexellis/arkade).

Wait for Envoy Gateway to become available:

```bash
kubectl wait --timeout=5m -n envoy-gateway-system \
  deployment/envoy-gateway --for=condition=Available
```

Create a `GatewayClass` so that `Gateway` resources can reference the Envoy Gateway controller, the usual name is `eg` short for Envoy Gateway.

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
  --version v1.19.3 \
  --set crds.enabled=true \
  --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true
```

You can run `crane ls jetstack/cert-manager` to see alternative versions.

> Note: The Gateway API CRDs must be installed before cert-manager starts.
> If you installed them after cert-manager, restart the controller with: `kubectl rollout restart deployment cert-manager -n cert-manager`

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

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging
  namespace: openfaas
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-account-key
    solvers:
    - http01:
        gatewayHTTPRoute:
          parentRefs:
          - name: openfaas-gateway
            namespace: openfaas
            kind: Gateway
```

## Expose the OpenFaaS gateway with TLS

### Create the Gateway object

The Gateway (API Gateway, not OpenFaaS Gateway) resource defines a LoadBalancer with listeners for your domains. When a Gateway is created, the referenced GatewayClass controller provisions or configures the underlying load balancing infrastructure. The `gatewayClassName` field is required and must reference an existing GatewayClass - in our case the `eg` GatewayClass we created earlier for Envoy Gateway.

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

You can also explore the various resources created by cert-manager.

Use either the `get` or `describe` verb for more information about the resources.

```bash
kubectl get certificaterequests -n openfaas
kubectl get issuers -n openfaas
kubectl get orders -n openfaas
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
    timeouts:
      # Should match gateway.writeTimeout in the OpenFaaS Helm chart.
      # Envoy's default of 15s is too short for most functions.
      request: 10m
    backendRefs:
    - name: gateway
      port: 8080
```

The `timeouts.request` field sets the maximum duration for the gateway to respond to an HTTP request. This value should be set to match the `gateway.writeTimeout` configured in the OpenFaaS Helm chart. If omitted, Envoy Proxy uses a default of 15 seconds which will cause functions with longer execution times to time out at the proxy level. See the [expanded timeouts guide](https://docs.openfaas.com/tutorials/expanded-timeouts/) for details on configuring all timeout values.

The `parentRefs` field defines which Gateway this route wants to be attached to, in this case the `openfaas-gateway` Gateway. The `hostnames` field filters requests by the Host header before rules are evaluated, ensuring only requests for `gw.example.com` are matched. The `backendRefs` field defines the backend service where matching requests are forwarded - in this case the OpenFaaS `gateway` service on port 8080.

### Attempt to reach a function

Using `kubectl` we can deploy a function from the OpenFaaS store, and invoke it via curl.

```bash
faas-cli generate --from-store env | kubectl apply -f -

curl -i https://gw.example.com/function/env
```

### Log in to OpenFaaS

Once the certificate is issued and DNS has propagated, you can log in and use it as you would normally through Ingress.

For instance, if you're not using IAM for OpenFaaS, you can simply run:

```bash
export OPENFAAS_URL=https://gw.example.com

PASSWORD=$(kubectl get secret -n openfaas basic-auth \
  -o jsonpath="{.data.basic-auth-password}" | base64 --decode; echo)
echo -n $PASSWORD | faas-cli login --username admin --password-stdin

faas-cli list
```

## Add the OpenFaaS dashboard

The [OpenFaaS Dashboard](https://docs.openfaas.com/openfaas-pro/dashboard/) is an essential add-on for OpenFaaS Standard and OpenFaaS for Enterprises.

This is where we start to see some of the differences between Gateway API and Ingress.

With Ingress, the Ingress Controller has one IP, and routes all traffic to hosts and paths defined on Ingress records.

With Gateway API, you have two things to update and maintain, and to keep in sync: both the Gateway and the HTTPRoute objects must include the desired hostname i.e. `dashboard.example.com`.

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
    timeouts:
      # Should match gateway.writeTimeout in the OpenFaaS Helm chart.
      # Envoy's default of 15s is too short for most functions.
      request: 10m
    backendRefs:
    - name: dashboard
      port: 8080
```

You should now be able to access the dashboard at `https://dashboard.example.com`.

That concludes the walk-through

## Final thoughts and next steps

If you're not sure whether to try to hang onto Ingress with one of the Ingress Controllers that's still being maintained like Traefik, or to migrate to the Gateway API right now. We'd strongly encourage you to pick a sensible default like Envoy Gateway, and Gateway API. It will require some initial setup to migrate, but once it's in place, we don't expect you to need to change it much.

In summary we coveered:

* The double whammy of Ingress being sidelined by the community as a "legacy" technology, and ingress-nginx being deprecated with a very short notice period.
* A sensible default for implementing Gateway API with Envoy Gateway.
* How to map Gateway API resources to the OpenFaaS gateway and dashboard, including TLS termination from Let's Encrypt.

If taking on Gateway API feels like too much right now, do not be tempted to continue using ingress-nginx in its unmaintained state. It's had severe security issues in the recent past like [CVE-2025-1974](https://kubernetes.io/blog/2025/03/24/ingress-nginx-cve-2025-1974/) on March 24 2025. Instead, you can get the basic routing, load balancing and TLS termination from Traefik. We've updated our [existing guide on Ingress](https://docs.openfaas.com/reference/tls-openfaas/) to reflect this.

For questions, comments and suggestions, reach out to us via your existing support channels, or through the form on our [Pricing page](https://www.openfaas.com/pricing/).
