---
title: Introducing Faster Function Builds With a Self-Hosted Registry
description: With the Function Builder, you can take code from customers or partners, build and deploy to run in a sandbox. A Self-Hosted registry can speed up the pipeline.
date: 2024-11-20
categories:
- functionbuilder
- rest
- faas
- sandbox
dark_background: true
# image: /images/2024-09-openfaas-edge/background.png
author_staff_member: alex
hide_header_image: true
---

The Function Builder API makes it easy to take code in from customers, partners, or internal teams, build it, and deploy it to run in an isolated container-based sandbox. This is a powerful feature for teams that need to run potentially untrusted or hostile code in a safe way.

The API accepts code in a tarball, along with some configuration and returns the build logs, plus an image reference that you can use to make a HTTP call to the OpenFaaS Gateway to create or update a function. You can create tenant namespaces to isolate functions from different customers or teams using the REST API.

Earlier on the blog in [Integrate FaaS Capabilities into Your Platform with OpenFaaS](/blog/add-a-faas-capability/) we showed how several companies are taking code from their users via a web-based IDE such as Code9 or the Ace editor. You could also source the files from a database, S3, a Git repository, or a zip file.

**How to optimise the pipeline with a self-hosted registry**

We recommend using the hosted registry offering from your cloud provider, whether that be Elastic Container Registry (ECR), Google Container Registry (GCR), or Azure Container Registry (ACR). These are built to scale, are backed by high speed storage, and can be deployed into the same region as your Kubernetes cluster for optimal latency.

However, you can also self-host your own registry inside the Kubernetes cluster, or on a host within the same private network, this reduces latency to the absolute minimum for both pushing (during the creation of the user's image) and pulling images from the registry (during deployment via REST API).

Docker created a registry some time ago which was subsequently donated to the CNCF and renamed to "distribution". The distribution project is simple, lightweight, and easy to extend with authorization and different backing options like S3. [Docker Registry](https://docs.docker.com/registry/).

The Habor project originally created at VMware is a much more feature-rich registry with a UI, RBAC, and built-in options for mirroring and managing images. [Harbor](https://goharbor.io/).

## Tutorial

We won't cover the installation of the registry in this post, but we will assume that you have generated a Certificate Authority (CA), and have signed a certificate for the registry using it.

One thing to note is that your server certificate for the registry will need to include the fully qualified name including the namespace, since the registry will be deployed in one namespace, and functions will be running in another, i.e. `registry-service.openfaas.svc.cluster.local`.

The examples assume the distribution registry is installed in the openfaas namespace, under the Kubernetes service name `registry-service`, or the fully qualified name `registry-service.openfaas.svc.cluster.local`.

The Function Builder API makes use of buildkit to publish images, so the rest of the steps will focus on:

1. How to configure the Function Builder API to trust the CA when publishing images
2. How to configure the cluster to trust the CA when pulling images

The Function Builder requires several steps to be used with a self-hosted registry:

* A secret containing the CA certificate
* A secret containing the Docker config file for authentication for publishing images
* A secret containing the payload secret for making requests to the Function Builder API itself to trigger a build
* A custom values file for the Function Builder helm chart

Then, for deploying the function, you will need to create a pull secret in the `openfaas-fn` namespace.

### 1. Create a secret for the CA

Assuming you have a file named `ca.crt`, run:

```sh
kubectl create secret generic -n openfaas \
    registry-tls --from-file=ca.crt=ca.crt
```

This will create a secret named `registry-tls` in the `openfaas` namespace.

### 2. Configure the Function Builder API in its helm chart

The helm chart is named `pro-builder`, create a values.yaml file, and define the following `caSecret` with the name of the secret you created above.

custom-values.yaml:

```yaml
buildkit:
    caSecret: "registry-tls"
```

Now we need to create a custom buildkit config file, which will be mounted into the Function Builder API pod.

custom-values.yaml:

```yaml
buildkit:
    caSecret: "registry-tls"
    config: |
        [registry."registry-service.openfaas.svc.cluster.local:443"]
            ca=["/home/user/.config/buildkit-tls/ca.crt"]
```

The path above is required when running in rootless mode, for root mode, change it to:

custom-values.yaml:

```yaml
buildkit:
    caSecret: "registry-tls"
    config: |
        [registry."registry-service.openfaas.svc.cluster.local:443"]
            ca=["/var/run/registry-tls/ca.crt"]
```

Next, set the mode for buildkit, this should usually be `rootless`, but some clusters may require `root` due to older Kernel or Operating System versions.

custom-values.yaml:

```diff
buildkit:
+    mode: "rootless"
```

### 3. Configure any secrets required to publish images

The pro-builder container reads authentication from a standard format Docker config file, which is be mounted into the container as a secret.

For testing, you could bypass authentication on your registry, but for production it is essential to have this enabled to prevent unauthorized access.

Follow the "Registry authentication" section of the [Helm chart README](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder).

The `faas-cli registry-login` command referenced in the above link will create a docker config file like this:

credentials/config.json 

```json
{
 "auths": {
  "registry-service.openfaas.svc.cluster.local:443": {
   "auth": "ZmFrZTp1c2VyCg=="
  }
}
```

You can specify multiple registries if that is needed, most customers only need one entry.

I created my secret with:

``sh
kubectl create secret generic registry-secret \
    --from-file config.json=credentials/config.json -n openfaas
```

### 4. Create the Payload secret

The Function Builder API requires a payload secret which is used by callers to sign their requests. This secret is used to verify the authenticity of the request and to prevent unauthorized access.

```sh
mkdir -p ~/.openfaas

$(openssl rand -base64 32) > ~/.openfaas/payload.txt

kubectl create secret generic payload-secret \
  -n openfaas \
  --from-file payload-secret=~/.openfaas/payload.txt
```

### 3.1 mTLS certificates for Buildkit

For testing, mTLS certificates are not required, however for production, you should follow the additional steps in the [Helm chart README](https://github.com/openfaas/faas-netes/blob/master/chart/pro-builder/README.md).

### 5. Deploy the Function Builder API

```sh
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update
helm upgrade pro-builder openfaas/pro-builder \
    --install \
    --namespace openfaas \
    -f custom.yaml
```

### 6. Publish a test image

The `faas-cli` can be used to publish a test image to the registry, without having to use the Function Builder API directly from your application.

```sh
# Set the OPENFAAS_PREFIX to the registry service within the cluster:
export OPENFAAS_PREFIX=registry-service.openfaas.svc.cluster.local:443

# Create a new test function
faas-cli new --lang node20 test-fn && \
    mv test-fn.yml stack.yml

# Publish the function
faas-cli publish --remote-builder http://127.0.0.1:8081 --payload-secret $HOME/.openfaas/payload.txt
```

Within a few moments you will see the logs from the build returned, along with the image reference, i.e. `registry-service:443/test-fn:latest`.

This is how quickly my Node 20 function was built and published with a warm cache, I only changed the handler.js file:

```diff
'use strict'

module.exports = async (event, context) => {
  const result = {
    'body': JSON.stringify(event.body),
    'content-type': event.headers["content-type"],
+    'build': 1
  }

  return context
    .status(200)
    .succeed(result)
}

```

```sh
...
s: 2024-11-20T15:01:10Z pushing manifest for registry-service:443/test-fn:latest@sha256:d00f194e84a320f1a4a07a252a4846d5cfb0c606bfd9f562578e4f8a4ed649a8 0
2024/11/20 15:01:10 test-fn success building and pushing image: registry-service:443/test-fn:latest
[0] < Building test-fn done in 0.88s.
[0] Worker done.

Total build time: 0.88s

```

Now add a dependency to "axios":

```sh
cd test-fn

# Update package.json
npm i --save axios

# Remove the node_modules directory, since it is added
# via the build itself
rm -rf node_modules
```

Import it in the handler:

```diff
'use strict'

+const axios = require('axios')

module.exports = async (event, context) => {
  const result = {
    'body': JSON.stringify(event.body),
    'content-type': event.headers["content-type"],
    'build': 1
  }

  return context
    .status(200)
    .succeed(result)
}
```

Next, trigger the build again:

```sh
time faas-cli publish --remote-builder http://127.0.0.1:8081/build --payload-secret $HOME/.openfaas/payload.txt


s: 2024-11-20T15:08:34Z pushing manifest for registry-service:443/test-fn:latest@sha256:881f4b1c79cac3da4b5e907fe80b19de55f3c0d3737df1878aac487bad36c3e5 0
v: 2024-11-20T15:08:34Z exporting to image 0.21s
s: 2024-11-20T15:08:34Z pushing manifest for registry-service:443/test-fn:latest@sha256:881f4b1c79cac3da4b5e907fe80b19de55f3c0d3737df1878aac487bad36c3e5 0
2024/11/20 15:08:34 test-fn success building and pushing image: registry-service:443/test-fn:latest
[0] < Building test-fn done in 2.04s.
[0] Worker done.

Total build time: 2.04s
```

We can see the complete build and push time finished within 2s, now this time is broken down into downloading base images (cached), npm's "audit" step (512ms), downloading npm modules (680ms - not cached yet) and pushing the final image (210ms). We can't quite have an instant build, but we can get under 1s when we're only changing the code, and not having to rebuild a binary or bring in new dependencies from an external HTTP server.

### 7. Add a pull secret to authenticate to the registry

In order to deploy the function, a pull secret must be created in the `openfaas-fn` namespace.

Follow the docs for [Private registries](https://docs.openfaas.com/reference/private-registries/). If you used `faas-cli registry-login` when defining the secret for the pro-builder, then the same file can be used again for the pull secret.

For a quick example, this is what I ran in testing:

```sh
kubectl create secret generic \
 -n openfaas-fn \
 tls-registry-pull-secret \
 --from-file=config.json=credentials/config.json

kubectl patch serviceaccount -n openfaas-fn default -p '{"imagePullSecrets": [{"name": "tls-registry-pull-secret"}]}'
```

### 7.1 Trust the CA for pulling images, and update the DNS on each node

A self-hosted registry is simpler if it is run on a VM within the region or cloud account, rather than in-cluster. By running out of cluster, and using Let's Encrypt for the TLS, it means that you can skip this step completely.

In cluster access requires:

* The CA to be trusted on the node itself
* The `registry-service` DNS to resolve to the correct IP address from the node itself

To add the CA, on an Ubuntu-like node, you can run:

```sh
sudo cp ca.crt /usr/local/share/ca-certificates/registry-service.crt
sudo update-ca-certificates
```

You'll find various suggestions on StackOverflow on how to automate this final piece of the puzzle using approaches like a DaemonSet, or other custom tooling.

The next part is slightly more involved.

Look up the IP for kube-dns or CoreDNS:

```sh
kubectl get svc -n kube-system kube-dns
NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
kube-dns   ClusterIP   10.43.0.10   <none>        53/UDP,53/TCP,9153/TCP   211d
```

Update the `/etc/resolv.conf` file to include a new nameserver entry for the IP given, i.e. `10.43.0.10`.

If your machine is using `systemd-resolved`, you may need to update the configuration in `/etc/systemd/resolved.conf` and restart the service.

```diff
[Resolve]
-DNS=8.8.8.8 1.1.1.1
+DNS=8.8.8.8 1.1.1.1 10.43.0.10 
FallbackDNS=8.8.4.4
+Domains=~svc.cluster.local
```

Then run `systemctl restart systemd-resolved`

Now, you the kubelet, which is responsible for running pods, will be able to resolve the DNS for the registry service.

You can test the configuration with the server given explicitly:

```bash
nslookup registry-service.openfaas.svc.cluster.local.svc.cluster.local 10.43.0.10
```

And implicitly:

```bash
nslookup registry-service.openfaas.svc.cluster.local.svc.cluster.local
```

### 8. Deploy the function

Now you're ready to deploy the function:

```sh
faas-cli deploy
```

Check it out:

```bash
faas-cli describe test-fn
echo test | faas-cli invoke test-fn
```

To check for errors, run `kubectl get events -n openfaas-fn -w`.

### Wrapping-up

There are a number of moving pieces involved in configuring the Function Builder API, however, if you are able to run it with the rootless mode, it provides a quick, secure, and powerful way to build code into container images for use with OpenFaaS. OpenFaaS for Enterprises isolates functions using Kubernetes namespaces, the container runtime, read-only filesystems, CPU/RAM requests/limits, and when combined with network policies provides a sandbox to run thousands of functions from customers.

The self-hosted registry not only speeds up publishing images, but it also reduces the time it takes to scale from zero, and horizontally when high load demands more replicas of a given image.

If you're starting out, we still think that a hosted registry in the same region as your Kubernetes cluster is one of the best options, but for those who want the absolute quickest pipeline, a self-hosted registry is the way to go. It is possible to host a registry in-cluster, but as we saw it means updating the CA trust store, and the DNS configuration on each node, which is a manual task and negates some of the benefits of using autoscaling nodes with Kubernetes.

If you need any help or support, or want to try this out with a trial license, please reach out to the team [via the links on the pricing page](https://openfaas.com/pricing).
