---
title: "A snowman's journey: Lambda to OpenFaaS"
description: Richard Gee showcases a holiday project which demonstrates adding voice control to OpenFaaS functions using an Alexa skill and moving the handling function out of AWS Lambda onto OpenFaaS alternatives.
date: 2019-01-25
image: /images/lambda-to-openfaas-with-skill/background-brown-christmas.jpg
categories:
  - alexa
  - lambda
  - cloud
author_staff_member: richard
dark_background: true
---

As the festive season started to approach, as it tends to on a fairly regular and annual basis, I decided to revisit a project from the previous year where I used Amazon Echo to control a festive decoration.  The _smart_ festive decoration remains synchronised with the colour of devices across the globe using the current [Cheerlights](http://cheerlights.com/) colour. 

Inside the decoration is a Raspberry Pi ZeroW with a [Pimoroni](https://shop.pimoroni.com/) [Blinkt](https://shop.pimoroni.com/products/blinkt) attached.  The Pi runs Docker and a small golang binary based on Alex’s [Blinkt! golang library](https://github.com/alexellis/blinkt_go/), which periodically checks the [Cheerlights](http://cheerlights.com/) API and sets the colour of the Blinkt accordingly.  For more on how to configure the Pi see [Alex's blog](https://blog.alexellis.io/festive-docker-lights/).

![Snowman and Pi ZeroW](/images/lambda-to-openfaas-with-skill/pi_snowman.jpg)

[Cheerlights](http://cheerlights.com/) enables people to change the current colour via Twitter, which means that the overall system covered here is asynchronous; the Alexa skill sets the [Cheerlights](http://cheerlights.com/) colour through an interaction with the Twitter API and the Pi hosted within the decoration will pick up that change from the Cheerlights API.

The initial implementation used Lambda as the code execution engine, this is typically the route that Alexa skill blogs and tutorials follow.  In 2017 the approach changed slightly with the handler function moving out of AWS Lambda onto OpenFaaS - the Alexa skill triggered an OpenFaaS function running on a Raspberry Pi.  Finally, for this season's holiday, the handling function moved to [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/) Community Cluster to add a Git-based workflow to the Alexa skill endpoint.

## Alexa Skills
The first consideration in creating a voice enabled function is that of how the human will converse with Alexa in order to invoke the function - the _Voice User Interface_.  In order to configure this, access to the [Alexa skills console](https://developer.amazon.com/alexa) is required.  For brevity, only the outline will be covered here - there is a wealth of resources already available covering how to create an Alexa skill through the skills console.

### Invocation 

Keeping it simple:

```
Alexa, ask the snowman...
```

### Intents

Intents are effectively actions that will be requested following the invocation. Within each intent there can be multiple utterances - this is important as the utterance should be natural and there are multiple natural ways to request the same action.  Initially there were three intents, with a fourth added for a bit of fun during the migration to OpenFaaS.

* currentColour

With the following utterances
```
the colour
for the current colour
what the current colour is
what colour it is
```
* listColours

With the following utterances
```
what are the available colours
for available colours
for colours
which colours are available
which colours he can change to
for a list of available colours
```
* changeColour

With the following utterances
```
to change to {Colour}
to change colour to {Colour}
to turn {Colour}
```

### Slots

Within the `changeColour` intent an argument called `Colour` is used, these are referred to as _slots_.  Slot types are a list of possible values for a slot, a custom list can be created if one doesnt already exist within Amazon.  As the list of snowman colours is specified by Cheerlights a custom slot type was created.

* LIST_OF_COLOURS

```
red,
green,
blue,
cyan,
white,
warmwhite,
purple,
magenta,
yellow,
orange,
pink,
```

### Putting it together

With the intents, utterances and slots in place we can build a picture of how the voice user interface might sound:

* Alexa, ask the snowman for the current colour
* Alexa, ask the snowman for a list of available colours
* Alexa, ask the snowman to turn green

How Alexa responds to these requests vocally, and the actions triggered thereafter are defined within the function code.

## Function Code

Each interaction with Alexa about the snowman will generate a body of JSON which will be passed to our function code.  We can inspect the JSON to determine the event type and if its an intent request interrogate the session detail in order to find the requested action and trigger the approapriate response. Here is the original code that started life hosted on Lambda:

<script src="https://gist.github.com/rgee0/4a825ceff3f9b4347fc88156ff96eab3.js"></script>


## Implementations

The overall interaction with the _Voice User Interface_ doesnt change throughout these implementations.  There are small changes required in the code as the snowman transitions between the different hosting environments and the endpoint configured within the [Alexa skills console](https://developer.amazon.com/alexa) will obviously require updating.

### Lambda

The orignal code is shown in the introduction above.  In this case the whole system is within the Amazon ecosystem which means we can use an the Lambda function's ARN as the specified endpoint.

![System flow using AWS Lambda](/images/lambda-to-openfaas-with-skill/snowman_lambda.png)

Additionally six Lambda environment variables are used, two of these test that the event has arrived from the expected source.  The remaining 4 are Twitter API access tokens and keys.  These were all added through the Lambda console.

### OpenFaaS

Here the function execution moved onto a Raspberry Pi residing on the home network.  OpenFaaS has been supported on the Raspberry Pi since the very beginning - for more on how to set up a Pi cluster running OpenFaaS see [Alex's blog](https://blog.alexellis.io/your-serverless-raspberry-pi-cluster/).  An additional component is needed in this configuration in order to expose an HTTPS endpoint - an AWS requirement - to the Internet; ngrok was utilised on the Pi to achieve this.  The [Alexa skills console](https://developer.amazon.com/alexa) endpoint needed to be swapped from the existing ARN to the HTTPS endpoint offered via ngrok.

> Note: since implementing this method a shorter ngrok timeout period has come into effect. 

![System flow using Pi based OpenFaaS](/images/lambda-to-openfaas-with-skill/snowman_openfaas.png)

#### Code changes

Little change was required to move the function from Lambda to OpenFaaS.  The signature of the handler changes slightly and the environment variables are instead read from secrets.  An additional intent was also added at this point, so Alexa could be asked how the snowman functions.

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Added an additional intent and associated utterances to celebrate successfully moving the snowman function onto <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> <a href="https://twitter.com/hashtag/faasfriday?src=hash&amp;ref_src=twsrc%5Etfw">#faasfriday</a> <a href="https://twitter.com/hashtag/teamserverless?src=hash&amp;ref_src=twsrc%5Etfw">#teamserverless</a> <a href="https://t.co/KO0LHgIWbq">https://t.co/KO0LHgIWbq</a></p>&mdash; Richard Gee (@rgee0) <a href="https://twitter.com/rgee0/status/936676255746985986?ref_src=twsrc%5Etfw">December 1, 2017</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

First create a new function using the CLI:

```
$ faas new --lang=python-armhf --prefix=rgee0 snowman
```

Then add the exisitng code to `snowman/handler.py` making the following changes:

```python
def lambda_handler(event, context):
    
    if (event['session']['application']['applicationId'] != os.environ['appID']):
        raise ValueError("Invalid Application ID")
    
    if (event['session']['user']['userId'] != os.environ['userID']):
        raise ValueError("Invalid user ID")
```

becomes:

```python
def handle(req):

    with open("/var/openfaas/secrets/appid", "r") as appid:
        app_id = appid.read().strip()

    if event['session']['application']['applicationId'] != app_id:
        raise ValueError("Invalid Application ID")

    with open("/var/openfaas/secrets/userid", "r") as userid:
        user_id = userid.read().strip()

    if event['session']['user']['userId'] != user_id:
        raise ValueError("Invalid user ID")
```

and

```python
auth = tweepy.OAuthHandler(os.environ['consumer_key'], os.environ['consumer_secret'])
auth.set_access_token(os.environ['access_token'], os.environ['access_secret'])
```

becomes:

```python
with open("/var/openfaas/secrets/consumerKey", "r") as consumerkey:
    consumer_key = consumerkey.read().strip()
with open("/var/openfaas/secrets/consumerSecret", "r") as consumersecret:
    consumer_secret = consumersecret.read().strip()

auth = tweepy.OAuthHandler(consumer_key, consumer_secret)

with open("/var/openfaas/secrets/accessToken", "r") as accesstoken:
    access_token = accesstoken.read().strip()
with open("/var/openfaas/secrets/accessSecret", "r") as accesssecret:
     access_secret = accesssecret.read().strip()

auth.set_access_token(access_token, access_secret)
```

Use the CLI to create the secrets used above:

```
$ faas-cli secret create appid --from-literal "$APPID" && \
   faas-cli faas-cli secret create userid --from-literal "$USERID" && \
   faas-cli faas-cli secret create consumerKey --from-literal "$CONSUMERKEY" && \
   faas-cli faas-cli secret create consumerSecret --from-literal "$CONSUMERSECRET" && \
   faas-cli faas-cli secret create accessToken --from-literal "$ACCESSTOKEN" && \
   faas-cli faas-cli secret create accessSecret --from-literal "$ACCESSSECRET"
``` 

Edit `snowman.yml` to specify the secrets at deployment:

```
    secrets:
     - appid
     - userid
     - consumerKey
     - consumerSecret
     - accessToken
     - accessSecret
```

Next, because Python packages are included at build time, rather than through a zip upload whuch is familiar with Lambda, add dependent modules to `requirements.txt`.

```
tweepy
```

Finally, build, push & deploy:

```
$ faas up -f snowman.yml
```

### OpenFaaS Cloud

OpenFaaS Cloud is a multi-user OpenFaaS platform that enables developers to build and deploy OpenFaaS Functions from a public GitHub repository. A `git push` action triggers a GitHub App which will invoke a series of OpenFaaS system functions to build the function and deploy it. The associated GitHub commit is then updated with a passed/failed status, and a HTTPS URL is made available to access the function.  It is this URL which entered in the The [Alexa skills console](https://developer.amazon.com/alexa) once the endpoint is available.

![System flow using OpenFaaS Cloud](/images/lambda-to-openfaas-with-skill/snowman_ofc.png)

The OpenFaaS Cloud in this instance is the community cluster.  To gain access it is necessary to send a PR to the [CUSTOMERS file](https://github.com/openfaas/openfaas-cloud/blob/master/CUSTOMERS) with your GitHub username added to the end.  Once the GitHub account is added as a customer, the GitHub app needs installling and then enabling for the function repo.

#### Code changes

Again, the changes to move between OpenFaaS And OpenFaaS Cloud are minimal.  As the function definition is entirely pulled from GitHub, the approach to configuring secrets has to be a little different.  SealedSecrets mean the secrets are encrypted and so can be committed to the function repo.  OpenFaaS Cloud will decrypt them using the cluster's private key and make them available to the function.

Seal the secrets using the CLI:

```
faas-cli cloud seal --name rgee0-snowman --cert=./pub-cert.pem \
    --literal appid=$APPID \
    --literal userid=$USERID \
    --literal consumerKey=$CONSUMERKEY \
    --literal consumerSecret=$CONSUMERSECRET \
    --literal accessToken=$ACCESSTOKEN \
    --literal accessSecret=$ACCESSSECRET \
```

This command results in the creation of a `secrets.yml` file:

<script src="https://gist.github.com/rgee0/dd098314ce0b78bc45594340b7cdc611.js"></script>

Edit `snowman.yml` to attach these secrets to the function:

```
    secrets:
     - snowman
```

Push the code:

```
$ git add . && \
    git commit -sm'Add secrets for OpenFaaS Cloud' && \
    git push origin master
```

The build time on the last commit was just over 60 seconds, so a minute or so after pushing, an endpoint is available and the function shows in the dashboard:

![OpenFaaS Cloud Dashboard](/images/lambda-to-openfaas-with-skill/dashboard.png)

## Wrapping Up

We've seen, using a fun and practical example, how easy it is to move your functions from AWS Lambda onto an open source framework such as OpenFaaS.  Also how simple it is to add voice control to your OpenFaaS functions, moving out of what some might have seen as a closed ecosystem.  Why not try adding your own voice control to one of your existing functions?  Or, perhaps taking something like the business strategy generator function from the [OpenFaaS function store](https://blog.alexellis.io/announcing-function-store/) and adapting it so that Alexa reads the result back to you.

Familiarise yourself with [OpenFaaS Cloud](https://docs.openfaas.com/openfaas-cloud/intro/).  Build your own, or join the community cluster and get a HTTPS endpoint within seconds of pushing your code to Github.

For questions, comments and suggestions follow us on [Twitter @openfaas](https://twitter.com/openfaas) and join the [Slack community](https://docs.openfaas.com/community).