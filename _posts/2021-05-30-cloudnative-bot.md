---
title: "Building a Twitter Bot using OpenFaaS to keep up-to-date with CNCF projects and events"
description: "Building a Twitter Bot using OpenFaaS to keep up-to-date with CNCF projects and events, to not miss a CFP or discovery when is the next Patch releases for Kubernetes"
date: 2021-05-20
image: /images/2021-05-cnbot/background-twitter.png
categories:
 - twitter-bot
 - use-cases
 - functions
author_staff_member: cpanato
dark_background: true

---

Learn how OpenFaaS and connector-sdk can be used to run a Twitter bot

## Introduction

Bots are everywhere. Some are useful that can help you in your daily work, and others are collecting information about you to use to make an advertisement. There are others to be fun and entertaining.

I created [@CloudNativeBot](https://twitter.com/CloudNativeBot) because: I would like to learn a bit more about OpenFaaS and the ecosystem around that; To let people know about when is the next KubeCon, when the CFP will end; When the Kubernetes Patch Releases happen; Also to bring some fun, like you can issue a slash command to get a random CloudnativeTV logo. All this is using the Twitter API.

And most important, have fun, discover new technologies that can be applied in your daily work.

In this blog post, I'll show you how I put the bot together and what tools I used along the way so that you can build your own or get ideas for your projects with Go or OpenFaaS.

## What you'll need to try it out

* [Docker or Docker Desktop](https://www.docker.com/products/docker-desktop)
* OpenFaaS
* faas-cli
* [connector-sdk](https://github.com/OpenFaaS/connector-sdk)
* [ko](https://github.com/google/ko)

### Using Connector-sdk to listen and dispatch the Twitter Stream

The connector-sdk is very handy and can be used to listen to an event and act if something happens by triggering a specific function.

The good part is you can set up that with a few lines of code. In the case of Twitter, we need to configure to listen to the stream. 

To configure the Twitter stream, we can do something like:

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

After that, we need to configure the connector-sdk

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

Then we can create a loop to listen to the events and dispatch when needed.

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

Now we are in part to deploy the service into a Kubernetes Cluster. We will need to build a Dockerfile to create the container image for our service, or we can use a tool called [`ko`](https://github.com/google/ko).

`ko` simplifies and makes it easier to create a container image for your Go applications. It is an excellent tool, and we don't need to define a docker file; you can build and push the container right away and have your Kubernetes manifests configured with that image.

One way to use `ko` is to define your deployment manifest, and in the image field, have the `ko` syntax, for example:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudnative-bot-stream
  labels:
    app.kubernetes.io/name: cloudnative-bot-stream
    app.kubernetes.io/managed-by: honk
spec:
  replicas: 1
    spec:
      containers:
      - name: stream
        image: ko://github.com/cpanato/cloudnative-bot/cmd/twitter-stream
        imagePullPolicy: IfNotPresent
```
Note: some lines were removed from the manifest to make it more clear.

After defining the deployment, you can run `ko,` and the output will be the updated manifests ready to be deployed and the image pushed to the registry.

```console
$ export KO_DOCKER_REPO=YOUR_REGISTRY_NAME
$ ko resolve -f  deployment.yaml > release.yaml
```


To learn more about `ko` refer to https://github.com/google/ko

### Using OpenFaaS functions for the slash commands

We are using OpenFaaS to deploy the slash command functions for the bot, and those will be triggered by the connector-sdk code we show above.

The `CloudNativeBot` have currently three functions:

  * `/cloudnativetv` - returns a random logo for the CNCF CloudNative TV shows
  * `/k8s-patch-schedule` - returns the patch schedule for the active release branches fro Kubernetes
  * `/kubecon-random-video`- returns a random KubeCon video

The code for each function you can found in the CloudNativeBot GitHub Project: https://github.com/cpanato/cloudnative-bot

An example of how that works:

* A Twitter user post a message `/kubecon-random-video`
* The stream listener will catch that and will trigger the function
* The specific function, in this case, the `kubecon-random-video` will grab a random video from Youtube and post a reply message on Twitter.


  ![https://twitter.com/comedordexis/status/1398286724569182219](/images/2021-05-cnbot/twitter-bot-example.png)

### OpenFaas functions running as cron jobs

We have two functions that run once a day to tweet some information about when will be the next Kubecon and what is the deadline for the KubeCon CFP.

The functions are pretty similar to the ones we develop above, but those two are using the the [`cron-connector`](https://github.com/openfaas/cron-connector). which helps us to schedule cron functions to run.

The `cron-connector` is an addon that you can install along side your OpenFaaS deployment and then using some annotations in your function you can make it run using a defined schedule.

To define the schedule for your function you can add the following in your `stack.yaml` 

```yaml
functions:
  YOUR_FUNCTION:
    image: functions/YOUR_FUNCTION
    annotations:
      topic: cron-function
      schedule: "*/5 * * * *"
```

### Summing up

Using OpenFaaS and the connector-sdk, we were able to bootstrap the project quickly and have each function very well defined and scoped.

`ko` is a handy tool that helps to build and push images for Golang projects without a need to define the Dockerfile.

Using all those tools and infrastructure, we can learn how everything can work together and have insights to use in our projects and products.

What to do next:

 - Learn a bit more about `ko`: https://github.com/google/ko
 - Blog post about Golang and OpenFaaS: https://www.openfaas.com/blog/golang-serverless/
 - Discover more tools and functions in the OpenFaaS ecosystem: https://github.com/openfaas
 - Next KubeCon will the KubeCon US and will happen on October 11-15, 2021:  https://events.linuxfoundation.org/kubecon-cloudnativecon-north-america/
 - Follow the [@CloudNativeBot](https://twitter.com/CloudNativeBot)
 - Post a message for the bot and watch a Kubecon video suggestion or discover the logos of the CNCF CloundNative TV shows!
