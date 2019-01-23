---
title: Unifying Secrets for OpenFaaS
description: Alex Ellis shows how the community unified the secret experience with Kubernetes, Docker Swarm and other OpenFaaS providers. He will examine secret management for Kubernetes and show a full worked-example of secrets with Slack using the new OpenFaaS CLI.
date: 2019-01-23
image: /images/unified-secrets/barrier-chain-chain-link-fence-951408.jpg
categories:
  - kubernetes
  - swarm
  - developer-experience
  - security
author_staff_member: alex
dark_background: true
---

Today I want to tell you about a new feature released in OpenFaaS that unifies the experience of working with secrets. We introduced the ability to manage secrets in one consistent way whether you are using Kubernetes, Swarm or Nomad. The changes we made to the REST API and CLI simplify the amount of commands you need to learn and remember to manage confidential data used by your functions.

We will start by looking at what I mean by `secret`, some *Dos and Don'ts* and how the new feature works. Then we'll build a full example of an invitation bot you can use with your own Slack workspace.

## What do you mean by a `secret`?

When I say `secret` I am referring to confidential data which needs to be protected from public viewing. This may be an API key, access code or even configuration data which is sensitive such as the name of a database or a validation rule stored as a Regular Expression.

There are various ways to consume passwords in Kubernetes or Swarm.

### Dos and Don'ts

* Don't store secrets in your Docker image with `COPY` or `ADD`

Anyone who can pull the Docker image can see the secret. Even if you use a private registry this makes your confidential data hard to change or update over time.

* Don't configure confidental data using environmental variables

Environmental variables can be used to configure non-confidential data such as feature-flags, verbose logging and in some circumstances the names of other services that you may want to reach. The [12-Factor App Manifesto](https://12factor.net/) may recommend this, but fortunately Kubernetes, Swarm and the OpenFaaS Nomad provider all provide more suitable alternatives.

* Do read the secret in your function from the standard location

Whichever back-end you use with OpenFaaS your secret will be made available in one and only one location:

```
/var/openfaas/secrets/SECRET_NAME
```

This can not be mapped to a different path, so pick a descriptive name that does not clash. If you need your secret value to appear at a certain location, then you can copy the secret or configure your tooling to read it from the new path.

* Do use the secret store of your orchestrator

Kubernetes has a built-in secret store which can be used by OpenFaaS to define and manage secrets. Swarm has its own secret store which also encrypts the secrets at rest.

On Kubernetes:

```bash
# Via a file
kubectl create secret generic fn-api-key --from-file=fn-api-key=fn-api-key.txt

# Or via a literal value
kubectl create secret generic fn-api-key --from-literal=fn-api-key="VALUE_HERE"
```

On Swarm:

```bash
cat fn-api-key.txt | docker secret create fn-api-key -
```

## Why did we build this feature?

It turned out that maintaining two sets of instructions for creating secrets in Kubernetes or Docker Swarm is a lot of work. We first saw this in the [OpenFaaS workshop](https://github.com/openfaas/workshop) where we had to duplicate a lot of content for Kubernetes or Swarm users. Recently the provider for Hashicorp's Nomad orchestrator also gained secrets and so we'd have yet another set of commands for our contributors and users to remember.

### Use the faas-cli

Our `faas-cli` is now a core piece of the OpenFaaS developer-experience and our users run it locally and in their CI jobs, so it seemed like a great place to start.

Create the secret from a text value:

```bash
faas-cli secret create fn-api-key --from-literal "VALUE_HERE"
```

Create the secret from a file:

```bash
faas-cli secret create fn-api-key --from-file fn-api-key.txt
```

In both instances the file will be available in the same standard location whatever the back-end:

```
/var/openfaas/secrets/fn-api-key
```

### Use the REST API

We updated the OpenFaaS REST API so that you can manage secrets via CI or automation, this involved several new operations:

* Create
* List
* Update
* Delete

You'll notice this is not CRUD, but CLUD. We specifically did not want to make the value of secrets available over the API.

Here's how you can create a new secret using the REST API:

```bash
export OPENFAAS_URL=http://

curl -X POST \
  -d '{"name":"fn-api-key","value":"VALUE_HERE"}' \
  http://admin:password@$OPENFAAS_URL/system/secrets
```

Now verify it:

```bash
curl -X GET \
  http://admin:password@$OPENFAAS_URL/system/list
```

## Let's put it all together

Now let's put everything together in an example function we can use to invite new users to our Slack community. You should have OpenFaaS deployed and have run `faas-cli login` already.

You can deploy OpenFaaS in a few minutes [using the documentation](https://docs.openfaas.com/).

Create a directory for our code:

```
mkdir -p ~/dev/slack-inviter
cd ~/dev/slack-inviter
```

### Get a Slack admin token

You'll need to get yourself a free Slack workspace and an admin token for the whole workspace. This key can be used to control the whole workspace, so we need to store it confidentially.

https://api.slack.com/custom-integrations/legacy-tokens

Save your token as: `slack-token` so that we can prevent it being recorded in our bash history.

* Now create the secret

```bash
faas-cli secret create slack-token \
  --from-file=./slack-token
```

Let's create another secret to protect the function itself.

```bash
export SLACK_LOGIN=$(head -c 16 /dev/urandom | shasum | cut -d " " -f 1)
faas-cli secret create slack-login-password \
  --from-literal="$SLACK_LOGIN"
```

### Build a new function

Change `--prefix` to your Docker Hub account or your private registry. Note you will need to use `docker login` before the next step.

```
faas-cli template store pull node10-express && \
faas-cli new --lang node10-express \
   --prefix=alexellis \
   slack-inviter
```

Now edit the resulting YAML stack file: `slack-inviter.yml` and add:

```
    secrets:
     - slack-token
     - slack-login-password
```

Add a dependency to to the `request` module from npm.js so we can call the Slack API.

> You will need the `npm` binary or Node.js on your local machine.

```
cd slack-inviter
npm init -y
npm install --save request
cd ..
```

Now you will see a file `slack-inviter/package.json` created that gives the modules needed for our function.

The format for inviting a new user will be a JSON payload:

```json
{
"first": "alex",
"last": "ellis",
"email": "alex@openfaas.com"
}
```

We will secure the endpoint with basic authentication.

> Note: if you deploy this example to the internet, then make sure you followed one of the guides to enable TLS / HTTPS.

Let's write the code in `./slack-inviter/handler.js`

```js
"use strict"
const request = require('request');
const fs = require('fs');
const passwordFile = "/var/openfaas/secrets/slack-login-password";
const slackTokenFile = "/var/openfaas/secrets/slack-token";

module.exports = (event, context) => {
    fs.readFile(passwordFile, "utf-8", (err, loginPassword) => {
        if(err) {
            return context
            .status(500)
            .succeed({"status": "error", "message": "unable to read secret"});
        }

        if(!validAuth(event.headers, loginPassword.trim())) {
            return context
                .status(401)
                .succeed({"status": "unauthorized"});       
        }
        invite(event.body, (err, res) =>{
            if(err) {
                return context
                .status(500)
                .succeed({"status": "error", "message": "unable to invite user: " + err});
            }
            context.status(202).succeed(res);
        });
    });
}

function invite(payload, cb) {
    fs.readFile(slackTokenFile, "utf-8", (err, token) => {
        if(err) {
            return cb(err, undefined);
        }
        const opts = {
            uri: "https://openfaas.slack.com/api/users.admin.invite",
            form: {
                "email": payload.email,
                "token": token,
                "set_active": true,
                "first_name": payload.first,
                "last_name": payload.last
            }
        };

        request.post(opts, (err, res, body) => {
            if(err) {
                return cb(err, undefined);
            }
            if(!res.statusCode.toString().startsWith("2")) {
                return cb("res", body);
            }
            
            return cb(undefined, body);
        });
    });
}

function validAuth(headers, loginPassword) {
    if(!headers.authorization) {
        return false;
    }

    if(headers.authorization.indexOf("Basic ") > -1) {
        const encoded = headers.authorization.substr("Basic ".length)
        let buf = new Buffer(encoded, 'base64')
        let plaintext = buf.toString('ascii')
        process.stderr.write(loginPassword + " vs " + plaintext);

        if(plaintext == "admin:" + loginPassword) {
            return true
        }
    }
    return false;
}
```

Deploy the function:

```bash
faas-cli up -f slack-inviter.yml
```

Now let's invite someone:

```bash
curl -i \
 -H "Content-Type: application/json" \
 -X POST \
 -d '{"first": "first", "last": "last", "email": "valid-email@domain.com"}' \
 http://admin:password@127.0.0.1:31112/function/slack-inviter
```

> Note: change 127.0.0.1:31112 to the IP address and port of your OpenFaaS API gateway.

If you use an incorrect password you'll receive a 401 error. If you use a bad request body you'll get a 500 error and if everything is correct you'll receive a 202 (Accepted) code for a user who was invited successfully or whom already received an invitation.

## Wrapping up

The addition of Secrets management to OpenFaaS makes it even easier to consume secrets in your functions and lets you take advantage of your orchestrator's secret store whether that be with Kubernetes, Docker Swarm or Nomad.

This project is independent and run by community, so I'd like to thank everyone who was involved in building, testing and documenting this new feature.

Now it's over to you to try the new feature in your local development environment, on your CI servers or simply for the first time. You could also take the example from this blog post and extend it with additional validation or try it out with your own Slack workspace for managing invitations. Perhaps you could combine it with some additional functions or webpages to create a smarter workflow for your community?

* To get started with secrets today update your CLI with `brew` or `curl` utility script over at [https://github.com/openfaas/faas-cli](https://github.com/openfaas/faas-cli).

* For questions, comments and suggestions follow us on [Twitter @openfaas](https://twitter.com/openfaas) and join the [Slack community](https://docs.openfaas.com/community).

* Learn how to contribute on YouTube: [How To Contribute to OpenFaaS](https://www.youtube.com/watch?v=kOgHjU38Efg)
