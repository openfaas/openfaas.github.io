---
title: "Cloud Native tools for Developers"
description: We look through kubernetes, k3s, OpenFaaS and inlets to provide an overview of a cloud native application platform
date: 2020-04-04
image: /images/arkade-traefik-k3sup/traefik-router.png
categories:
  - kubernetes
  - serverless
  - cloud
  - functions
author_staff_member: alistair
dark_background: true

---

Do you ever wonder how to get started with cloud native technologies? Keep asking yourself "what benefit does it have for
me?". Let us show you a quick and repeatable setup for a developer friendly, run anywhere application stack built on 
Kubernetes.

We are going to go through the steps of setting up a 4 node Kubernetes cluster on 4 cloud VMs, configure ingress from 
the public internet using [Inlets](https://docs.inlets.dev/#/) and deploy a working application composed of [OpenFaaS](https://www.openfaas.com/) Functions.

We are going to be using the following tools:
* [K3s](https://k3s.io/) installed with [k3sup](https://github.com/alexellis/k3sup)
* [arkade](https://github.com/alexellis/arkade) which is used to install kubernetes apps
* The [inlets-operator](https://github.com/inlets/inlets-operator) for ingress, using [inlets-pro](https://github.com/inlets/inlets-pro)
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) will be used to verify the installation and see the running pods inside our cluster
* [faas-cli](https://github.com/openfaas/faas-cli) for installing the openfaas applications

This post summarises the steps taken in the webinar presented in collaboration with [Traefik](https://containo.us/traefik/)
{% include youtube.html id="r4mEF8rtXWo" %}

### Install k3sup

`k3sup` is a tool that automates the installation of k3s kubernetes clusters on remote hosts using SSH. It is run from 
your computer rather than running on the nodes directly. `k3sup` can automatically detect the remote computer's CPU 
architecture. This means we can use this tool to install k3s on ARM and AMD based compute nodes. This would allow us to 
run AWS A1 instances (Other ARM based compute is available) if our workloads were ARM compatible to reduce costs and 
energy usage.

```sh
curl -sLS https://get.k3sup.dev | sh

sudo install k3sup /usr/local/bin/
```

### Install k3s 

We are going to use 4 Digital Ocean VMs as our Kubernetes nodes. 

>You can use any cloud provider or spare compute you have kicking around. ARM and AMD64 based compute should work (we 
>used 4x RPi4s on the webinar, and I'm using AMD based nodes now)

I have set up 4 nodes in the London region. You can use whichever size suits your needs, but it's probably best to use 
nodes with at least 2GB of ram, allowing you enough resources to deploy your own applications as well as the kubernetes
components.

![DigitalOcean droplets from their cloud UI](/images/arkade-traefik-k3sup/digitalocean_4_nodes.png)
I have put the 4 IP addresses into environment variables. 

```sh
export MASTER_IP=178.128.162.180
export WORKER_1_IP=157.245.45.50
export WORKER_2_IP=157.245.32.88
export WORKER_3_IP=157.245.47.60
```

These IPs are not going to be the same for you, but replace the 4 IPs with the ones for your instances. You can also use
a different number of nodes if you wish, just amend the below commands as required.

When using K3s our "master" node can also be used to schedule work unlike normal k3s, so we get even more resources to 
use for our own applications.

> I'm using the user `k3s` in the below examples. I have logged into each VM and created a `k3s` user and added my SSH
>key to the user's `~/.ssh/authorised_keys`. It is not advised to use `root` for running k3s.

To make the next steps easier for you I have used an environment variable for the user, some providers create different 
ones for you. 

```sh 
export USER="k3s"
```

Let's first install k3s on our master node.

> By passing the `--no-extras` flag we are going to exclude the installation of traefik and the servicelb
> which are included by default on k3s clusters

```sh
k3sup install --ip $MASTER_IP --user $USER --no-extras
```

When this finished we should have a `kubeconfig` file in our current directory. We can verify the installation by checking 
that we can connect to the cluster using the `kubeconfig`.

```sh
export KUBECONFIG=/full/path/to/kubeconfig

kubectl get nodes -o wide

NAME                         STATUS   ROLES    AGE   VERSION        INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
ubuntu-s-1vcpu-2gb-lon1-02   Ready    master   14m   v1.17.2+k3s1   178.128.162.180   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   containerd://1.3.3-k3s1

```

Now we have verified our master node is up we can join our 3 extra workers.

These commands below will install the k3s worker agent on the nodes and join them to the cluster.

```sh
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_1_IP
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_2_IP
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_3_IP
```


We can check that these nodes joined by running `kubectl get nodes -o wide` again.

```sh 
NAME                         STATUS   ROLES    AGE   VERSION        INTERNAL-IP       EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
ubuntu-s-1vcpu-2gb-lon1-02   Ready    master   16m   v1.17.2+k3s1   178.128.162.180   <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   containerd://1.3.3-k3s1
ubuntu-s-1vcpu-2gb-lon1-03   Ready    <none>   93s   v1.17.2+k3s1   157.245.45.50     <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   containerd://1.3.3-k3s1
ubuntu-s-1vcpu-2gb-lon1-01   Ready    <none>   72s   v1.17.2+k3s1   157.245.32.88     <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   containerd://1.3.3-k3s1
ubuntu-s-1vcpu-2gb-lon1-04   Ready    <none>   39s   v1.17.2+k3s1   157.245.47.60     <none>        Ubuntu 18.04.3 LTS   4.15.0-66-generic   containerd://1.3.3-k3s1
```

> Note: If your nodes don't join correctly make sure the workers have network connectivity to the master, and that the
> hostnames are different for all of the nodes. There could be other things that are causing you problems, but these are 
> the most common and easy to fix.

### Install our Kubernetes Applications with `arkade`

Now we have our kubernetes cluster up and running it is time to start installing our apps and services. We are going to 
use `arkade` to help us out. `arkade` is a kubernetes app installer that provides an easy to use, strongly typed, command 
line tool to automate the deployment of complex helm charts and apps that require manual steps and setup before they can 
be used.

`arkade` can be installed like this:

```sh
curl -sLS https://dl.get-arkade.dev | sudo sh

arkade --help
```

`arkade` apps use sensible defaults wherever possible. For any configuration that can't be defaulted it provides flags 
to get the required information. For example, the `openfaas-ingress` app requires a domain name and email to be provided
by the user. If you omit these then you get a useful message explaining what is wrong and how you can rectify the 
problem.

```sh 
$ arkade install openfaas-ingress
Error: both --email and --domain flags should be set and not empty, please set these values
```

#### Install `traefik2`

When we installed our k3s cluster using `k3sup` we used the `--no-extras` flag. This means we didn't install the k3s 
default ingress provider `traefik`. We did this because we want to install `traefik2`. This is the latest version of the
cloud native router with commercial support from [containous](https://containo.us/)

It's one command to install traefik2 using `arkade`.
```sh
arkade install traefik2
```

This will install the `traefik2` Custom Resource Definition (CRD) [IngressRoute](https://docs.traefik.io/providers/kubernetes-crd/)
which can be used to configure your ingress with more control than using the default auto-discovery
provided by `traefik`. You are still able to use the normal behaviour without any major changes.

#### Install the inlets-operator (Optional)

If you are building your cluster inside a private network, such as using Raspberry Pis in your house we can get inbound
network access from the internet so that we can get our TLS certificates and eventually ingress for our deployed applications.

The inlets-operator automates the provisioning of [inlets](https://docs.inlets.dev/#/) exit nodes, and the routing of 
requests to your kubernetes services. 

For you to get TLS certificates and `https` URLs you will need to use `inlets-pro` which is a paid-for version of the 
open source `inlets`. Inlets-pro can support layer4 TCP tunneling, while the open source version only supports layer7
HTTP tunneling. You can get an inlets-pro license by following the steps in the [inlets-pro github repository](https://github.com/inlets/inlets-pro#start-your-free-14-day-trial)

Inlets requires an API Key for one of the supported cloud providers, I am using Digital Ocean for my nodes, so may as well 
use the same provider for the inlets exit nodes. I have downloaded the token and put it into a file `~/do-token`.

```sh 
export LICENSE=<your-license-here>
arkade install inlets-operator -t ~/do-token -l $LICENSE
```

This will install everything you need to automatically get a public IP from your chosen inlets provider when you create a 
kubernetes service which requests an external IP.

> Note: You can use any of the supported providers with the inlets operator, so check out the
> [inlets](https://docs.inlets.dev/#/) docs for more info on supported providers and configuration. 


#### Install cert-manager

[cert-manager](https://cert-manager.io/) automates the provisioning of TLS Certificates within your clusters. We are using it to get a certificate
for openfaas so that our user's data is secured when in transit. 

Installing cert-manager is easy with `arkade` its just this command.

```sh
arkade install cert-manager
```

You may need to wait for a minute for the images to pull and all the containers to start. 


#### Install OpenFaaS

Now we have almost all of our "platform" applications installed, its time to install [OpenFaaS](https://www.openfaas.com/)

OpenFaaS makes it simple to deploy both functions and existing code to Kubernetes. Neat!

We are going to deploy some Serverless functions into our cluster using OpenFaaS to manage these deployments a little later 
in this post. 

```sh 
arkade install openfaas
```

We can then wait for the deployment to finish

```sh 
$ kubectl rollout status -n openfaas deploy/gateway
Waiting for deployment "gateway" rollout to finish: 0 of 1 updated replicas are available...
deployment "gateway" successfully rolled out
```

Now to check that everything is ok with the OpenFaaS installation. We need to forward the traffic for the OpenFaaS
gateway to our local machine.

```sh

#Grab the OF Dashboard pwd 
kubectl get secret \
    -n openfaas basic-auth \
    -o jsonpath={.data.basic-auth-password} | base64 --decode; echo

kubectl port-forward svc/gateway -n openfaas 31112:8080 

```

Grab the password that the first command printed out, mine was `l8C3732h5EZN5usx8dHF8UPj6`. 

Now head to [http://localhost:31112/ui/](http://localhost:31112/ui/) and login with username: `admin` and your password.
You should then be greeted with the OpenFaaS Dashboard.

![openfaas gateway image](/images/arkade-traefik-k3sup/openfaas-dashboard.png)

Not much to see yet, but we know it's working inside our cluster. We can't yet access the dashboard from the public 
internet. 

#### Setup DNS Records

We need to grab the IP of our exit node. The inlets-operator provisioned for us automatically when we install traefik2 
as it requested an external IP.

```sh 
kubectl get svc -n kube-system traefik

NAME      TYPE           CLUSTER-IP      EXTERNAL-IP    PORT(S)                      AGE
traefik   LoadBalancer   10.43.161.149   167.172.55.6   80:31199/TCP,443:30157/TCP   36m
```

> Note: Use your email and domain in place of the `example.com` values from now on!

Im using DigtalOcean's CLI `doctl` , as I have a domain setup in there. You should set the DNS record with your hosting provider.

```sh 
doctl compute domain records create example.com \
    --record-type A --record-name openfaas \
    --record-ttl 30 --record-data 167.172.55.6
```


> Note: We have used the inlets-operator to get a public IP, if you have not used this then grab the IP/DNS name for your 
> cluster and use that instead.


#### Install `openfaas-ingress`

We have created an `arkade` app for installing the Ingress and automating the provisioning of the TLS certificates for 
OpenFaaS. This means that with 1 command we can add Ingress and get a `https` url for our OpenFaaS installation.

Please use your email and domain in place of the `example.com` values from now on!

```sh
$ arkade install openfaas-ingress \
    --email your-email@example.com \
    --domain openfaas.example.org \
    --ingress-class traefik


Using kubeconfig: /home/heyal/kubeconfig
2020/03/19 13:24:20 /tmp/.arkade
=======================================================================
= OpenFaaS Ingress and cert-manager ClusterIssuer have been installed =
=======================================================================

# You will need to ensure that your domain points to your cluster and is
# accessible through ports 80 and 443. 
#
# This is used to validate your ownership of this domain by LetsEncrypt
# and then you can use https with your installation. 

# Ingress to your domain has been installed for OpenFaaS
# to see the ingress record run
kubectl get -n openfaas ingress openfaas-gateway

# Check the cert-manager logs with:
kubectl logs -n cert-manager deploy/cert-manager

# A cert-manager ClusterIssuer has been installed into the default
# namespace - to see the resource run
kubectl describe ClusterIssuer letsencrypt-prod

# To check the status of your certificate you can run
kubectl describe -n openfaas Certificate openfaas-gateway

# It may take a while to be issued by LetsEncrypt, in the meantime a 
# self-signed cert will be installed

Thanks for using arkade!

``` 

And now we wait... It can take a few minutes for you to get a TLS certificate. 

```sh 
$ kubectl get cert -n openfaas
NAME               READY   SECRET             AGE
openfaas-gateway   True    openfaas-gateway   2m28s
```

When `kubectl get cert -n openfaas` returns "True" for the READY field, we are good to go!

You can then naviate to your domain `https://example.openfaas.com` and login with the password we got earlier. 


### Install our Application

WoW! A lot of content to get to this stage. Let's recap on what we have so far.

* K3s cluster (4 nodes)
* Public IP Address
* OpenFaaS installation
* A custom domain secured with TLS (https url)

If we took the commands and ran them in 1 block it would look like this: 

```sh 
# Install our tools
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/
curl -sLS https://dl.get-arkade.dev | sudo sh

# Set our environment variables
export MASTER_IP=178.128.162.180
export WORKER_1_IP=157.245.45.50
export WORKER_2_IP=157.245.32.88
export WORKER_3_IP=157.245.47.60
export USER="k3s"
export LICENSE=<your-inlets-pro-license-here>


# Install our cluster
k3sup install --ip $MASTER_IP --user $USER --no-extras
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_1_IP
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_2_IP
k3sup join --user $USER --server-ip $MASTER_IP --ip $WORKER_3_IP
export KUBECONFIG=/full/path/to/kubeconfig


arkade install traefik2
arkade install inlets-operator -t ~/do-token -l $LICENSE
arkade install cert-manager
arkade install openfaas
doctl compute domain records create example.com \
  --record-type A --record-name openfaas \
  --record-ttl 30 --record-data <external IP>
arkade install openfaas-ingress \
  --email your-email@example.com \
  --domain openfaas.example.org \
  --ingress-class traefik

```

So, with 11 commands (I'm not counting the ones that set up environment variables or install tools) we have set up a 4 node
cluster, installed OpenFaaS and set up a custom domain for our OpenFaaS installation.

> Note: If we were using a managed Kubernetes service this would go down to just 4 commands! We would install 
> OpenFaaS, OpenFaaS Ingress, Cert-Manager and set our DNS.


## Install Applications

During the demo we installed an application that received webhooks from Github when someone commented on an Issue in a 
repository. The app collected the emojis that people posted and aggregated them in a postgres database. There was a UI to 
see which was the most popular emoji.

We are going to run through configuring and installing that app on our OpenFaaS installation.

> Note: We will not go through getting a postgres database set up, this is outside the scope of this post. We will 
> assume you have a database and you have connection details to hand.

We are going to install [Comment Vibes](https://github.com/alexellis/comment-vibes) written by [Alex Ellis](https://twitter.com/alexellisuk).

First off, use the postgres command line to connect to the database and then paste in the contents of [schema.sql](https://github.com/alexellis/comment-vibes/blob/master/schema.sql)

```sh 
psql postgresql://connection-string-here
# paste in that file's contents
```


Next we need to set up our secrets. These will allow our application to communicate with the database
and verify that the webhooks we receive are from github.

```sh 
faas-cli login \
  -g https://openfaas.example.com \
  --username admin \
  --password <your openfaas password from before>


export USERNAME="postgres username"
export PASSWORD="postgres password"
export HOST="postgres host"
export WEBHOOK_SECRET="some-random-string"

export OPENFAAS_URL="https://openfaas.example.com"
faas-cli secret create username --from-literal $USERNAME
faas-cli secret create password --from-literal $PASSWORD
faas-cli secret create host --from-literal $HOST
faas-cli secret create webhook-secret --from-literal $WEBHOOK_SECRET
```

Clone the [github repository](https://github.com/alexellis/comment-vibes) and install to openfaas

```sh 
git clone https://github.com/alexellis/comment-vibes
cd comment-vibes
```

#### Deploy to OpenFaaS (Intel)

```sh
# Get the additional template
faas-cli template store pull golang-middleware

# Deploy

faas-cli deploy
 ```


#### Rebuild and deploy (Intel and ARM)

```sh
sed -i stack.yml s/alexellis2/your-docker-hub/g
export DOCKER_BUILDKIT=1

faas-cli up --tag=sha
 ```

#### Set up Github Webhooks

We should now have the application setup on your cluster. We now just need to setup the Github webhooks to send webhooks to 
our app when someone leaves a comment on our github Issue.

Choose a github repository (Or create one). Go to Settings for your repo and click "Webhooks". Add a webhook like below.
You can use your custom domain `openfaas.example.com/function/import-comment` for the Payload URL.

Go to Settings for your repo and click "Webhooks" set the webhook secret to the same value you used to create the 
OpenFaaS Secret in the previous steps.

![Setting up a github webhook](/images/arkade-traefik-k3sup/webhook.png)

Pick only the issue comments event.

![Issue comments section of github](/images/arkade-traefik-k3sup/issue-comment.png)

#### Use your app

Have someone send a comment to one of the issues in your repo with an emoji.

You can then view the result at your custom domain `https://openfaas.example.com/function/view`


![example output from our app](/images/arkade-traefik-k3sup/view.png)

## Wrapping up

If you watched the video and followed along with the steps in this post you should have now setup
a kubernetes cluster using `k3sup`, installed some "platform" applications with `arkade` and then deployed
an application that listens for webhooks from github on OpenFaaS. 

This platform can then be used to deploy other serverless functions and applications. They will all get a path under your
custom domain. They will all be secured with the TLS certificate we got from Lets Encrypt.


## Over to you!

We would love to know what you are using OpenFaaS for, come and join the community on [slack](https://slack.openfaas.io).
