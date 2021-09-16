---
title: "Deploy OpenFaaS to Linode with K3sup"
description: "Learn how to deploy OpenFaaS to Linode using a virtual machine and K3sup"
date: 2021-09-16
image: /images/2021-06-kubectl-functions/background.jpg
categories:
 - cloud
 - hosting
 - functions
 - kubernetes
author_staff_member: alex
dark_background: true

---

Learn how to deploy OpenFaaS to Linode using a virtual machine and K3sup.

## Introduction

It's easy to run OpenFaaS on your desktop machine using a virtual machine and faasd or Docker Desktop and a local Kubernetes tool like KinD, K3d or Minikube. But what if you want to share your OpenFaaS functions with colleagues or clients? What if you want to host a few functions on the Internet or want to do load testing on a public cloud?

Where you decide to deploy OpenFaaS will be heavily dependent on whether you have complimentary credits, or a preferred cloud provider. Most providers, both big and small have their own managed Kubernetes solutions, however these can have drawbacks - running several nodes for testing can be expensive and can restrict technology choices such as network drivers or security policies.

<img src="https://raw.githubusercontent.com/alexellis/k3sup/master/docs/assets/k3sup.png" width="30%" alt="K3sup">

In this brief article, I want to show you how to launch OpenFaaS on a VM on [Linode](https://www.linode.com/openfaas) using K3sup ("ketchup") and K3s. K3s is a production ready distribution of Kubernetes that runs just as well in the cloud as on an IoT device such as a Raspberry Pi.

> Why Linode? [Linode](https://www.linode.com/openfaas) is a developer cloud, that also has enterprise and multi-cloud customers and earlier this year they opted to sponsor our homepage for 6 months. Linode also sponsor the Changelog, and we would like to thank them for supporting our work with OpenFaaS.

You can learn more about K3s in the course I wrote for the LinuxFoundation: [Introduction to Kubernetes on Edge with k3s (LFS156x)](https://training.linuxfoundation.org/training/introduction-to-kubernetes-on-edge-with-k3s-lfs156x/)

K3sup is a K3s installer that works over SSH, and at the end of the installation merges the cluster's configuration file into your local one, so that you can use `kubectl` remotely. The idea with Kubernetes is that all of your nodes - whether masters or workers, should be left well alone, and rarely logged into for any kind of administrative activity.

<img src="https://raw.githubusercontent.com/alexellis/k3sup/master/docs/k3sup-cloud.png" width="70%" alt="K3sup conceptual diagram">

> K3sup can install K3s to a single machine, or be used to form a cluster - all over SSH.

## Tutorial

This tutorial should take you less than 10-15 minutes and at the end of it, you'll be able to play with your new cluster on the Internet.

I'll give you two options - the first will let you use OpenFaaS just like a local environment, and the second will also install an Ingress definition and configure a TLS certificate from Let's Encrypt.

### Create an account on Linode

You will need to [create an account on Linode](https://www.linode.com/openfaas)

Next, add your local SSH key to your Linode account. You can generate an SSH key using the `ssh-keygen` command.

### Create a VM on Linode

Linode calls its Virtual Machines "Linodes", so log in and open your dashboard. Then click "Linodes" and "Create Linode".

Pick *Ubuntu 21.04* for the Operating system.

Pick a region that is close to where you live

Next, pick a Linode Plan. If you want to make this as cheap as possible, you can click "Shared CPU" and then pick either: Nanode 1 GB ($5/mo) or Linode 2 GB ($10/mo).

Linode Label is the field where you fill out the hostname, so write: `openfaas-k3s-server1`. Optionally, you could also add a tag such as `k3s` or `openfaas`.

It's important that you add an SSH key for use with K3sup, you also need to set a root password.

![Create the Linode](/images/2021-09-linode/linode-create.jpg)

Take a note of the IP address:

```bash
export IP="212.71.247.60"
```

### Pre-reqs

One of the tools that will make this tutorial much quicker is [arkade](https://arkade.dev). Arkade can install CLI apps just about as quickly as is possible and 40+ Kubernetes applications too. It doesn't do anything exotic, and relies on Helm charts, YAML files or bespoke CLI installers from various open source projects.

You are of course welcome to do things the long way.

```bash
# If you do not want to use sudo, simply remove it
# and move the arkade binary to /usr/local/bin after
# execution
curl -sLS https://get.arkade.dev | sudo sh
```

```bash
arkade get kubectl
arkade get k3sup
arkade get faas-cli
```

The above will download the CLI for kubectl (Kubernetes CLI), k3sup (K3s installer) and faas-cli (the OpenFaaS CLI).

### Install K3s using K3sup

[K3sup](https://k3sup.dev/) is a K3s installer that works over SSH. Its primary goal is to make installation a breeze through automation, abstracting away complicated options and synchronising your Kubeconfig file which is used by kubectl to contact the cluster.

It also makes multi-node installation of K3s much quicker though an install and join command.

Now install K3s:

```bash
export IP="212.71.247.60"
export USER="root"  # This user may be "ubuntu" on other providers

k3sup install --ip $IP \
  --user $USER \
  --local-path $HOME/.kube/config \
  --merge \
  --context linode-openfaas
```

You'll see some output like the following:

```bash
Running: k3sup install
2021/09/16 11:47:13 212.71.247.60
Public IP: 212.71.247.60
[INFO]  Finding release for channel v1.19
...
Merging with existing kubeconfig at /home/alex/.kube/config
Saving file to: /home/alex/.kube/config

# Test your cluster with:
export KUBECONFIG=/home/alex/.kube/config
kubectl config set-context linode-openfaas
kubectl get node -o wide
```

If you want to install a specific version or the latest version of K3s, see the `k3sup install --help` command which explains how to specify a version (`--k3s-version`) or channel (`--k3s-channel`). Channels correspond to a conceptual version such as `stable` or `latest`.

After installation, you'll be able to switch to the next context to use `kubectl` remotely:

```bash
kubectl config set-context linode-openfaas
kubectl get nodes -o wide
```

Example output:

```bash
NAME                 STATUS   ROLES    AGE    VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                                     KERNEL-VERSION     CONTAINER-RUNTIME
kind-control-plane   Ready    master   2d1h   v1.19.1   172.20.0.2    <none>        Ubuntu Groovy Gorilla (development branch)   5.4.0-84-generic   containerd://1.4.0
```

At this point you can use `kubectl` and `helm` on your cluster just like you would if it was running locally.

### Install OpenFaaS

You can use helm or arkade to install OpenFaaS.

We have [detailed instructions here](https://docs.openfaas.com/deployment/kubernetes/)

```bash
arkade install openfaas
```

You can now use `faas-cli` against your cluster using port-forwarding the OpenFaaS gateway. See `arkade info openfaas` for more details.

Or continue with the tutorial to install a TLS certificate and map it to a custom sub-domain.

### Configure an Ingress Controller and TLS certificate

K3s ships with the [Traefik](https://traefik.io) [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/) built-in, you can change this to ingress-nginx or an alternative if you wish. The [K3sup readme](https://k3sup.dev/) has notes on how to avoid installing K3s' default extras such as Traefik.

Install cert-manager which will obtain TLS certificates for your installation:

```bash
arkade install cert-manager
```

Next create a DNS A or CNAME record for the IP address of your Linode VM and your subdomain, such as:

```
faas.example.com    212.71.247.60
```

The following arkade app generates an Ingress definition for OpenFaaS:

```bash
export DOMAIN="exit.o6s.io"

arkade install openfaas-ingress \
    --email webmaster@$DOMAIN \
    --domain faas.$DOMAIN \
    --ingress-class traefik
```

Note the custom `--ingress-class` flag for K3s' Traefik IngressController.

Then you will be able to access OpenFaaS via the subdomain `faas.example.com`.

Find your password:

```bash
PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode; echo)

echo $PASSWORD
```

Log in via the CLI:

```bash
echo -n $PASSWORD | faas-cli login \
    --gateway https://faas.$DOMAIN \
    --password-stdin
```

Or open a browser using the subdomain i.e. https://faas.example.com

If you receive an error, then it could be because your DNS record is still being propagated around the Internet.

After a few minutes, if you're still not getting a valid certificate, see the following for debug information: `arkade info openfaas-ingress`

## Wrapping up

You now have OpenFaaS set up with a K3s cluster and a single server. You can add other servers or agents to the cluster by following the same steps above, but using the `k3sup join` command instead. If you followed all of the instructions, then you'll now have a TLS certificate and any traffic between your functions and your users will be encrypted.

![OpenFaaS Portal with TLS](/images/2021-09-linode/portal-tls.png)

In the above example, I could access the `env` function using its full URL of `https://faas.exit.o6s.io/function/env`

> If you would rather run OpenFaaS on an on-premises server, a Raspberry Pi, or your laptop, then you can do so and still get all of the benefits above through a secure HTTPS tunnel. Learn how with inlets: [Expose your local OpenFaaS functions to the Internet](https://inlets.dev/blog/2020/10/15/openfaas-public-endpoints.html)

We didn't create a K3s cluster with multiple nodes today, but K3s and K3sup support that and have several options for configuration. You can learn more about K3s and K3sup in the course I mentioned above: [Introduction to Kubernetes on Edge with k3s (LFS156x)](https://training.linuxfoundation.org/training/introduction-to-kubernetes-on-edge-with-k3s-lfs156x/)

[Linode](https://www.linode.com/openfaas) reminds me of other developer clouds, but the marketing team told me that they see their platform being used for multi-cloud deployments. That would mean that a company may deploy both to AWS and Linode, or GCP and Linode. I found their UI easy to use and fast to provision a Kubernetes cluster with K3s. They also have a managed Kubernetes service called LKE which you could try in a similar way for a multi-node cluster and a managed control-plane.

Disclosure: Linode sponsored the OpenFaaS homepage for 6 months. Other cloud providers are available.

### Getting in touch and supporting our work

Do you have questions, comments or suggestions? Why not [join us in the OpenFaaS Slack community](https://slack.openfaas.io)?

> Want to support our work? You can become a sponsor as an individual or a business via GitHub Sponsors with tiers to suit every budget and benefits for you in return. [Check out our GitHub Sponsors Page](https://github.com/sponsors/openfaas/)
