---
title: "Why did the OpenFaaS community build arkade and what's in it for you?"
description: "The OpenFaaS community is building a tool for Kubernetes developers, learn how it can help you install OpenFaaS, along with complementary CLIs and applications to your cluster"
date: 2020-08-13
image: /images/2020-openfaas-arkade/briana.jpg
categories:
  - kubernetes
  - developers
  - tools
author_staff_member: alex
dark_background: true

---

The OpenFaaS community is building a tool for Kubernetes developers, learn how it can help you install OpenFaaS, along with complementary CLIs and applications to your cluster

<a href="https://arkade.dev"><img src="https://raw.githubusercontent.com/alexellis/arkade/master/docs/arkade-logo-sm.png" alt="arkade logo" width="300" height="300"></a>

> [arkade](https://arkade.dev) - Portable Kubernetes marketplace

## Solving pain

The popular essay [Cathedral and the Bazaar](http://www.catb.org/~esr/writings/cathedral-bazaar/cathedral-bazaar/) was written over 20 years ago by author and then open source activist Eric Steven Raymond. In it, he contrasts the development of proprietary software within a corporation (the cathedral) to that of an open-source model (the bazaar). One of the key points he makes is that most open-source software starts when a developer has an itch they need to scratch or finds a pain-point that they can solve.

[arkade](https://arkade.dev) has evolved since it was first created to install OpenFaaS, to now install 40 different applications using their preferred installation method.

* OpenFaaS - [helm3](https://helm.sh)
* Linkerd - its own CLI
* Portainer - a static YAML manifest file

It then gained the ability to install CLIs such as `faas-cli`, `terraform`, `kubectx`, `helm` and `kubectl` which are relatively easy to find, but when you need 3-5 of these over the course of a short tutorial, it breaks the flow.

> I once gave a workshop on OpenFaaS for new Kubernetes users, and it took them 1.5h-2h just to install a few CLIs and start a managed cluster on DigitalOcean. This tool makes that whole workflow much, much faster.

Now if you're anything like us, then you will be re-creating a cluster several times per day or per week to test a PR or change to your project, you may even be creating a cluster in a CI job to test each incoming commit. arkade is built for developers to rapidly get a working system with whatever they need. You can use it in production, or in a pipeline, but you may find that a GitOps style more suitable using a tool like [ArgoCD](https://argoproj.github.io/argo-cd/) or [Flux](https://fluxcd.io).

> ⭐️ Star/fork [arkade](https://arkade.dev) on GitHub

### Helm 2 - insecure by default

Since around 2017, OpenFaaS was packaged with a [helm](https://helm.sh) chart, and back in those days, you used to have to install a very insecure component to your cluster ([Tiller](https://v2.helm.sh/docs/install/)), which ran in a kind of "God mode." If someone accessed Tiller, and it was very easy to do so, then it would be game over. This wasn't just a problem for OpenFaaS, but for any other helm chart you wanted to install.

Fortunately DevOps professionals had identified a series of 3-5 additional steps that meant you could avoid using Tiller. This involved: fetching a compressed archive and then running a "template" command, which generated plain YAML files, which could be applied using `kubectl`. In addition to these commands, one had to add the specific helm chart repository, synchronise it and do a few other tasks like creating namespaces.

I wrote some code to automate all of this and packaged in a tool called `k3sup` as `k3sup app install openfaas`. The short story is that many users were confused about the `k3sup` and its link to `k3s` naming and so this code was spun out into a new project called `arkade`.

> This is the same reason that `arkade` is not hosted in the openfaas organisation. Many users adopting Kubernetes could benefit from a platform like OpenFaaS that makes it very simple to get an endpoint up and running without worrying about boiler-plate code, however my fear is that if arkade lived in the openfaas organisation on GitHub, folks would dismiss it as being exclusively for or part of OpenFaaS, which it is not.

We recently removed the code to support Helm2 and YAML templating, because Helm 3 arrived and made installation more secure, and easier to use. The Helm 3 binary can still template YAML, but we have not seen much demand for it.

### Who's building arkade?

The OpenFaaS community is working on several tools and projects, and I've enjoyed seeing contributors starting out with one tool and then helping out on something completely different.

Within the community you'll find us working on openfaas, arkade, [inlets](https://inlets.dev) - Cloud Native Tunnel, [k3sup](https://k3sup.dev) - k3s installer over SSH and [Derek](https://github.com/alexellis/derek) - reducing maintainer fatigue, to find out more about each, checkout the [pinned projects on my GitHub account](https://github.com/alexellis/).

arkade is being "seeded" by the OpenFaaS community, but we are now seeing PRs and issues from upstream projects like cert-manager and Istio. This, along with the mounting number of downloads, GitHub stars, and blog posts is encouraging us to keep pressing on.

### What's in a name?

Why arkade? It's very difficult to come up with naming, and we wanted to have something that loosely fitted with the nautical theme. An arcade (k for Kubernetes) is according to Oxford Languages: "a covered passage with arches along one or both sides." Arcades such as those in Milan and Covent Garden, in London are also filled with various kinds of shops, so this seemed to fit well with the idea of making apps easier to find for Kubernetes developers.

### Discovering charts and their many options

One of the main reasons to use a helm chart over plain Kubernetes manifest files is that they can be updated, fine-tuned, and edited by passing in a series of `--set` commands, or by editing a supplementary YAML file. Why would you do that? Well Kubernetes is a system designed to offer many configuration options, and users tend to need to do things like change the way networking works, alter security settings, or to update a container image when deploying.

Let's say we wanted to install Postgresql? The typical approach goes like this: open Google, type in "Postgresql chart", see 3-5 options - one that looks semi-official, one that's from Bitnami, one from Red Hat, two or three from hobbyists. You roll the dice, and pick one. Then you have to add its helm chart repo, synchronise, and trawl the README file for all the various `--set` options.

> Note: you can find a list of apps via `arkade install --help`

Some charts come with fairly good defaults, but up until recently, something you always had to change for local Kubernetes was whether persistence was enabled. In addition, you may also need to override any networking settings that create a LoadBalancer, these don't tend to work on a local cluster.

It's not uncommon to be faced with 20-50 options in a long README file. arkade makes the decision easy by picking an opinionated helm chart source, it then goes further and only allows configuration via flags, which we hard-code, so that you can discover them via `arkade install APP --help`

Here's the example for OpenFaaS:

```bash
$ arkade install openfaas --help
Install openfaas

Usage:
  arkade install openfaas [flags]

Examples:
  arkade install openfaas --loadbalancer

Flags:
  -a, --basic-auth                    Enable authentication (default true)
      --basic-auth-password string    Overide the default random basic-auth-password if this is set
      --clusterrole                   Create a ClusterRole for OpenFaaS instead of a limited scope Role
      --direct-functions              Invoke functions directly from the gateway (default true)
      --function-pull-policy string   Pull policy for functions (default "Always")
      --gateways int                  Replicas of gateway (default 1)
  -h, --help                          help for openfaas
      --ingress-operator              Get custom domains and Ingress records via the ingress-operator component
  -l, --load-balancer                 Add a loadbalancer
      --log-provider-url string       Set a log provider url for OpenFaaS
      --max-inflight int              Max tasks for queue-worker to process in parallel (default 1)
  -n, --namespace string              The namespace for the core services (default "openfaas")
      --operator                      Create OpenFaaS Operator
      --pull-policy string            Pull policy for OpenFaaS core services (default "IfNotPresent")
      --queue-workers int             Replicas of queue-worker for HA (default 1)
      --set stringArray               Use custom flags or override existing flags 
                                      (example --set=gateway.replicas=2)
      --update-repo                   Update the helm repo (default true)
```

What if you need some options that aren't listed? That's fine, you can go back to the old way of trawling README files and then add `--set gateway.image=` for instance to override the OpenFaaS gateway container image.

### Making your next action obvious

To be fair, most Helm charts will give you a pointer on how to use the software, but usually this is an afterthought.

arkade gives specific and actionable help messages after installing an app.

```bash
$ arkade info openfaas

Info for app: openfaas
# Get the faas-cli
curl -SLsf https://cli.openfaas.com | sudo sh

# Forward the gateway to your machine
kubectl rollout status -n openfaas deploy/gateway
kubectl port-forward -n openfaas svc/gateway 8080:8080 &

# If basic auth is enabled, you can now log into your gateway:
PASSWORD=$(kubectl get secret -n openfaas basic-auth -o jsonpath="{.data.basic-auth-password}" | base64 --decode; echo)
echo -n $PASSWORD | faas-cli login --username admin --password-stdin

faas-cli store deploy figlet
faas-cli list

# For Raspberry Pi
faas-cli store list \
 --platform armhf

faas-cli store deploy figlet \
 --platform armhf

# Find out more at:
# https://github.com/openfaas/faas
```

You can call these back at any time with `arkade info APP`

### The multi-arch question. Why doesn't this work on my Raspberry Pi?

If you've ever seen the message: `Illegal instruction` or `exec format error` then you know that I'm talking about here. For the past 5 years the OpenFaaS community have been producing software that is built to run on multiple types of CPUs and Operating Systems.

arkade itself is a multi-arch binary available for Windows, MacOS, Linux. It works on both Intel and ARM architectures.

Its apps are smart enough to tell you that Istio isn't available for your cluster running on Raspberry Pi or AWS Graviton.

```bash
$ arkade install istio

only Intel, i.e. PC architecture is supported for this app
```

That said, wherever possible, we add apps that are multi-arch, and include any switches or changes in the arkade code to make the installation smooth for you.

Here's a few apps that install to an ARM or Intel cluster:

* ingress-nginx
* openfaas
* ingress-operator
* metrics-server

### The Cloud Native problem. Lack of cohesion, proliferation of CLIs

A characteristic of Cloud Native projects and the ecosystem is that applications tend to be self-contained, and usable on their own. They also fit quite well together when designed in this way, but it means there is a lack of cohesion and a proliferation of CLIs.

In the good old says you may have a single binary that did 3-5 things, now we have to fetch 5-10 binaries just to set up a basic cloud native application.

arkade makes it very quick and easy to download cloud native CLIs.

Want to write a quick tutorial for OpenFaaS that uses DigitalOcean for a VM, KinD to run a cluster, helm to install openfaas, faas-cli to deploy functions and kubectl to debug them? How about automating that with terraform? Great, you now need to download at least 5 different CLIs. Start your stop-watch, and honestly tell me how long it took you to trawl all the GitHub repos, find the latest stable release and to install it correctly for your OS.

arkade provides a simple way to download binaries:

```bash
arkade get terraform --version 0.12.1
arkade get doctl
arkade get kind
arkade get kubectl
arkade get helm
arkade get faas-cli
```

And we're done. Whatever your OS or CPU architecture, the correct and latest binary will be downloaded.

> Tip: find a complete list of apps via `arkade get --help`

### Composite apps

Sometimes installing a single app doesn't add much value over the traditional approach, in which case you may be better off using what you know. arkade does help when you find that you need 4-5 apps in a short period of time, or for a tutorial. We write many tutorials in the community and some of us even do it for a day-job. This is where arkade comes into its own.

What would it normally take you to set up a Docker Registry with TLS and auth? I know this one because [I wrote it for a client a year ago](https://www.civo.com/learn/set-up-a-private-docker-registry-with-tls-on-kubernetes): about 3000-5000 lines of mark-up and a few hours.

arkade can reduce that to 5 lines:

```bash
arkade install ingress-nginx
arkade install cert-manager
arkade install docker-registry
arkade install docker-registry-ingress \
  --email $EMAIL \
  --domain $DOMAIN

docker login $DOMAIN
```

That's it. By all means, read the [manual approach used by the tutorial](https://www.civo.com/learn/set-up-a-private-docker-registry-with-tls-on-kubernetes) to compare.

The first three steps install charts with defaults, something we can replicate with helm, but not as fast. The last step creates a template for a cert-manager Issuer and Ingress record, which are then applied in your cluster. This kind of "magic" can go a long way and also exists for bringing TLS to OpenFaaS.

```bash
arkade install ingress-nginx
arkade install cert-manager
arkade install openfaas
arkade install openfaas-ingress \
  --email $EMAIL \
  --domain $DOMAIN

echo Access your OpenFaaS Gateway at: https://$DOMAIN/
```

### Easy networking when working locally

arkade also offers the [inlets-operator](https://github.com/inlets/inlets-operator) as an app, which enables you to use a LoadBalancer on your local cluster with KinD, k3s, a Raspberry Pi, or minikube, just like you would on your expensive AWS cluster.

The inlets-operator makes a fully working TCP LoadBalancer available through a network tunnel with [inlets PRO](https://inlets.dev), and a tiny VM provisioned on the cloud of your choice.

```bash
arkade install inlets-operator \
 --license "$(cat ~/LICENSE.txt)" \
 --provider digitalocean \
 --region lon1 \
 --access-token-file ~/access-token.txt
```

If you run this command before the step above for your Docker Registry or OpenFaaS installation, then it will allocate your cluster a public IP address and start routing traffic to your IngressController. This all takes much less time than a cloud LoadBalancer, you'll be accepting traffic in 30-60s.

Find out more on the [inlets PRO landing page](https://inlets.dev/), there's also an open source version which you can use if you only need HTTP traffic.

## Wrapping up

[arkade](https://arkade.dev) was written to make the life of developers easier, it can install many different applications, which may involve using Helm, kubectl, or an additional CLI. It gives helpful usage information, and tries to prevent you doing things you shouldn't, like installing an application to your Raspberry Pi cluster that isn't built for ARM CPUs. It makes the tedious task of downloading dozens of CLIs much quicker.

Looking forward, arkade will continue to be maintained by the OpenFaaS community and is accepting PRs and suggestions. It evolved to solve a clear pain-point, and as we approach 1000 stars on GitHub, it has proven useful to the community so far.

* Have you got an app that you'd like to see?
* Is there a CLI that you often use with a Kubernetes cluster?
* Do you want to view the code?

[View the code on GitHub](https://get.arkade.dev)

Try it out today:

```bash
# Note: you can also run without `sudo` and move the binary yourself
curl -sLS https://get.arkade.dev | sudo sh

arkade --help
ark --help  # a handy alias

# Windows users with Git Bash
curl -sLS https://get.arkade.dev | sh
```

What about commercial apps? One of the lessons we've learned as a community about Open Source, is just how much effort it takes to sustain a project where everything's given away for free. Commercial users are often not interested or willing to contribute through sponsorships, support, consulting, or paid development. Now there has been interest from commercial companies that want to have their app listed. We've come up with a way for them to differentiate their offerings through Sponsored Apps.

Find out about [Sponsored Apps](https://get.arkade.dev)
