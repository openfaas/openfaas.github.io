---
title: "Painless Serverless Development with Kubernetes, OpenFaaS and Okteto"
description: In this tutorial Ramiro from Okteto explains how you can use Kubernetes, OpenFaaS and Okteto to streamline function development.
date: 2020-01-24
image: /images/2020-01-24-painless-serverless-development/cover.jpg
categories:
  - guest
  - serverless
  - kubernetes
  - okteto
author_staff_member: alex
dark_background: true
---

I’d like to introduce you to Ramiro Berrelleza who is our guest-writer for today’s end-user blog post. Ramiro will talk about how you can use Kubernetes, OpenFaaS and Okteto to streamline function development.

> Author bio: [Ramiro Berrelleza](https://twitter.com/rberrelleza) is one of the founders of [Okteto](https://okteto.com), where he and his team are building tools to improve the development experience of Cloud Native applications.

<img src="/images/2020-01-24-painless-serverless-development/ramiro.jpg" width="25%" height="25%" />

I'm a huge fan of the serverless programming paradigm. I've been building functions for a while, and I truly believe that it is the way to go. Let me write my business logic without caring about anything else? Yes, please! I built a function for Amazon Echo years ago. I haven't touched it in years, and it's been happily running ever since. 

But AWS Lambda, Cloud Run, Zeit, etc.. all suffer from the same problem. **Developing functions is full of friction**: 

You either develop and test locally, and then run into a lot of integration issues, or you develop and test in production, and you end up with a workflow where most of the time you're waiting for builds or deploys to happen. 

When building a function I want the same things that I want when building any other type of distributed application:
- I want to be able to quickly setup my environment.
- I want to keep my mocks to a minimum.
- I want it to be fast.

Starts to sound a lot like the type of problems that we are working on at Okteto no?

> For the more visually oriented, I gave talk on the same topic as part of the Serverless Summit during Kubecon 2019. The recording [is available on youtube](https://www.youtube.com/watch?v=Yx1nGH2zh0k).

# Enter OpenFaaS

[OpenFaaS](https://openfaas.com) is a framework for building serverless functions with Docker and Kubernetes. Their goal, in their own words, is *to make it easy for developers to deploy event-driven functions and microservices to Kubernetes without repetitive, boiler-plate coding*.

In the Kubernetes world, OpenFaaS functions are deployments. This makes it the perfect partner for Okteto's remote development model. OpenFaaS and Okteto together lets you iterate on your functions as fast as you can type.

In the rest of the blog post I'll talk about the workflow I use when developing functions. I'll talk about how I leverage Okteto Cloud to deploy OpenFaaS with one-click, OpenFaaS to deploy my funtions in Kubernetes, and the Okteto CLI to launch my development environment, iterate on my function, and even attach a debugger to it.

# Deploy OpenFaaS in Okteto Cloud

_If you already have your own installation of OpenFaaS, feel free to skip [to the next step](#create-your-function)._

[Okteto Cloud](https://okteto.com) is a development platform for Kubernetes applications. It's free to try, you cat get up to 3 namespaces with 4 CPUs and 8GB of RAM each for you to develop. Among other handy features, it has a catalog of Helm applications that you can directly deploy with one-click, like Wordpress, MongoDB and **OpenFaaS**. We'll be using that to deploy our dev instance of OpenFaaS.

[Log in to Okteto Cloud](https://cloud.okteto.com) and click on the Deploy Application button on the top left. A dialog will open with the list of available applications you can deploy on your namespace. Select `OpenFaaS` from the list, set the gateway password to something memorable and click the `Deploy` button.

![OpenFaaS install via Okteto Cloud](/images/2020-01-24-painless-serverless-development/deploy.png)

After a few seconds, your OpenFaaS instance will be up and ready to go.  All the different OpenFaaS components will be grouped under the application in the Okteto Cloud UI. Clicking on the link will take you to OpenFaaS' gateway.

![OpenFaaS deployed via Okteto Cloud](/images/2020-01-24-painless-serverless-development/deployed.png)

# Create your function

Now that our instance of OpenFaaS is ready, we are going to start building our function. 

We are going to use the `faas` CLI to skaffold our function, and to deploy it. If you don't have it, the installation instructions [are available here](https://github.com/openfaas/faas-cli#get-started-install-the-cli).

First, we'll login to our OpenFaaS gateway. While this is not strictly necessary, it will make further steps easier. Don't forget to set `$GATEWAY_URL` with the URL you got from Okteto Cloud, and `$GATEWAY_PASSWORD` to the password you set when deploying OpenFaaS (it defaults to `Password123!`).

```console
export GATEWAY_URL=https://openfaas-rberrelleza.cloud.okteto.net
export GATEWAY_PASSWORD='Password123!'
faas login --password $GATEWAY_PASSWORD --gateway=$GATEWAY_URL
```

Let's go ahead and initialize our function. For this post we're going to be using golang, so we are going to pull the `go-http` template:

```console
faas template pull https://github.com/openfaas-incubator/golang-http-template
```

```console
Fetch templates from repository: https://github.com/openfaas-incubator/golang-http-template at master
2020/01/17 20:13:19 Attempting to expand templates from https://github.com/openfaas-incubator/golang-http-template
2020/01/17 20:13:20 Fetched 4 template(s) : [golang-http golang-http-armhf golang-middleware golang-middleware-armhf] from https://github.com/openfaas-incubator/golang-http-template
```

Then we initialize the function, using the `golang-middleware` template. Don't forget to set $DOCKER_ID with your Dockerhub ID.

```console
export DOCKER_ID=ramiro
faas new hello --lang golang-middleware --handler function --gateway $GATEWAY_URL --prefix $DOCKER_ID
```

```console
Folder: function created.
    ___                   _____           ____
/ _ \ _ __   ___ _ __ |  ___|_ _  __ _/ ___|
| | | | '_ \ / _ \ '_ \| |_ / _` |/ _` \___ \
| |_| | |_) |  __/ | | |  _| (_| | (_| |___) |
\___/| .__/ \___|_| |_|_|  \__,_|\__,_|____/
        |_|


Function created in folder: function
Stack file written: hello.yml
```

Finally, we build the container and deploy the initial version of the function:
```console
faas up -f hello.yml
```

```console
[0] > Building hello.
...
...
...
Deploying: hello.

Deployed. 202 Accepted.
URL: https://openfaas-ingress-rberrelleza.cloud.okteto.net/function/hello
```

You can use `faas` to call the function directly from the command line:
```console
faas invoke hello -f hello.yml
```

```console
Reading from STDIN - hit (Control + D) to stop.
hello
Hello world, input was: hello
```

# It's developin' time

Normally, when you're developing your function you'll have to go through the following workflow:
- Make changes to your function.
- Run your unit tests (you do write unit tests right?).
- Build and deploy your function.
- `faas invoke` it to validate things end to end.

That flow probably takes about a minute or two. Which doesn't sound to bad right? Not until you have to go through that cycle 10-20 times while battling a particularly gnarly bug. At that point you're going to be spending more time looking at the build logs in your terminal than writing your function.

That's where the [Okteto CLI](https://github.com/okteto/okteto) comes into the picture. The Okteto CLI is an open-source project that **lets you develop your applications directly in Kubernetes** while taking advantage of all the existing tooling.

Since OpenFaaS are deployed as deployment and pods in Kubernetes, we can reuse most of the patterns of remote development that we've been using when building cloud native applications. Instead of developing and then deploying our function we can develop the function directly where it is running.

> If you don't have the Okteto CLI, [follow the instructions here](https://okteto.com/docs/getting-started/installation/index.html) to install it.

Let's launch our remote development environment. Open a shell, go to the folder where you created the function, and save [this manifest](/images/2020-01-24-painless-serverless-development/okteto.yml) as `function/okteto.yaml`:


```yaml
# The name tells Okteto to replace the function named 'hello' with the dev environment
name: hello                  
image: okteto/golang-http-template
command:
- bash
workdir: /home/app/handler
mountpath: /home/app/handler/function
volumes:
# This makes the go build cache persistent across development environments
- /home/app/.cache/go-build/ 
securityContext:
  # the user and group that OpenFaaS functions run as
  runAsUser:  12000
  runAsGroup: 12000
  fsGroup:    12000
  capabilities:
    add:
    # enables us to run the debugger inside the pod
    - SYS_PTRACE
environment:
  # overrides the one set by openfaas, enabling build and run
  - fprocess=go run main.go
forward:
- 8080:8080
- 2345:2345
```

The `okteto.yml` file holds the configuration of your development environment. It's the secret sauce that gives you a repetitive development environment. Commit `okteto.yaml` into your repo and **everyone collaborating will get the same development environment every time**. 

In this case, the manifest is telling Okteto to create an environment environment with:
- `okteto/golang-http-template` as the container, which already has the go runtime, the debugger, [fwatchdog](https://docs.openfaas.com/architecture/watchdog/) and a few other tools installed.
- `/home/app/handler` as the working directory.
- Your function code automatically synchronized at `/home/app/handler/function`
- Automatic port-forwarding for ports `8080` (the function) and `2345` (the go debugger).
- OpenFaaS' [fwatchdog process](https://docs.openfaas.com/architecture/watchdog/) configured to build and launch our function when handling the request.

Since we are launching our development environment in Okteto Cloud, we need to get our credentials. Go back to your browser, log in into [https://cloud.okteto.com](https://cloud.okteto.com), and click on the credentials button on the left to download your kubeconfig.

Okteto CLI automatically picks up your local Kubernetes context. In this case, we'll set `KUBECONFIG` to the path of the kubeconfig we just downloaded, in order to deploy our development environment in Okteto Cloud.

```console
export KUBECONFIG=$HOME/Downloads/okteto-kube.config
```

> The Okteto CLI works with any Kubernetes cluster, local or remote. If you are not using Okteto Cloud, you can either use your current context, or set `KUBECONFIG` to point to your cluster's configuration.

And launch your development environment:
 ```console
 okteto up
 ```

```console
 ✓  Development environment activated
 ✓  Files synchronized
    Namespace: rberrelleza
    Name:      hello
    Forward:   2345 -> 2345
               8080 -> 8080
```

Once `okteto up` finishes provisioning your development environment, you'll be dropped into a remote shell open. Start the function by running the command below:
```console
okteto> fwatchdog
```

```console
Forking - go [run main.go]
2020/01/22 03:43:48 Started logging stderr from function.
2020/01/22 03:43:48 Started logging stdout from function.
2020/01/22 03:43:48 OperationalMode: http
2020/01/22 03:43:48 Timeouts: read: 10s, write: 10s hard: 10s.
2020/01/22 03:43:48 Metrics listening on port: 8081
2020/01/22 03:43:48 Listening on port: 8080
```

Open `function/handler.go` in your local IDE, and change the return message:
```go
w.Write([]byte(fmt.Sprintf("Hello world from Okteto, your input was: %s", string(input))))
```

Go back to the remote shell and stop and start the `fwatchdog` process. Then call the function again from your local shell:
```
faas invoke hello -f hello.yml
```

```
Reading from STDIN - hit (Control + D) to stop.
hello
Hello world from Okteto, your input was: hello
```

With this approach, we were able to **validate our changes end to end directly in OpenFaaS**. You don't need to run docker-compose or minikube locally, write mocks, build containers over and over and no need to redeploy functions. Just write you code, save it and invoke the function.

# Debug instead of print

My favorite feature about using remote development environments is that I can finally go back and **use a debugger to troubleshoot my code**. Forget about littering your code with log.Infos and printf's and instead break exactly where the issue is.

In order to enable debugging, we are going to combine the powers of OpenFaaS and Okteto. We are going to configure the `fwatchdog` process to start the go debugger, and we are going to have Okteto automatically setup a forwarding port between your local machine and the debugger's port in your remote development environment. 

```
export fprocess='dlv debug /home/app/handler --listen 0.0.0.0:2345 --api-version 2 --log --headless'
fwatchdog
```

```
Forking - dlv [debug /home/app/handler --listen 0.0.0.0:2345 --api-version 2 --log --headless]
2020/01/22 03:46:14 Started logging stderr from function.
2020/01/22 03:46:14 Started logging stdout from function.
2020/01/22 03:46:14 OperationalMode: http
2020/01/22 03:46:14 Timeouts: read: 10s, write: 10s hard: 10s.
2020/01/22 03:46:14 Listening on port: 8080
2020/01/22 03:46:14 Writing lock-file to: /tmp/.lock
2020/01/22 03:46:14 Metrics listening on port: 8081
```

> For this part, I'm using VSCode, but this will work with any IDE that supports remote debuggers.

Open the repo we created in VSCode, and create a `.vscode/launch.json` file with the following configuration:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug",
      "type": "go",
      "request": "attach",
      "mode": "remote",
      "host": "127.0.0.1",
      "port": 2345,
      "remotePath": "/home/app/handler",
      "showLog": true,
      "trace": "verbose"
    }
  ]
}
```

This configuration is telling VSCode to attach to a debugger in `127.0.0.1:2345`. In our case, this is the port that Okteto is automatically forwarding to our development environment in Okteto Cloud.

Open the function code, add a breakpoint in `function/handler.go` line 10, and press `F5` to start the debugging session.

Now go back to the local shell and call the hello function via the `faas invoke` command. Write `hello` and press (Control + D) to send the request.

```
faas invoke hello -f hello.yml
```

```
Reading from STDIN - hit (Control + D) to stop.
hello
```

Instead of getting back a response immediately, the debugger will stop on the breakpoint you chose. At this point we can control the flow, inspect values and continue the execution. Pretty neat no? 😎.

### Wrapping up

I've found that this workflow really accelerates my everyday development. I have two commands to get my entire development environment up and running (`faas up` and `okteto up`) and once coding I can stay in "flow" for longer periods, which makes me a lot more productive. 

If you are building functions today, I'd encourage you to try out this workflow and [let me know](https://twitter.com/rberrelleza) what you think about it and how we can improve it.

If you have any comments, questions or suggestions, please join us on Slack at:
* [OpenFaaS Slack #kubernetes](https://slack.openfaas.io)
* [Kubernetes Slack #okteto](https://slack.k8s.io)