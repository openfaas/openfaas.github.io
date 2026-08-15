---
title: "Encrypt build-time secrets for the Function Builder"
description: "Learn how to pass private registry tokens and credentials into the Function Builder, encrypted end-to-end."
date: 2026-03-24
categories:
- kubernetes
- faas
- functions
- builder
- enterprise
dark_background: true
author_staff_member: alex
image: "/images/2026-03-build-secrets/background.png"
hide_header_image: true
---

Learn how to pass private registry tokens, API keys, and certificates into the Function Builder - encrypted end-to-end.

## Introduction

Build secrets are already supported for [local builds and CI jobs](https://docs.openfaas.com/cli/build/#build-time-secrets) using `faas-cli build`. In that workflow, the secret files live on the build machine and are mounted directly into Docker's BuildKit. There's no network transport involved.

The [Function Builder API](https://docs.openfaas.com/openfaas-pro/builder/) is different. It's designed for building untrusted code from third parties  - your customers. A SaaS platform takes user-supplied source code, sends it to the builder over HTTP, and gets back a container image. The build happens in-cluster, without Docker, without root, and without sharing a Docker socket.

```
                           Kubernetes cluster
                          ┌──────────────────────────────┐
  faas-cli /              │                              │
  Your API/dashboard      │  pro-builder      buildkit   │   registry
  ┌───────────────┐       │  ┌──────────┐  ┌──────────┐  │  ┌─────────┐
  │  source code  │──tar──│─▶│  unseal  │──│  build   │──│─▶│  image  │
  │  + sealed     │ HTTP  │  │  secrets │  │  + push  │  │  │         │
  │    secrets    │ HMAC  │  └──────────┘  └──────────┘  │  └─────────┘
  └───────────────┘       │                              │
                          └──────────────────────────────┘
```

The question is: what happens when those builds need access to private resources? A Python function might need to `pip install` from a private PyPI registry. A Node.js function might need packages from a private npm registry. A function might need a private CA certificate to pull dependencies from an internal mirror.

Since the Function Builder launched, most customers haven't needed build-time credentials  - Go users vendor their dependencies, and many teams use public registries. Others have found workarounds where they could. But as platforms mature and customer requirements evolve, the need for private package registries comes up.

[Waylay.io](https://waylay.io) has been using the Function Builder since 2021 to build functions for their industrial IoT and automation platform. As their customers started needing pip modules from private registries, they reached out and we worked together to develop a proper solution. Build secrets use Docker's `--mount=type=secret` mechanism, which means credentials are only available during the specific `RUN` instruction that needs them  - they never end up in image layers and they're not visible in `docker history`. We added NaCl box encryption (Curve25519 + XSalsa20-Poly1305) on top so that secrets are protected over the wire between the client and the builder, even over plain HTTP.

The result is a new feature in the Function Builder that lets you pass secrets into `RUN --mount=type=secret` instructions in your Dockerfiles. The secrets are encrypted client-side by `faas-cli` using the builder's public key, included in the build tar, and decrypted in-memory by the builder just before the build runs. They never appear in image layers, they're never written to disk in plaintext, and they never travel in plaintext over the wire  - even if the connection between your client and the builder is plain HTTP.

## How it works

The builder generates a Curve25519 keypair at startup. The public key is available via a `/publickey` endpoint. When `faas-cli` sends a build with secrets, it:

1. Encrypts each secret value independently using NaCl box
2. Includes the sealed secrets in the build tar as `com.openfaas.secrets`
3. Signs the entire tar with HMAC-SHA256 (as before)

The builder receives the tar, validates the HMAC, extracts the sealed file, decrypts each value using its private key, and passes them to BuildKit as `--mount=type=secret` mounts. After the build, the decrypted values are discarded.

The sealed file format uses per-value encryption with visible key names, so you can see which secrets are included without being able to read their values:

```yaml
version: v1
algorithm: nacl/box
key_id: TrZKmwyy
public_key: TrZKmwyyTHBflZBF98y/j/2vn8wDZsMkX7yvUUGLUUM=
secrets:
    api_key: <encrypted>
    pip_index_url: <encrypted>
```

This means the file is safe to commit to git. You get an audit trail of which keys were added or removed, and you can see when a value has changed by its ciphertext  - all without needing the private key.

## Part A: Setting up the builder with build secrets

The following steps let you try the full workflow on a local KinD cluster before moving to a live environment. You'll need `faas-cli` 0.18.6 or later, `helm`, `kubectl`, `kind`, and an OpenFaaS for Enterprises license.

### Create a test cluster

```bash
kind create cluster --name build-secrets-test
```

### Create the namespace and license secret

```bash
kubectl create namespace openfaas

kubectl create secret generic openfaas-license \
  -n openfaas \
  --from-file license=$HOME/.openfaas/LICENSE
```

### Create a registry credential secret

For testing, we'll use [ttl.sh](https://ttl.sh) which is a free ephemeral registry that doesn't require authentication:

```bash
cat <<'EOF' > ttlsh-config.json
{"auths":{}}
EOF

kubectl create secret generic registry-secret \
  -n openfaas \
  --from-file config.json=./ttlsh-config.json
```

For a private registry, see the [helm chart README](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder) for how to configure authentication.

### Generate secrets

Two things are needed: a keypair for encrypting build secrets, and a payload secret for HMAC request signing.

```bash
faas-cli secret keygen
faas-cli secret generate -o payload.txt
```

```
Wrote private key: key
Wrote public key:  key.pub
Key ID:            TrZKmwyy
```

### Create the Kubernetes secrets

```bash
kubectl create secret generic -n openfaas \
  payload-secret --from-file payload-secret=payload.txt

kubectl create secret generic -n openfaas \
  pro-builder-build-secrets-key --from-file key=./key
```

### Deploy the builder

```bash
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update

helm upgrade pro-builder openfaas/pro-builder \
  --install -n openfaas \
  --set buildSecrets.privateKeySecret=pro-builder-build-secrets-key
```

Wait for it to be ready:

```bash
kubectl rollout status deployment/pro-builder -n openfaas
```

### Verify

Port-forward and check the public key endpoint:

```bash
kubectl port-forward -n openfaas deploy/pro-builder 8081:8080 &

curl -s http://127.0.0.1:8081/publickey | jq
```

```json
{
  "key_id": "TrZKmwyy",
  "algorithm": "nacl/box",
  "public_key": "TrZKmwyyTHBflZBF98y/j/2vn8wDZsMkX7yvUUGLUUM="
}
```

The `key_id` is derived from the public key automatically. You don't need to configure it. The builder is ready.

## Part B: Building a function with secrets

Let's walk through a complete example. We'll create a function that reads a secret at build time using the classic watchdog.

### Create the function

```bash
faas-cli new --prefix ttl.sh/test-build-secrets \
  --lang dockerfile sealed-test
```

Replace `sealed-test/Dockerfile` with:

```Dockerfile
FROM ghcr.io/openfaas/classic-watchdog:latest AS watchdog

FROM alpine:3.22.0

COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog

RUN mkdir -p /home/app

RUN --mount=type=secret,id=api_key \
    cat /run/secrets/api_key > /home/app/api_key.txt

ENV fprocess="cat /home/app/api_key.txt"

CMD ["fwatchdog"]
```

The `--mount=type=secret,id=api_key` line tells BuildKit to mount the secret at `/run/secrets/api_key` during that `RUN` step. It's only available during the build  - it doesn't end up in any image layer.

Create a file to hold the secret value:

```bash
mkdir -p .secrets
echo -n "sk-live-my-secret-key" > .secrets/api_key.txt
```

Edit `stack.yaml` to add `build_secrets`. The values must be file paths — `faas-cli` reads the file contents before sealing and sending them to the builder:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  sealed-test:
    lang: dockerfile
    handler: ./sealed-test
    image: ttl.sh/test-build-secrets/sealed-test:2h
    build_secrets:
      api_key: .secrets/api_key.txt
```

### Build with the remote builder

If you don't already have the payload secret file locally, fetch it from the cluster:

```bash
export PAYLOAD=$(kubectl get secret -n openfaas payload-secret \
  -o jsonpath='{.data.payload-secret}' | base64 --decode)
echo $PAYLOAD > payload.txt
```

If you don't have the public key file, fetch it from the builder:

```bash
curl -s http://127.0.0.1:8081/publickey | jq -r '.public_key' > key.pub
```

Then publish:

```bash
faas-cli publish \
  -f stack.yaml \
  --remote-builder http://127.0.0.1:8081 \
  --payload-secret ./payload.txt \
  --builder-public-key ./key.pub
```

The secrets are encrypted by `faas-cli` before sending. You'll see the build logs streamed back:

```
[0] > Building sealed-test.
Building: ttl.sh/test-build-secrets/sealed-test:2h with dockerfile template. Please wait..
2026-03-24T11:15:13Z [stage-1 2/4] COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
2026-03-24T11:15:13Z [stage-1 3/4] RUN mkdir -p /home/app
2026-03-24T11:15:13Z [stage-1 4/4] RUN --mount=type=secret,id=api_key ...
2026-03-24T11:15:14Z exporting to image
sealed-test success building and pushing image: ttl.sh/test-build-secrets/sealed-test:2h
```

### Verify

Run the image and invoke the watchdog:

```bash
docker run --rm -d -p 8081:8080 --name sealed-test \
  ttl.sh/test-build-secrets/sealed-test:2h

curl -s http://127.0.0.1:8081

docker stop sealed-test
```

```
sk-live-my-secret-key
```

The secret was encrypted on the client, sent over the wire inside the build tar, decrypted by the builder, and mounted into the Dockerfile during the build.

### A real-world example: private PyPI registry

In production, you'd use this to pass credentials for private package registries. Here's what that would look like for a Python function using the `python3-http` template.

Create a file with the index URL:

```bash
echo -n "https://token:pypi-secret@my-org.jfrog.io/artifactory/api/pypi/python-local/simple" > .secrets/pip_index_url.txt
```

In your `stack.yaml`, point `build_secrets` to the file:

```yaml
functions:
  data-processor:
    lang: python3-http
    handler: ./data-processor
    image: registry.example.com/data-processor:latest
    build_secrets:
      pip_index_url: .secrets/pip_index_url.txt
```

Then in the template's Dockerfile, you'd change the `pip install` line to mount the secret:

```diff
-RUN pip install --no-cache-dir --user -r requirements.txt
+RUN --mount=type=secret,id=pip_index_url \
+    pip install --no-cache-dir --user \
+    --index-url "$(cat /run/secrets/pip_index_url)" \
+    -r requirements.txt
```

The same pattern works for npm, Go private modules, or any package manager that takes credentials at install time.

Binary values like CA certificates are also supported. You can seal them from files instead of literals:

```bash
faas-cli secret seal key.pub \
  --from-file ca.crt=./certs/internal-ca.crt \
  --from-literal pip_index_url=https://token:secret@registry.example.com/simple
```

## Sealing secrets for CI pipelines

If you're integrating with a CI system rather than using `faas-cli publish` directly, you can seal secrets into a file ahead of time:

```bash
faas-cli secret seal key.pub \
  --from-literal api_key=sk-live-my-secret-key
```

This writes `com.openfaas.secrets` in the current directory. Include it in the build tar alongside `com.openfaas.docker.config` and the `context/` folder, and the builder will pick it up.

You can inspect a sealed file without the builder:

```bash
faas-cli secret unseal key
```

```
api_key=sk-live-my-secret-key
```

## New faas-cli commands

We've added four new subcommands to `faas-cli secret`:

| Command | Purpose |
|---------|---------|
| `faas-cli secret keygen` | Generate a Curve25519 keypair |
| `faas-cli secret generate` | Generate a random secret value for the pro-builder's HMAC signing key |
| `faas-cli secret seal key.pub --from-literal k=v` | Seal secrets into `com.openfaas.secrets` |
| `faas-cli secret unseal key` | Decrypt and inspect a sealed file (requires access to the private key) |

## Wrapping up

Build secrets for local builds and CI have been available for a while via the `faas-cli`. This feature brings the same capability to the Function Builder API, where builds happen in-cluster on behalf of third-party users and the secrets need to be protected over the wire.

We developed this together with [Waylay](https://waylay.io) based on their production requirements, using NaCl box encryption to protect secrets over the wire. The `seal` package in the [Go SDK](https://github.com/openfaas/go-sdk) is generic and could be reused for other use-cases in the future.

If you're already using the Function Builder, you can start using build secrets by upgrading the helm chart and `faas-cli`. If you're new to the builder, see the [Function Builder API docs](https://docs.openfaas.com/openfaas-pro/builder/) for the full setup guide.

If you have questions, feel free to [reach out to us](https://openfaas.com/pricing).

### See also

* [Function Builder API docs](https://docs.openfaas.com/openfaas-pro/builder/)
* [Go SDK `seal` package](https://github.com/openfaas/go-sdk/tree/master/seal)
* [Pro-builder Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/pro-builder)
* [How to Build Functions with the Go SDK for OpenFaaS](https://www.openfaas.com/blog/building-functions-via-api-golang/)
