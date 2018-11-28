---
title: Introducing the Template Store for OpenFaaS
description: Alex Ellis walks us through how OpenFaaS approaches serverless packaging and the new "Template Store" feature making it easy to share and discover custom function templates.
date: 2018-11-28
image: /images/template-store/tea-store.jpg
categories:
  - kubernetes
  - swarm
  - templates
  - developer-experience
author_staff_member: alex
dark_background: true
---

I would like to introduce you to the new *Template Store* feature which has been developed in the community to make it even easier to discover and share custom function templates for your serverless functions. We'll look at how serverless platforms such as AWS Lambda package functions in zip files along with some of the pros and cons. We'll then take a quick look at how OpenFaaS packages functions using the Docker/OCI image format and learn how to discover custom function templates using the new template store feature.

## Serverless packaging

The earliest example of packaging for serverless functions was in 2014 when AWS launched the Lambda product which allowed developers to write a short script in a text-box on a webpage before hitting "save" and deploying that to their production environment. For very short and simple scripts you can't beat a text-box for convenience, but as soon as you move beyond that and start adding pip modules or npm modules then things get harder. Lambda solves this by asking you to run `npm install` or `pip install` on your local computer and then you need to zip the folder and upload it to an S3 bucket.

![](/images/template-store/s3-upload.png)

*Pictured: uploading Lambda package to AWS via S3*

### Drawbacks to zip-files

There are some drawbacks to using zip files for packaging software to run as a function.

* Using native dependencies is hard
* Lack of repeatability
* Poor integration with CI/CD tooling
* Reduced convenience
* Package size limits

Some common Python or Node.js modules need to make use of a native C/C++ toolchain to build their dependencies - these are known as *native dependencies*. Since most modules need to build against shared libraries or modules such as gLibc this makes building such modules very painful and frustrating. Ideally you need a complete replica of the Lambda runtime environment such as a separate Virtual Machine running Amazon Linux in order to build your code's dependencies. 

Assuming you have a VM set up you now need to circulate that within your team and make sure you all use the exact same version. If you don't then the builds being made are no longer repeatable nor portable.

Running a VM or having to build native modules for a different set of shared modules or OS target during CI/CD is problematic and will mean a complicated build environment is needed to apply software delivery best practices. Once a working pipeline is set up the zip files will need to be versioned and stored in a separate artifact store making even more work. This artifact must be uploaded to S3 using tooling such as the AWS CLI which means credential management is also required.

There are many tools which exist to try to address these problems such as [Serverless CLI](https://serverless.com/framework/docs/providers/aws/cli-reference/), [Docker Lambda](https://github.com/lambci/docker-lambda#build-examples) and [Apex](http://apex.run).

One of the things the frameworks and tools above cannot help with is the package size limit enforced by cloud functions providers. At time of writing [Google Cloud Functions](https://cloud.google.com/functions/quotas) shows a 100MB compressed limit and 500MB uncompressed limit for source code, libraries and artifacts. This may suit many of the smaller functions teams need, but when it doesnt then there's really nowhere to go with this.

Developers are adopting Serverless functions in order to streamline their experience and to ship code faster. This needs to come with a high level of convenience, but as we've explored above shipping native modules can make this experience anything but.

### Packaging with Docker/OCI image format

When I made the first commit to OpenFaaS in November 2016 one of my primary goals was to improve the developer-experience for building and shipping functions. I had been working with containers for packaging software and helping others to adopt this methodology through the Docker Captains' influencer program with Docker Inc.

At first glimpse packaging functions in a Docker image may seem heavy-weight, but it has some characteristics that bring convenience over working with zip files.

* Native modules are easy
* Repeatable and portable build environment
* Efficient layered filesystem
* CI/CD-friendly
* Unlimited package-size*

Native modules can be built easily within a Docker image since the build environment is often the same as the runtime environment. This means that packages can be linked to system libraries and modules without having to setup a separate build environment.

Docker images provide repeatable builds that are portable. You can easily share a Dockerfile with your team through git or your source-control management system.

The layered file-system used to build/share Docker images means that you only have to transfer deltas across the network rather than the whole package. Once the base images are in place on a node, if you only changed 50Kb of Python code, then only that 50Kb of Python code will be saved in a new layer, be uploaded to your registry and downloaded on the target node.

The rise of microservices and the modernization of existing legacy monoliths by Docker Inc has meant that as an industry we have an accepted way of packaging software - the container image. At the time of writing [ThoughtWorks recommend shipping software in Docker images](https://www.thoughtworks.com/radar/techniques) to increase portability and reduce lock-in.

![](/images/template-store/thoughtworks.png)

This is evident in the ease with which we can build Docker images in our existing CI tooling and in the new wave of projects under the banner of GitOps such as [JenkinsX](https://jenkins.io/projects/jenkins-x/), [GitHub Actions](https://github.com/features/actions), [Weave Flux](https://github.com/weaveworks/flux), GitLab Runners and Travis CI.

There are much higher limits for how large your container image can be compared to the zip files accepted by cloud functions providers. [An answer on StackOverflow](https://www.quora.com/What-is-the-maximum-size-of-a-docker-image-you-can-store-on-Docker) believe this to be 10GB, which is around 10x bigger than Google Cloud Functions allows at time of writing. I certainly wouldn't recommend a 10GB Docker image for your function, but it does show that this limit becomes more of a judgement call than a hard-limit.

## OpenFaaS templates

Every OpenFaaS template is based upon a common format which can be applied to produce a Docker image that runs as a serverless function.

* Dockerfile - here we specify the base image for the language such as Node.js. This image may be sourced from the Docker Hub, from a third party such as RedHat. Some companies such as ADP provide employees with a "golden" image derrived from an enterprise Linux subscription.
* Entrypoint - the entrypoint is either a binary that works over STDIO or a process which exposes a HTTP server on the loopback interface. Pick STDIO for ultimate portability - i.e. making the AWS CLI into a function and the HTTP server option for top-end throughput, i.e. Node.js or Java.
* Handler - the handler is the only user-visible component which defines the way to process or handle a request.
* Package list - with each template we use the language-specific, idiomatic way to specify dependencies. So with C# that means listing NuGet packages in a `.csproj`. When we use Node.js that means updating a `package.json` file with a list of `npm` modules. 

There is only one CLI command needed to a user's handler and package list into a Docker/OCI image.

* `faas-cli build`

If you have multiple functions then you can also build them in parallel with the `--parallel` flag.

### How it works

If you run `faas-cli up` then your code will be built, pushed to a Docker registry and then deployed via the OpenFaaS RESTful API.

![](/images/template-store/how-it-works.png)

*Conceptual diagram showing the `faas` or `faas-cli` packaging a function*

### Building the template store

The template store was introduced to make it easy to build, share and make use of templates written for your favourite programming languages.

Around 12 months ago today we announced the [OpenFaaS Function Store](https://blog.alexellis.io/announcing-function-store/) which was built to enable sharing and re-use of functions between our users and community. The template store builds on that success and uses a similar set of new CLI commands.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">In 42 seconds <a href="https://twitter.com/alexellisuk?ref_src=twsrc%5Etfw">@alexellisuk</a> demos the most powerful feature of FaaS. The function store. This is what the future and the now looks like. An open source ecosystem of functions. <a href="https://t.co/ix3ER4b7Jn">pic.twitter.com/ix3ER4b7Jn</a></p>&mdash; Kenny Bastani (@kennybastani) <a href="https://twitter.com/kennybastani/status/1064881269153116167?ref_src=twsrc%5Etfw">November 20, 2018</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script> 

The OpenFaaS core contributors provide support for the *official* templates in the [openfaas/templates](https://github.com/openfaas/templates/) GitHub repo, but there are a growing number of third-party, experimental or opinionated templates which we wanted to make available without breaking the existing experience.

Examples of the community's favourite templates include: [Node.js 10 with Express.js](https://github.com/openfaas-incubator/node10-express-template), [Python 2.7 & 3 with Flask](https://github.com/openfaas-incubator/python-flask-template) and until recently the unofficial PHP template. We've now merged the PHP template into the [official set](https://github.com/openfaas/templates/).

### Get your template into the store

The function store and the template store both have a similar model where a JSON served from the GitHub CDN provide an index of the items available to you. 

> You can view the manifest file here: [templates.json](https://github.com/openfaas/store/blob/master/templates.json)

To get your template into the store follow this process:

#### 1. Propose the template through a new issue

We'll review the repo, Dockerfile and how the template is structured to make sure it is suitable for and workable in the store. You may get some feedback from the community before being given the go-ahead

#### 2. Wait for the go-ahead

Once you've got the go-ahead you can send a PR to the [templates.json](https://github.com/openfaas/store/blob/master/templates.json) file

#### 3. Share and enjoy

Once merged you will be able to use the `faas-cli template store` commands to download your new template and start using it in your projects right away.

If you want to maintain your own template store for personal use or for your team then you can just pass the `--url` variable to your own file or set the `OPENFAAS_TEMPLATE_STORE_URL` environmental variable if you want to make this more permanent.

### Template store demo

You can read more about the OpenFaaS templates over on [the documentation site](https://docs.openfaas.com/)

Here is an interactive demo from [Martin Dekov](https://github.com/martindekov) who built-out the feature with feedback and input from the community.

<script id="asciicast-213889" src="https://asciinema.org/a/213889.js" async></script>

The new `list` and `pull` commands can be accessed via `faas-cli template store`.

For instance you could create a new serverless function using Rust by first typing:

```bash
$ faas-cli template store list

NAME                    SOURCE             DESCRIPTION
rust                    booyaa             Rust template
```

If you're curious or want to check things out you can use the `--verbose/-v` flag to see more information.

Then the following (replacing `alexellis` with your Docker Hub username):

```bash
$ faas-cli template store pull rust
$ faas-cli new --lang rust hello-rust --prefix=alexellis
$ faas-cli up -f hello-rust.yml
```

### What if I have an existing microservice or legacy code?

There may be some circumstances where you have an existing microservice or project which isn't suitable for a function template. An example might be a pre-existing ASP.NET Core application or a Sinatra app written in Ruby. There are two things you may find useful in this scenario. The first is to use the `dockerfile` template which creates a new folder with a Dockerfile allowing you to add whatever you need, or the [stateless microservice approach which you can read about here](https://www.openfaas.com/blog/stateless-microservices/).

## Wrapping up

We looked at some of the drawbacks and technical challenges faced by developers leveraging the zip-file approach to packaging functions. We then explored how the Docker/OCI image format can address some of those issues and finished by showing the template store in action along with covering how you can get your own templates accepted into the store for your favourite languages.

To get started today update your CLI with `brew` or `curl` utility script over at [https://github.com/openfaas/faas-cli](https://github.com/openfaas/faas-cli).

For questions, comments and suggestions follow us on [Twitter @openfaas](https://twitter.com/openfaas) and join the [Slack community](https://docs.openfaas.com/community).
