---
title: "I wrote a Twitter Bot using OpenFaaS to avoid missing out on CfP deadlines"
description: "I wrote a Twitter bot using Golang and OpenFaaS so that I wouldn't miss the deadline for CNCF talk submissions or Kubernetes releases"
date: 2021-06-07
image: /images/2021-06-cloudnativetv/background-twitter.png
categories:
 - twitter
 - bot
 - golang
 - usecase
 - functions
author_staff_member: cpanato
dark_background: true

---

I wrote a Twitter bot using Golang and OpenFaaS so that I wouldn't miss the deadline for CNCF talk submissions or Kubernetes releases.

In this blog post, I'll show you how I put the bot together and what tools I used along the way so that you can build your own and get ideas for your own projects.

## Introduction

Bots are everywhere. Some are useful that can help you in your daily work, and others are collecting information about you to use for ads.

> I think that the best bots are both fun and useful.

I created [@CloudNativeBot](https://twitter.com/CloudNativeBot) because: I would like to learn a bit more about OpenFaaS and the ecosystem around that.

I wanted to:
* let people know when the next KubeCon was coming up and when the Call For Papers (CFP) deadline was
* to show when the [Kubernetes](https://kubernetes.io/) Patch Releases land
* and to bring some joy

Most importantly, I want you to have fun, discover new technologies that can be applied to your daily work.

## What you'll need to try it out

Before you get started you'll need Docker on your machine so that you can deploy a Kubernetes cluster and build OpenFaaS functions.
* [Docker or Docker Desktop](https://www.docker.com/products/docker-desktop)

Then you'll need the following, which you can get by following the docs:

* [OpenFaaS](https://www.openfaas.com) - to run the functions
* [faas-cli](https://github.com/openfaas/faas-cli) - the CLI for OpenFaaS
* [connector-sdk](https://github.com/openfaas/connector-sdk) - the SDK for writing event connectors to trigger functions, in this instance from Twitter
* [ko](https://github.com/google/ko) - a project to hot-reload our Twitter connector in the cluster as we iterate on it

### Using Connector-sdk to listen and dispatch the Twitter Stream

The connector-sdk helps you to connect events to functions. In the beginning of the code you bind to your streaming data source like Twitter, NATS or a cron timer, then whenever a message is received, the topic or channel name is used to trigger matching functions.

You can learn more here: [OpenFaaS Triggers](https://docs.openfaas.com/reference/triggers/)

![Connector pattern](https://docs.openfaas.com/images/connector-pattern.png)
> Functions subscribe to events by adding a "topic" annotation at deploy time

I was able to setup my connector with just a few lines of code. In the case of Twitter, we need to configure the SDK to listen a stream for various messages like `/cloudnativetv` or `/k8s-patch-schedule`. 

Here's an example of how to connect the stream using the Twitter SDK and [anaconda library](https://github.com/ChimeraCoder/anaconda).

```golang
api = anaconda.NewTwitterApiWithCredentials(Config.TwitterAccessToken, Config.TwitterAccessSecret, Config.TwitterConsumerKey, Config.TwitterConsumerSecretKey)
  if _, err := api.VerifyCredentials(); err != nil {
    log.Fatalf("Bad Authorization Tokens. Please refer to https://apps.twitter.com/ for your Access Tokens: %s", err)
  }

  streamValues := url.Values{}
  streamValues.Set("track", "/cloudnativetv,/k8s-patch-schedule,/kubecon-random-video")
  streamValues.Set("stall_warnings", "true")
  log.Println("Starting CloudNative Stream...")
  s := api.PublicStreamFilter(streamValues)
```

After that, we need to configure the connector-sdk with the password for the gateway and any other configuration we want.

If you expect to receive many messages over a short period of time, or concurrent slow-running functions then you can set `AsyncFunctionInvocation` to true for execution in the background.

```golang
creds := &auth.BasicAuthCredentials{
    User:     Config.OpenFaaSUsername,
    Password: Config.OpenFaaSPassword,
  }

  config := &types.ControllerConfig{
    RebuildInterval:         time.Millisecond * 1000,
    GatewayURL:              Config.OpenFaaSGateway,
    PrintResponse:           true,
    PrintResponseBody:       true,
    AsyncFunctionInvocation: false,
  }

  controller := types.NewController(creds, config)

  receiver := ResponseReceiver{}
  controller.Subscribe(&receiver)

  controller.BeginMapBuilder()
```

Then we can create an event-loop in a separate Go routine to listen to the events and dispatch them when required.

The `controller.Invoke()` function takes a topic and a number of bytes. So the topic could be `"cloudnative.twitter.stream"` and the message in this instance will be a JSON payload that can be parsed by the target function.

```golang
go func() {
    for t := range s.C {
      switch v := t.(type) {
      case anaconda.Tweet:
        data := []byte(fmt.Sprintf(`{"text": %q,"id": %d, "id_str": %q, "user_screen_name": %q, "api_key": %q}`, v.Text, v.Id, v.IdStr, v.User.ScreenName, Config.TokenAPIKey))

        topic := "cloudnative.twitter.stream"
        log.Printf("Got one message - https://twitter.com/%s/status/%d - Invoking on topic %s\n", v.User.ScreenName, v.Id, topic)
        controller.Invoke(topic, &data)
      default:
        log.Printf("Got something else %v", v)
      }
    }
  }()
```

The complete source code can see here: https://github.com/cpanato/cloudnative-bot/blob/main/cmd/twitter-stream/main.go.

Now we are in part to deploy the service into a Kubernetes Cluster.

All other connectors have a Dockerfile and help chart, but I decided to use the [`ko`](https://github.com/google/ko) tool for building my connector. `ko` simplifies and makes it easier to create a container image for your Go application without having to write a Dockerfile.

> Note: The community connectors do however use a Dockerfile and it is easy to use as a template for your own. For example, the [nats-connector](https://github.com/openfaas/nats-connector).

One way to use `ko` is to define your deployment manifest, and in the image field, have the `ko` syntax, for example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-bot-stream
  labels:
    app.kubernetes.io/name: cloudnative-bot-stream
spec:
  replicas: 1
    spec:
      containers:
      - name: stream
        image: ko://github.com/cpanato/cloudnative-bot/cmd/twitter-stream
        imagePullPolicy: IfNotPresent
```
Note: some lines were removed from the manifest to make it more clear.

After defining the deployment, you can run `ko` and the output will be the updated manifests ready to be deployed and the image pushed to the registry.

```console
$ export KO_DOCKER_REPO=YOUR_REGISTRY_NAME
$ ko resolve -f deployment.yaml > release.yaml
```

### Using OpenFaaS functions for the slash commands

We are using OpenFaaS to deploy the slash command functions for the bot, and those will be triggered by the connector-sdk code we show above.

The `CloudNativeBot` have currently three functions:

  * `/cloudnativetv` - returns a random logo for the CNCF CloudNative TV shows
  * `/k8s-patch-schedule` - returns the patch schedule for the active release branches fro Kubernetes
  * `/kubecon-random-video`- returns a random KubeCon video

The code for each function you can found in the [cloudnative-bot](https://github.com/cpanato/cloudnative-bot) repo.

An example of how that works:

* A Twitter user post a message `/kubecon-random-video`
* The stream listener will catch that and will trigger the function
* The specific function, in this case, the `kubecon-random-video` will grab a random video from Youtube and post a reply message on Twitter.

![https://twitter.com/comedordexis/status/1398286724569182219](/images/2021-06-cloudnativetv/twitter-bot-example.png)
> Example response with a random video from the last KubeCon event.

### Running functions running on a schedule

Now we've covered the functions which are triggered by user-input. We still need to talk about the function that reminds us about the upcoming deadline for talk submissions. You can't give a talk at a conference, if you've not submitted a talk abstract and sometimes these dates come up so quickly, so I wanted to make sure I never missed one.

These functions are similar to the ones we created above, but instead of being triggered by the Twitter connector I built and deployed with ko, they are triggered by the [`cron-connector`](https://github.com/openfaas/cron-connector).

The `cron-connector` is an add-on that you can install along side your OpenFaaS deployment and then using some annotations in your function you can make it run using a defined schedule.

To define the schedule for your function you can add the following in your `stack.yaml` 

```yaml
functions:
  remind-cfp:
    image: ghcr.io/cpanato/remind-cfp:1.0.0
    annotations:
      topic: cron-function
      schedule: "*/5 * * * *"
```

The `topic` is always set to `cron-function` and the `schedule` is a standard Cron expression.

For [faasd](https://github.com/openfaas/faasd) users, you can use cron on your system or deploy the cron-connector. faasd can run on a single virtual machine or Raspberry Pi without the overhead of Kubernetes.

### Summing up

With OpenFaaS and the connector-sdk I was able to bootstrap my project quickly and iterate on it until I had everything in place.

Feel free to test it out, the commands are:

* `/cloudnativetv`
* `/k8s-patch-schedule`
* `/kubecon-random-video`

If you like, feel free to fork the repo and build your own bot. The functions can be written in any language that you can find in the template store via `faas-cli template store list` or you can just customise mine to suit your needs.

You can even build your own Slack and GitHub bots with OpenFaaS. Find out what the community and customers are doing in: [Exploring Serverless Use-cases from Companies and the Community](https://www.openfaas.com/blog/exploring-serverless-live/)

What to do next:

 - Follow the [@CloudNativeBot](https://twitter.com/CloudNativeBot)
 - Read this blog post on [Golang and OpenFaaS](https://www.openfaas.com/blog/golang-serverless/)
 - Discover more tools and functions in the OpenFaaS ecosystem: https://github.com/openfaas
 - Checkout [KubeCon US](https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/) - October 2021
