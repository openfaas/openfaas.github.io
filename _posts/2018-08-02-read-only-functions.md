---
title: Serverless Security&#58; read-only functions with OpenFaaS
description: Alex Ellis introduces the read-only functions feature for OpenFaaS - a security concept available with containers and Kubernetes to prevent tampering
date: 2018-08-01
image: /images/read-only/railings.jpg
categories:
  - security
  - kubernetes
  - swarm
author_staff_member: alex
---

In this post I'll highlight one of the ways we're making OpenFaaS a more secure environment for your production functions and workloads.

## What is a read-only function?

All functions deployed to OpenFaaS are first built into immutable Docker images. We do this so that you get exactly the same results wherever you want to run your code. Read-only functions are functions which run with an enhanced security profile so that users cannot make changes to the underlying file-system in the container. This protects the underlying filesystem, shared libraries and the code for the function.

We also use a read-only file-system in the OpenFaaS API Gateway which provides a REST API and user-friendly UI for your functions.

## How does it work?

In both Kubernetes and Docker Swarm, we enabled a feature in the built-in security context to make the root file-system `/` read-only. Before we applied this patch to the OpenFaaS providers we also changed all the OpenFaaS templates to run as non-root users to prevent tampering with system files, this change goes one step further and prevents a function from tampering with its own code.

To see this in action with a regular Docker container try the following:

```bash
docker run --rm -ti --read-only alpine:3.7

# apk add --no-cache curl
ERROR: Unable to lock database: Read-only file system
ERROR: Failed to open apk database: Read-only file system
```

A read-only file-system is highly recommended for your functions to prevent tampering.

![](/images/read-only/conceptual.png)

*Above: Conceptual diagram showing an altered container and a read-only container*

### How do I try it?

This feature is released and available with the latest versions of OpenFaaS including the CLI (0.6.17), Kubernetes faas-netes & operator (0.8.4/0.6.0) and Swarm (0.4.0) support.

* Create a function

```bash
faas-cli new --lang node overwrite-me --prefix=alexellis2
mv overwrite-me.yml stack.yml
echo "alexellis" > ./overwrite-me/valid_user.txt
```

* Update the function code: `./overwrite-me/handler.js`:

```js
"use strict"

const fs = require('fs');

module.exports = (context, callback) => {
    if(process.env["Http_Query"] == "update=1") {
      fs.writeFile("/home/app/function/valid_user.txt", context, (err) => {
        return callback(err, {action: "update", value: context});
      });
    } else {
        fs.readFile("/home/app/function/valid_user.txt", "utf8", (err, val) => {
            return callback(err, {action: "get", value: val});
        });
    }
}

```

* Build/push/deploy

```
faas-cli build \
 && faas-cli push \
 && faas-cli deploy
```

You can now deploy the function and query the valid user, then try to update it.

```
echo | faas-cli invoke overwrite-me
{"action":"get","value":"alexellis\n"}

echo stefanprodan | faas-cli invoke overwrite-me --query update=1
{"action":"update","value":"stefanprodan\n"}

echo | faas-cli invoke overwrite-me
{"action":"get","value":"stefanprodan\n"}
```

Now let's apply a read-only root file-system and see what that looks like.

Edit your function's stack YAML file and add a property of `readonly_root_filesystem` with a value of `true`:

```yaml
functions:
  overwrite-me:
    lang: node
    handler: ./overwrite-me
    image: alexellis2/overwrite-me:latest
    readonly_root_filesystem: true
```

Now deploy the function and try to update the value to "stefanprodan":

```
faas-cli deploy

echo get | faas-cli invoke overwrite-me 
{"action":"get","value":"alexellis\n"}

echo stefanprodan | faas-cli invoke overwrite-me --query update=1

{ Error: EROFS: read-only file system, open '/home/app/function/valid_user.txt'
  errno: -30,
  code: 'EROFS',
  syscall: 'open',
  path: '/home/app/function/valid_user.txt' }
```

You can now see that the value is never updated and an error is generated.

Read on for what to do if you do need somewhere to write some temporary data such as a process identifier number or other kind of intermediate data.

### What if I want to write to the filesystem?

This feature is opt-in, but we'd suggest using it as a matter of course and we're changing over all the [OpenFaaS Function Store images to run this way](https://github.com/openfaas/store/issues/35).

If you want the best of both worlds, then we have enabled a temporary area for you in the `/tmp` mount. It is emphemeral and is not guaranteed to be available between requests. It is suitable for writing temporary data. 

## What next?

It's now over to you to try out a read-only filesystem with your functions and step up your Serverless Security.

### Try it out

If you'd like to get started with OpenFaaS, then you can deploy with helm, kubectl or Docker Swarm:

* [Docs: deployment](https://docs.openfaas.com/deployment/)

### Star &amp; share

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">Are you using OpenFaaS? Let us know so we can list you on the homepage and docs site <a href="https://t.co/UolMK2uMvA">https://t.co/UolMK2uMvA</a> <a href="https://t.co/EoBVLkZcBv">pic.twitter.com/EoBVLkZcBv</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/1024403113694900224?ref_src=twsrc%5Etfw">July 31, 2018</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

If you're a user of OpenFaaS, then let us know about it so that we can list you on the project homepage:

* [OpenFaaS Users](https://docs.openfaas.com/#users-of-openfaas)

Add your *Star* to the GitHub repo over at [openfaas/faas](https://github.com/openfaas/faas/) because it helps us help you.

