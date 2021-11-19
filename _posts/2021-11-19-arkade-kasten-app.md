---
title: "Announcing The Kasten App for Arkade"
description: "Alex walks you through the new Arkade app for Kasten's Data Protection solution for Kubernetes"
date: 2021-11-19
image: /images/2021-11-kasten/background.jpg
categories:
 - arkade
 - sponsoredapp
 - marketplace
 - backup
author_staff_member: alex
dark_background: true

---

Alex walks you through the new Arkade app for Kasten's data protection solution for Kubernetes

I'm excited to announce that Kasten's App is now available in arkade via the `arkade kasten install` command. In this article, I'll recap the problem that arkade sets out to solve and explain why Kasten approached us to have their product added to our marketplace. I'll also cover what the use-case is for Kasten, so you can evaluate whether it should be part of your data protection strategy.

## Introduction to arkade

[Arkade](https://arkade.dev/) is an open-source marketplace for Kubernetes developers. Unlike cloud marketplaces, it works the same way on both local and cloud clusters and developers can contribute their favourite apps for easy discovery, sharing and installation.

<img src="https://raw.githubusercontent.com/alexellis/arkade/master/docs/arkade-logo-sm.png" width="30%" alt="Arkade logo" />

When first encountering a tool like arkade, developers tend to ask: "why would I use this instead of helm?" and that's an important question.

Whenever I install a chart with helm it involves finding the project homepage, which is easier said than done, then reading through 20-200 different configuration values to find out how to set persistence, ingress, load-balancers, HA and various other options. Once I actually have that in place, I have to find the command to add the chart repo, update my charts, and install with a custom values.yaml file or a lengthy set of flags.

Arkade changes that to:

```bash
arkade install ingress-nginx
```

Or to install OpenFaaS with a cloud load balancer and 3 HA replicas of its gateway:

```bash
arkade install openfaas \
  --load-balancer \
  --gateways 3
```

After installing an app, commands are printed out which explain how to use it, check it and get started. Sometimes these instructions are more helpful than those offered in the project's documentation. At any time you can run `arkade info APP` to get that information back again. With helm, you have to install the chart again.

Combinations of apps can be installed for a compounding effect.

Think how long it would actually take you to navigate all the various helm chart README files to figure out how to install a simple stack with Ingress, TLS certs, OpenFaaS, backend storage and Kasten for data protection and backup.

Here's how it looks with arkade, and if you're building a lab or working locally, the defaults we've picked for each app are probably more than sufficient for your work.

```bash
arkade install ingress-nginx
arkade install cert-manager
arkade kasten install k10
arkade install openfaas
arkade install postgresql
```

Now, if we were only talking about helm for all of the Kubernetes and CNCF ecosystem, perhaps you could live without arkade. But not all apps are distributed with helm, for instance Istio moved to a CLI `istioctl` as its default installation method, Linkerd is very similar. For MetalLB, there are only static YAML manifest files that you can apply.

> The role of an arkade app is to abstract away this complexity and help you get software installed quickly.

The second feature of arkade is its ability to download CLI tools that are needed for DevOps, such as kubectl, kubectx, faas-cli, istioctl, helm, stern, kail, terraform, etc. The list goes on. In fact there are dozens of CLI tools defined in arkade, which have been added by users of the tool. Why use it instead of brew or apt-get? It's always up to date, and is much faster to use because it only downloads binaries for your system from a set of rules.

It's [a growing open source project](https://github.com/alexellis/arkade) with 2.3k stars, 160 releases and 59 contributors. You can read the story of how arkade has evolved and about its community over the past two years here: [Two year update: Building an Open Source Marketplace for Kubernetes](https://blog.alexellis.io/kubernetes-marketplace-two-year-update/)

## Kasten's App

There are a few criteria for adding an app to arkade, and most of the time it needs to be a project that's open source and free to use. It turns out that commercial products also have complex helm charts, that could be made easier to use with arkade.

> For that reason we introduced the idea of a Sponsored App and the first one was added for [Venafi](https://venafi.com) to bring Venafi's machine identity add-ons for cert-manager to developers in a more accessible way: [Announcing Venafi Sponsored Apps for Arkade](https://www.openfaas.com/blog/arkade-venafi/).

![Kasten logo](/images/2021-11-kasten/kasten.svg)

[Kasten](https://kasten.io/) by [Veeam](https://www.veeam.com/) is a data protection solution or Kubernetes.

Kasten can back up and restore data from within your Kubernetes cluster, but it's more than that. Not only can it copy Persistent Volumes off-site for backup purposes, it also has an integration with the Container Storage Interface (CSI). Why would that be important? CSI supports snapshots which means saving on costs, time and bandwidth vs. copying all data whether it's changed or not.

The core use-cases are: 
* backup and restore - the classic backup use-case, applied intelligently to Kubernetes with CSI
* disaster recovery - the ability to restore applications back to their state in the wake of an unfortunate event
* application mobility - not only back up data, but migrate it between clouds i.e. from AWS to GCP

In the Sponsored App project, we worked closely with [Michael Cade, Senior Technologist at Veeam](https://vzilla.co.uk/) and [Vaibhav Kamra, CTO of Kasten](https://www.linkedin.com/in/vaibhavkamra/).

Given half a dozen installation guides for various clouds, and separate instructions for local installation of Kasten, we wanted to consolidate the experience into a couple of CLI commands. This involved creating a new command for arkade `arkade kasten` and a few sub-commands that we'll get into below.

Kasten also had about 3-5 CLI commands that were useful for Kasten operators, so we added those via `arkade get` as separate downloads.

### Data protection demo

We'll set up Minikube with CSI enabled, the install K10 using the sponsored app and turn it over to you to follow a Kasten tutorial for installing an app and seeing the data protection in action.

The best way to try out Kasten is probably with [Minikube](https://minikube.sigs.k8s.io/docs/start/), because Minikube includes support for the CSI add-on. That's where the smarts of Kasten show through.

```bash
arkade get minikube@v1.21.0 \
  kubectl@v1.22.0
```

I recommend running minikube within a Docker container, or if you're on a Mac, you can also use the faster, lighter-weight hypervisor (HyperKit) instead of VirtualBox. See the various "drivers" here: [Configuring various minikube drivers](https://minikube.sigs.k8s.io/docs/drivers/)

Enable the CSI add-on for minikube.

Now start the cluster, and check the cluster is ready:

```bash
minikube start \
    --addons volumesnapshots,csi-hostpath-driver \
    --apiserver-port=6443 \
    --container-runtime=containerd \
    --kubernetes-version=1.21.2 \
    -p arkade

kubectl get node
kubectl get pod
```

> Note: at this time, Kasten doesn't support Kubernetes 1.22, but support is on the way.

## Set up the CSI Hostpath VolumeSnapshotClass for use with K10

```bash
kubectl annotate volumesnapshotclass csi-hostpath-snapclass \
    k10.kasten.io/is-snapshot-class=true
```

We also need to change the default StorageClass to the csi-hostpath-snapclass.

```bash
kubectl patch storageclass csi-hostpath-sc \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

kubectl patch storageclass standard \
    -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
```

A future enhancement for arkade may be to create a custom command to run the above commands.

## Pre-flight checks

Now check that the Kasten app can run successfully, and that everything is configured as required.

There is a bash script provided online, but we made it easier to find with an app:

```bash
arkade kasten install preflight
```

You'll get a summary at the end of the preflight run and notifications for anything that you need to change.

If you don't like running bash over the Internet, then you can also read exactly what the preflight checks are by running the following command:

```bash
arkade kasten install preflight --dry-run
```

It'll then print out the script that would be run for inspection.

The `arkade kasten install preflight --help` command will link you directly to the Kasten docs for further reading too.

```bash
Run pre-flight checks for Kasten's Backup and Migration solution
Read more at:

https://docs.kasten.io/latest/install/requirements.html#pre-flight-checks

Usage:
  arkade kasten install preflight [flags]

Flags:
      --dry-run   Print the commands that would be run by the preflight script.
  -h, --help      help for preflight
```

## Install K10 with its new app

```bash
arkade kasten install k10 \
  --token-auth
```

The `--token-auth` flag maps to the helm configuration of `auth.tokenAuth.enabled` and acts as a convenient short-hand. This allows a Kubernetes service account secret to be used for authentication instead of basic auth, which would be the default otherwise. You'll find the same approach taken by the community Kubernetes dashboard, also available via arkade.

Kasten is enterprise-grade software, so it brings its own control-plane and data-plane components which will take a few moments to download and initialise.

You can watch the progress:

```bash
kubectl get pods --namespace kasten-io -w
```

## Check out the dashboard

Fetch the token for the Kasten dashboard.

The name is not stable, so you must first run the following command to get the name of the token, then run another command to fetch its value.

```bash
TOKEN_NAME=$(kubectl get secret --namespace kasten-io|grep k10-k10-token | cut -d " " -f 1)
TOKEN=$(kubectl get secret --namespace kasten-io $TOKEN_NAME -o jsonpath="{.data.token}" | base64 --decode)

echo "Token value: "
echo $TOKEN
```

The secret name `k10-k10-token-random-characters` can change and doesn't have a stable name at this time, so bear this in mind, if you do install Kasten with helm or a GitOps tool like ArgoCD or FluxCD in the future.

The next step is to open the Kasten UI:

```bash
kubectl port-forward --namespace kasten-io \
  service/gateway 8080:8000
```

Then open a local browser at: `http://127.0.0.1:8080/k10/#/` - don't forget the path `/k10/#/`.

Paste in the token from the previous step.

You'll need to accept a EULA, but there are also flags in the helm chart for this such as `--set eula.accept=true`, `--set eula.company` and `--set eula.company.email`. Setting these flags can be helpful for automation, we support the first flag as a shortcut in arkade via `--eula true`.

![Initial UI](/images/2021-11-kasten/initial-min.png)

> Initial UI after logging in.

At this point, Kasten has been installed, and is ready to be used. We can now go ahead and deploy our applications, configure a target for backup such as Minio, if running on-premises, or an S3-compatible cloud storage bucket.

## Wrapping up

Since we started the project, [Kasten's helm chart](https://docs.kasten.io/latest/install/advanced.html?highlight=helm%20values#complete-list-of-k10-helm-options) and software has continued to grow and change, including their various CLIs. As a result, we are ready and waiting to patch arkade and improve it to support users, which is all part of the Sponsored App subscription. From writing this tutorial, several months after completing the app, it's clear that we can now automate even more of the manual steps in arkade, and add new CLI flags to make installation less verbose.

Having written software targeted at developers for most of my career, it's clear that having a good onboarding experience is important. The mean time to dopamine (MTTD) should be as low as possible, because ultimate, we shouldn't just want developers to install our tools, but to use them, understand the value and become raving fans.

### Onward journey

If you're an OpenFaaS user already, why not deploy Postgresql using `arkade install postgresql`? Followed by the example from Serverless For Everyone Else that shows you how to do data-access from within a function. Then, back up and restore the data volume for Postgresql using Kasten.

Perhaps OpenFaaS isn't something that you use at work just yet. You can do much more than back up volumes, including migrating between clouds using the [K10 Multi-Cluster Manager](https://docs.kasten.io/latest/multicluster/index.html) and set up a plan for [Disaster Recovery](https://docs.kasten.io/latest/operating/dr.html). The multi-cluster CLI can be downloaded via `arkade get k10multicluster`.

To see what other apps are available in arkade or to propose your own, check it out on GitHub: [alexellis/arkade](https://github.com/alexellis/arkade)

For more on Kasten, check out their excellent documentation: [docs.kasten.io](https://docs.kasten.io/latest/index.html)

Don't miss our upcoming live-stream where Michael will join me in person to walk-through a demo and show arkade and Kasten in action on our Kubernetes clusters.

Hit Subscribe & Remind below, or if you're watching this after the 7th December 2021, you can watch the recording.

{% include youtube.html id="zJA4_NRneOM" %}

