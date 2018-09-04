---
title: Introducing stateless microservices for OpenFaaS
description: Alex walks us through the latest addition to OpenFaaS - full support for stateless microservices giving an example of a guestbook written in Ruby with Sinatra
# date: 2018-09-06
date: 2018-09-04
image: /images/stateless-microservices/mixed-services.jpg
categories:
  - kubernetes
  - swarm
  - microservices
author_staff_member: alex
dark_background: true
---

I want to share some news with you - we've merged and released support for stateless microservices in [OpenFaaS 0.9.0](https://github.com/openfaas/faas/releases/0.9.0). This means you can take advantage of OpenFaaS as a single pane of glass to manage your microservices and functions - from the CLI to the Prometheus metrics to the built-in auto-scaling, even scaling to zero and back again. I'll walk you through deploying a Ruby and Sinatra guestbook based by MySQL running on OpenFaaS with Kubernetes.

## What's a Function?

Before getting into what a "stateless microservice" is, let's go back to my definition of a "FaaS Function" as defined in my blog post: [Functions as a Service (FaaS) (Jan 2017)](https://blog.alexellis.io/functions-as-a-service/).

Functions tend to invoke:

* invoking short-lived functions (Lambda has a default 1-sec timeout)
* does not publish TCP services - often accesses third-party services or resources
* tends to be ad-hoc/event-driven such as responding to webhooks
* should deal gracefully with spikes in traffic
* despite name, runs on servers backed by a fluid, non-deterministic infrastructure
* when working well makes the complex appear simple
* has several related concerns: infrastructure management, batching, access control, definitions, scaling & dependencies

Over the last year I've simplified this defintion into a number of properties.

Functions are:

* stateless
* emphemeral & short-lived
* auto-scaling
* single-purposed

Functions are stateless because they do not rely on internal state-machines, stored files or sessions. Each call to the function should result in the same end-result. They don't have to be strictly idempotent, but they are easier to manage when they are.

Functions are emphemeral because at any point they should be able to be replaced by any similar variant. This property means that all functions can be managed in the same way - from their health-check to their lifecycle, logging and monitoring.

Functions auto-scale either from a minimum replica count to a maximum count, or even down to zero and back again to match demand or to conserve resources.

Functions are single purposed, but common sense must prevail. We do not need to create a new FaaS function every time we write `function x() {}` or `def x:` in our code. A single purpose may be "CRUD for an employee record", "format this IBAN" or "identify the contents of this image using a machine learning model".

If you've written at least one serverless function then you'll be aware that the entrypoint is often abstracted away from you. You just write a handler and you're done - any dependencies are then expressed in a common format such as a `package.json` for Node.js or a `requirements.txt` file for Python.

Here's an example of a Node.js function:

```
"use strict"

module.exports = (context, callback) => {
    callback(undefined, {status: "done"});
}
```

As a developer you should have no knowledge of the mechanics used to bootstrap the handler - this is the boring, repetitive detail that you can off-load to a FaaS framework or toolkit.

We see a similar pattern of abstraction and off-loading of boring details with microservices frameworks like [Sinatra](http://sinatrarb.com), [Django](https://www.djangoproject.com) and [Express.js](https://expressjs.com). One size rarely fits all needs, so several options exist for each language or runtime.

## What's a stateless microservice?

A stateless microservice is a microservice which can be deployed as if it were a FaaS Function and managed by a FaaS framework or Platform such as OpenFaaS. For this reason no special routes, flags or filters are needed in the OpenFaaS CLI, Gateway API or UI. 

As far as the OpenFaaS components are concerned a function is written in any language and packaged in a Docker image. It must serve content over HTTP on port 8080 and write a lock file to `/tmp/.lock`. If your function or service detects it is unhealthy then you can remove the lock file and OpenFaaS will restart/reschedule your function.

OpenFaaS has a Ruby language template which can be used to create Ruby FaaS functions. A Ruby stateless microservice is a Ruby microservice created with [Ruby on Rails](https://rubyonrails.org), Sinatra or some other Ruby microservice framework. The primary difference is that you have more work to do than with a FaaS function. Now you have to manage your own Dockerfile, health-checks and routes.

Sinatra is a DSL or framework for Ruby for building microservices rapidly.

Here's the hello-world example from the official website:

```ruby
require 'sinatra'

get '/frank-says' do
    'Put this in your pipe & smoke it!'
end
```

If we saved this file as `main.rb` and ran `gem install sinatra` followed by `ruby main.rb` a web-server would come up on the default port of 5678 and then we could navigtate to the `/frank-says` URL.

The OpenFaaS CLI can template, build and deploy this microservice. The OpenFaaS platform will then track metrics for the invocations of the microservice and auto-scale it up, down or even to zero and back again.

## Create the Sinatra stateless microservices

Let's create a stateless microservice with Sinatra. You'll need OpenFaaS deployed and the OpenFaaS CLI before you go any further install them here: [Deployment](https://docs.openfaas.com/deployment/).

### Create a hello-world service

First of all create a new folder and generate a `dockerfile` function. The `dockerfile` template tells the OpenFaaS CLI to run a Docker build without applying any additional scaffolding or templating, you'll have to supply your own Dockerfile.

```bash
mkdir -p sinatra-for-openfaas/
cd sinatra-for-openfaas/

faas-cli new --prefix=alexellis2 --lang dockerfile frank-says
```

Replace `alexellis2` with your Docker Hub account or another Docker registry. A Docker image will be pushed here as part of the build / `faas-cli up` command.

This will create two files, just like if you'd created a function using one of the languages listed on `faas-cli new`:

```bash
./frank-says/Dockerfile
./frank-says.yml
```

Create a `Gemfile` and the `main.rb` file:

`./frank-says/main.rb`:

```ruby
require 'sinatra'

set :port, 8080
set :bind, '0.0.0.0'

get '/' do
    'Frank has entered the building'
end

get '/logout' do
    'Frank has left the building'
end
```

All FaaS functions and stateless microservices must listen on a consistent port which is TCP/8080.

`./frank-says/Gemfile`:

```Gemfile
source 'https://rubygems.org'
gem "sinatra"
```

Any list of gems can be added in this file.

Now replace the `./frank-says/Dockerfile` with:

```Dockerfile
FROM ruby:2.4-alpine3.6
WORKDIR /home/app
COPY    .   .
RUN bundle install
RUN addgroup -S app \
  && adduser app -S -G app
RUN chown app:app -R /home/app
WORKDIR /home/app

RUN touch /tmp/.lock
HEALTHCHECK --interval=2s CMD [ -e /tmp/.lock ] || exit 1

CMD ["ruby", "main.rb"]
```

The Dockerfile does the following:

* Adds a non-root user
* Adds the Ruby source and Gemfile then installs the `sinatra` gem
* Adds a healthcheck and temporary lock file required by OpenFaaS.
* Sets the start-up command

#### Deploy the example

Now you're ready to build and deploy the example using the OpenFaaS CLI.

```bash
docker login    # Login with your account details

faas-cli up --yaml frank-says.yml

Deploying: frank-says.

Deployed. 200 OK.
URL: http://127.0.0.1:8080/function/frank-says
```

Invoke your microservice with `curl` or view it in a web-browser:

```bash
$ curl http://127.0.0.1:8080/function/frank-says/
Frank has entered the building.
```

You can also try a custom route:

```
$ curl http://127.0.0.1:8080/function/frank-says/logout
Frank has left the building.
```

You can try updating the messages or adding some other routes then run `faas-cli up` again to redeploy the microservice.

Now check out `faas-cli list` to see the invocation count rising each time you access the microservice.

```
$ faas-cli list
Function                        Invocations     Replicas
frank-says                      5               1
```

#### Trigger auto-scaling

We can now trigger auto-scaling with a simple bash `for` loop:

```
for i in {1..10000} ; do sleep 0.01 && curl http://127.0.0.1:8080/function/frank-says && echo ; done
```

In another window enter: `watch faas-cli list` or run `faas-cli list` periodically. You should see the value for `Inovcations` increase and the `Replicas` increase as auto-scaling kicks in.

```
Function                        Invocations     Replicas
frank-says                    	702            	4 
```

When your bash `for` loop completes or when you cancel it with Ctrl+C you will see the replica count decrease back to `1`.

You can also use the OpenFaaS UI to monitor and invoke the microservice at http://127.0.0.1:8080

![](/images/stateless-microservices/frank-says.png)

Read more on auto-scaling including how to [configure min, max and zero replica scaling parameters](https://docs.openfaas.com/architecture/autoscaling/).

### Deploy the Sinatra guestbook with MySQL

```
git clone https://github.com/openfaas-incubator/openfaas-sinatra-guestbook
cd openfaas-sinatra-guestbook
```

Configure your MySQL database details in `./sql.yml`. If you don't have access to MySQL you can deploy it using [helm](https://github.com/helm/charts/tree/master/stable/mysql) on Kubernetes.

```
cp sql.example.yml sql.yml
```

Finally deploy the guestbook:

```
faas-cli up

http://127.0.0.1:8080/function/guestbook
```

Use the URL given to you by the command above to access the microservice.

Sign the guest book using the UI and when you're done you can reset the MySQL table at any time by posting to `/function/guestbook/reset`.

![](/images/stateless-microservices/signed.png)

This guestbook is stateless so it stores its state in a MySQL table meaning each auto-scaled replica gets the exact same view of the world. This is a key part of a stateless microservice.

#### Enable Zero-Scale

To enable zero-scale, simply [follow the documentation](https://docs.openfaas.com/architecture/autoscaling/) to enable the `faas-idler`.

Then add a label to your `stack.yml` file to tell OpenFaaS that your function is eligible for zero-scaling:

`com.openfaas.scale.zero: true`

Finally redeploy the guestbook with `faas-cli up`. The faas-idler will now scale your function to zero replicas as soon as it is detected as idle.

## Wrapping up

We've now deployed a simple hello-world Sinatra service and a more complete guestbook example using MySQL, ebs views, Bootstrap and Sinatra. It's over to you to start simplifying your developer workflow with OpenFaaS - whether you want to use FaaS Functions or just make it easier to manage your microserviecs.

For questions, comments and suggestions follow us on [Twitter @openfaas](https://twitter.com/openfaas) and join the [Slack community](https://docs.openfaas.com/community).
