---
title: "Build ASP.NET Core APIs with Kubernetes and OpenFaaS"
description: In this tutorial I'll show you how to build an ASP.NET Core API that you can deploy to Kubernetes easily using OpenFaaS.
date: 2019-12-03
image: /images/2019-asp-net-core/background.jpg
categories:
  - serverless
  - paas
  - kubernetes
  - kubecon
  - events
author_staff_member: alex
dark_background: true

---
In this tutorial I'll show you how to build an ASP.NET Core API that you can deploy to [Kubernetes](https://kubernetes.io/) easily using [OpenFaaS](https://openfaas.com/). We'll be using steps from the official tutorial provided by the [.NET team](https://devblogs.microsoft.com/dotnet/) and explaining any custom steps taken along the way.

# Why is OpenFaaS + ASP.NET Core a good combination?

ASP.NET Core provides a high-performance, lean, and portable runtime that enterprises can use to build robust APIs. The .NET team has worked hard to provide upgrade paths for companies with existing codebases and where that isn't an option, the familiar language can mean that moving code across from legacy code-bases can be done piecemeal.

<img src="https://github.com/openfaas/media/raw/master/OpenFaaS_logo_stacked_opaque.png" width="150px"/>&nbsp;<img src="/images/2019-asp-net-core/netcore.png" width="150px"/>

Kubernetes is the de-facto platform for cloud deployments, but has a significant learning-curve and is hard to get right. [OpenFaaS](https://openfaas.com/) provides a developer-focused abstraction on top of Kubernetes so that you only have to care about building your code and don't need to spend weeks learning Kubernetes and then keeping up with every change.

> What did you just say? "We're not ready for Serverless yet"? "We're still trying to learn all the ins and outs of Kubernetes" That's reason OpenFaaS was created and exists today, to push these details down the stack so that your team doesn't have to care about them. OpenFaaS provides a cloud native stack for applications developers. Read more about [The PLONK Stack](https://blog.alexellis.io/getting-started-with-the-plonk-stack-and-serverless/)

## Pre-reqs

We'll need to install .NET along with some additional tooling for OpenFaaS.

The complete code example is [available on GitHub](https://github.com/alexellis/aspnetcore-openfaas-tutorial).

### Setup OpenFaaS

It's assumed that you already have Kubernetes and OpenFaaS set up, but if you do not then [k3d](https://github.com/rancher/k3d), [KinD](https://kind.sigs.k8s.io), and [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/) can make good local options. I like working with remote clusters since they don't affect the battery life of my laptop, or the CPU/memory of my desktop and are always ready. A good option for a cheap remote cluster may be [DigitalOcean.com](https://digitalocean.com) or [Civo.com](https://civo.com/).

I'll provide two resources for you to get started:

* [OpenFaaS Deployment on Kubernetes](https://docs.openfaas.com/deployment/kubernetes/) - start here if you're confident with deploying Kubernetes
* [OpenFaaS step-by-step workshop](https://github.com/openfaas/workshop) - start here if Docker and Kubernetes are brand new to you

### Install .NET Core 3.1

Head over to the following site and download .NET Core for your OS, 2.2 will also work if that's what you're currently using:

[.NET Core 3.1 download page](https://dotnet.microsoft.com/download/dotnet-core/3.1)

I recommend you download the installer and the SDK.

The .NET product automatically reports telemetry, you can [turn this off](https://docs.microsoft.com/en-gb/dotnet/core/tools/telemetry) if you wish. I added `DOTNET_CLI_TELEMETRY_OPTOUT` to my `$HOME/.bash_profile` file.

### Install Docker and faas-cli

* Get Docker from [docker.com](https://docker.com)

* Get `faas-cli` for OpenFaaS

```sh
curl -sLFS https://cli.openfaas.com | sudo sh
```

Alternatively [download it from GitHub](https://github.com/openfaas/faas-cli/releases).

## Create a new project with ASP.NET Core

The following steps are based upon the [.NET Tutorial - Hello World Microservice](https://dotnet.microsoft.com/learn/aspnet/microservice-tutorial/intro)

* Check everything installed correctly

```sh
dotnet --info

dotnet --list-sdks
```

* Create the microservice

This uses the `webapi` project type (that's a REST API endpoint)

```sh
dotnet new webapi -o openfaas-api --no-https
```

This is the controller that was generated for us:

```cs
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

namespace openfaas_api.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class WeatherForecastController : ControllerBase
    {
        private static readonly string[] Summaries = new[]
        {
            "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
        };

        private readonly ILogger<WeatherForecastController> _logger;

        public WeatherForecastController(ILogger<WeatherForecastController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IEnumerable<WeatherForecast> Get()
        {
            var rng = new Random();
            return Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateTime.Now.AddDays(index),
                TemperatureC = rng.Next(-20, 55),
                Summary = Summaries[rng.Next(Summaries.Length)]
            })
            .ToArray();
        }
    }
}
```

You can view it with [VSCode](https://code.visualstudio.com) at `./openfaas-api/Controllers/WeatherForecastController.cs`

We need to package the service in a container for OpenFaaS to be able to serve traffic, but for now let's try it out locally.

* Test the service outside of a container

```sh
cd openfaas-api/
dotnet run
```

Then access the URL given such as http://localhost:5000 - add `WeatherForecast` to the path to form the URL for the controller: `http://localhost:5000/WeatherForecast`

![](/images/2019-asp-net-core/local.png)

Now hit Control + C.

* Get it into a Docker container

You'll need [Docker installed](https://docker.com/), so check that it's present with:

```sh
docker --version
```

We'll simply use the example [from the tutorial](https://dotnet.microsoft.com/learn/aspnet/microservice-tutorial/docker-file), but edit it for the name we picked:

```Dockerfile
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /src
COPY openfaas-api.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c release -o /app

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "openfaas-api.dll"]
```

Save this file in the openfaas-api folder

The `restore` step is done before the `COPY . .` step, so that Docker can apply caching and avoid running `dotnet restore` unnecessarily.

The team have also used a multi-stage build so that the Docker image that ships only has the runtime components available and not any SDKs, which bulk out the image.

Now create `openfaas-api/.dockerignore`, this file tells Docker to ignore any obj or bin files we create when debugging outside of Docker.

```
Dockerfile
[b|B]in
[O|o]bj
```

We should also create a `openfaas-api/.gitignore` file to prevent us committing any build output to git.

Run: `cp .dockerignore .gitignore`

* Create an OpenFaaS stack.yml file

Let's use the OpenFaaS template called `dockerfile` to define a new template for the project and call it `api`.

```sh
faas-cli new --lang dockerfile api
```

Now you'll see a folder generated called `api` containing a `Dockerfile` and `api.yml`

Let's edit stack.yml and have it point at our `Dockerfile` we created earlier:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080

functions:
  api:
    lang: dockerfile
    handler: ./api
    image: api:latest
```

* Let's rename the file to the default `stack.yml`
* And also change the `handler` folder to point at the existing folder
* Then add our Docker Hub username or private Docker container registry as a prefix to `image:` 

```yaml
# The text above remains the same

functions:
  api:
    lang: dockerfile
    handler: ./openfaas-api
    image: alexellis2/api:latest
```

You should now have:

```
./stack.yml
./openfaas-api/
./openfaas-api/Dockerfile
./openfaas-api/Program.cs
./openfaas-api/Controllers/WeatherForecastController.cs
# etc
```

* Attempt to build your OpenFaaS image

```sh
faas-cli build

Successfully built 1507c4b8b07b
Successfully tagged alexellis2/api:latest
Image: alexellis2/api:latest built.
[0] < Building api done.
[0] worker done.
```

You should see the image built successfully, but we need to make a couple of additional tweaks before we can ship this.

* Add the OpenFaaS watchdog

The OpenFaaS API expects Docker images to conform to a [runtime workload contract](https://docs.openfaas.com/reference/workloads/), we can either implement that in our code by changing the HTTP port and adding a health-check, or by using the [OpenFaaS watchdog component](https://docs.openfaas.com/architecture/watchdog/).

```Dockerfile
FROM openfaas/of-watchdog:0.7.2 as watchdog

FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /src
COPY openfaas-api.csproj .
RUN dotnet restore
COPY . .
RUN dotnet publish -c release -o /app

FROM mcr.microsoft.com/dotnet/core/aspnet:3.1
WORKDIR /app
COPY --from=build /app .
COPY --from=watchdog /fwatchdog /usr/bin/fwatchdog
RUN chmod +x /usr/bin/fwatchdog

ENV fprocess="dotnet openfaas-api.dll"
ENV upstream_url="http://127.0.0.1:80"
ENV mode="http"

ENTRYPOINT ["fwatchdog"]
```

The changes add the `fwatchdog` process as the entrypoint to the container. It receives all incoming HTTP traffic and forwards it to the port exposed by .NET Core on `TCP/80`, it also adds a health-check for Kubernetes and metrics / instrumentation with Prometheus.

> See also: [OpenFaaS workloads](https://docs.openfaas.com/reference/workloads/)

You can run the Docker image locally as a test before deploying it to OpenFaaS.

```sh
faas-cli build

docker run --rm -p 8080:8080 -ti alexellis2/api
```

Then access the site as before: `http://localhost:8080/WeatherForecast`

Hit Control + C when you're done.

* Deploy on Kubernetes with OpenFaaS

Now we can deploy to Kubernetes using OpenFaaS and `faas-cli`.

```sh
export OPENFAAS_URL="" # Set a remote cluster if you have one available

faas-cli up
```

The `faas-cli up` command runs the following:

* `faas-cli build` to output a local Docker image
* `faas-cli push` to transfer the image into a registry the Kubernetes cluster can access
* `faas-cli deploy` the OpenFaaS API will create Kubernetes objects within the cluster and start the Pod

The name of the endpoint is `api`, so we can now access the endpoint through a set URL:

```
# Synchronous

$OPENFAAS_URL/function/api

# Asynchronous / queued

$OPENFAAS_URL/async-function/api
```

You can view logs with `faas-cli logs api`

And check any other status and invocation metrics with `faas-cli describe logs`.

* View the OpenFaaS UI

![](/images/2019-asp-net-core/openfaas-ui.png)

You can view your endpoint in the OpenFaaS UI, but note that invoke will go to the `/` route, for which we have no listener at present.

## Taking things further

* Templates for C#

We used a `dockerfile` template which uses your provided Dockerfile. I picked that option to show you how easy it is to adapt any existing code that you may have. Part of the value OpenFaaS can deliver is that it can abstract away the Dockerfile and any boilerplate code you may normally have to write.

We can do the same for C# and there's at least three templates you may be interested in which are in the function store:

```
faas-cli template store list |grep csharp

csharp                   openfaas           Classic C# template
csharp-httprequest       distantcam         C# HTTP template
csharp-kestrel           burtonr            C# Kestrel HTTP template
```

You can think of `faas-cli new` as performing the same job as `dotnet new`, but the tool can hide away the Dockerfile and gory details if you prefer to work that way.

The `csharp-kestrel` template looks like this:

```cs
using System;
using System.Threading.Tasks;
 
namespace Function
{
    public class FunctionHandler
    {
        public Task<string> Handle(string input)
        {
            return Task.FromResult($"Hello! Your input was {input}");
        }
    }
}
```

It's hard to argue that the code above isn't easier to maintain than the full instructions we went through for the ASP.NET Core example from the .NET team, however I believe that both are valid use-cases for OpenFaaS and Kubernetes users.

* Templates for other languages

Here's an example of the `golang-middleware` template which reduces an entire Golang microservice down to a couple of lines:

```sh
faas-cli template store pull golang-middleware

faas-cli new --lang golang-middleware logger
```

Here's what we got:

```
logger.yml
logger/handler.go
```

And the contents of the logger:

```golang
package function

import (
        "fmt"
        "net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {
    log.Println(w.Header)
}
```

* Find out details about templates

You can run `faas-cli template store describe <NAME>` to discover the GitHub repo and author behind each template.

The templates go through basic quality control upon submission to ensure a small Docker image, a non-root user and that each README file has detailed usage examples.

```sh
faas-cli template store describe csharp-kestrel

Name:              csharp-kestrel
Platform:          x86_64
Language:          C#
Source:            burtonr
Description:       C# Kestrel HTTP template
Repository:        https://github.com/burtonr/csharp-kestrel-template
Official Template: false
```

* Auto-scaling

OpenFaaS has built-in auto-scaling rules based upon requests per second, and support for [Kubernetes HPAv2 also](https://docs.openfaas.com/tutorials/kubernetes-hpa/).

[![OpenFaaS workflow](https://github.com/openfaas/faas/blob/master/docs/of-workflow.png?raw=true)](https://docs.openfaas.com/architecture/stack/)

Try [Lab 9 of the OpenFaaS workshop](https://github.com/openfaas/workshop#lab-9---advanced-feature---auto-scaling), where you can learn how to test auto-scaling for your new ASP.NET Core application.

* Secrets and API keys

You can learn how to securely manage APIs and secrets using the [lessons in Lab 10](https://github.com/openfaas/workshop#lab-10---advanced-feature---secrets)

* Versioning of .NET runtimes

You may find that for various reasons you need to support .NET Core 2.0, 2.1, 2.2 and even 3.1 all at the same time.

That's fine, you can create different templates or you can just specify the runtime for each service in the `Dockerfile` we created earlier.

* 12-factor configuration

You can apply 12-factor configuration through the `environment` section of your OpenFaaS stack.yml file.

See also: [Lab 4: Inject configuration through environmental variables](https://github.com/openfaas/workshop/blob/master/lab4.md)

## Wrapping up

In a short period of time we were able to deploy an ASP.NET Core application using .NET 3.1 or 2.x to Kubernetes, have it scale out and build into an immutable Docker image. OpenFaaS made this task much simpler than it would have been if we'd tried to program directly against Kubernetes.

If you aren't quite convinced yet, then watch my KubeCon talk on the PLONK Stack that combines [OpenFaaS](https://openfaas.com/) with Kubernetes and several other CNCF projects like [Prometheus](https://prometheus.io) and [NATS](https://nats.io/) to create a platform for application developers.

* Video: [More than FaaS - Introduction to The PLONK Stack @ KubeCon](https://blog.alexellis.io/getting-started-with-the-plonk-stack-and-serverless/)

Your input and feedback is welcome. Please join the community Slack workspace and bring any comments, questions or suggestions that you may have.

* [OpenFaaS Slack](https://slack.openfaas.io)

Finally, feel free to reach out if you need help with any cloud native problems you're trying to solve, or if you could use an external perspective on what you're building from OpenFaaS Ltd: [alex@openfaas.com](mailto:alex@openfaas.com).
