---
title: "Using OpenFaas to run a fun twitter bot"
description: "Using OpenFaas to run a fun twitter bot"
date: 2021-05-20
image: /images/2021-05-cnbot/background-twitter.png
categories:
 - twitter-bot
 - use-cases
 - functions
author_staff_member: cpanato
dark_background: true

---

Learn how Openfaas and connector-sdk can be used to run a Twitter bot

## Introduction

Bots are everywhere. Some are useful that can help you in your daily work, and others are collecting information about you to use to make an advertisement, and there are others to be fun and entertaining.

The [@CloudNativeBot](https://twitter.com/CloudNativeBot) was created to bring some fun and also to users to use it to get some knowledge. The bot has some slash commands that can be triggered by posting a message on Twitter.

The behind the technology that the bot uses will be explained in this blog post.

## Pre-requisites

* [Docker or Docker Desktop](https://www.docker.com/products/docker-desktop)
* OpenFaaS
* faas-cli
* [connector-sdk](https://github.com/openfaas/connector-sdk)
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
    User:     Config.OpenFaasUsername,
    Password: Config.OpenFaasPassword,
  }

  config := &types.ControllerConfig{
    RebuildInterval:         time.Millisecond * 1000,
    GatewayURL:              Config.OpenFaasGateway,
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

To deploy this service, we are using `ko` with is an excellent tool, and we don't need to define a docker file; you can build and push the container right away and have your Kubernetes manifests configured with that image.

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

### Using OpenFaas functions for the slash commands

We are using OpenFaas to deploy the slash command functions for the bot, and those will be triggered by the connector-sdk code we show above.

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


### Wrap up

Using OpenFaas and the connector-sdk we were able to bootstrap the project in a quick way and have each function very well defined and scoped.

`ko` is a handy tool that helps to build and push images for golang projects without a need to define the Dockerfile.

Using all those tools and infrastucture we can learn a bit how everything can work together and have insights to use in our projects and products.

If you like it, post a message for the bot and watch a Kubecon video suggestion or discover the logos of the CNCF CloundNative TV shows!
