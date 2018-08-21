---
title: 5 tips and tricks for the OpenFaaS CLI
description: Alex shares his top 5 tips and tricks for boosting productivity with the OpenFaaS CLI. This post will feature some classic features and brand-new additions too.

date: 2018-08-21
image: /images/five-cli-tips/background.jpg
categories:
  - cli
  - kubernetes
  - swarm
author_staff_member: alex
---

In this post I'll will share 5 top tips for boosting productivity with the [OpenFaaS CLI](https://github.com/openfaas/faas-cli). The CLI used by developers to interact with OpenFaaS from the terminal is the most popular part of the project for new contributors to cut their teeth on. Since 2017 the contributors been incrementally fine-tuning the developer-experience through user-feedback, new features and productivity-boosters.

Part of this work has also involved expanding the set of language templates that are pre-packaged with OpenFaaS to include languages such as [Java](https://blog.alexellis.io/java-comes-to-openfaas/). A recent [developer-survey by DigitalOcean](https://www.digitalocean.com/currents/june-2018/) showed a high-level of overlap between the languages being used in containers in the responses and the list provided by the project.

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">From <a href="https://twitter.com/digitalocean?ref_src=twsrc%5Etfw">@digitalocean</a> report &quot;For those using containers, what languages are you most frequently using?&quot; vs. &quot;faas-cli new --list&quot; in OpenFaaS - what else would you like to see as a template? <a href="https://t.co/1S49KYMj42">pic.twitter.com/1S49KYMj42</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1014412959798431744?ref_src=twsrc%5Etfw">July 4, 2018</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

> Note: any binary or container can be made into a function with OpenFaaS meaning you can run any code, anywhere you like at any scale.

Before we get started, make sure you have the OpenFaaS CLI installed [via the docs](https://docs.openfaas.com/cli/install/).

## Tip 1 &amp; 2: use `--filter` and `--parallel`

The OpenFaaS YAML definition allows developers to group together all their functions in one place. When you get half a dozen functions and are only changing one you can use the `--filter` flag to speed things up.

Here's an example:

Create four functions appending them all to the same YAML file:

```
faas-cli new --lang node --name filter1
faas-cli new --lang node --name filter2 --append filter1.yml
faas-cli new --lang node --name filter3 --append filter1.yml
faas-cli new --lang node --name filter4 --append filter1.yml
```

Now if you were to run a `build`, `push` or `deploy` you'd carry that step out for all four functions. Fortunately Docker's caching would speed this up, but we knew we could make this experience better, that's when we introduced the `--filter` option to all three verbs.

You can simply type in `faas-cli build --filter=filter2` for instance.

Now if you do happen to edit most of your functions most of the time such as with [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud/blob/master/stack.yml), then you can use the `--parallel` flag and your images will be built concurrently. If you have 16 functions in one YAML file and use `--parallel=4` they will build in batches of 4 saving time overall. This speed-boosting feature isn't available when working with Docker outside of OpenFaaS.

You can also split your functions into separate folders, repos or YAML files.

For a full YAML reference for the "stack file" see the docs: [YAML format reference](https://docs.openfaas.com/reference/yaml/)

## Tip 3: use `OPENFAAS_URL` for your gateway address

All commands that reach out to the OpenFaaS gateway can take a flag for a remote or local address.

You can log into your remote gateway using `faas-cli login` for example.

Default to `127.0.0.1:8080`:

```
faas-cli login
```

Override with a flag or a short-flag:

```
faas-cli login --gateway http://127.0.0.1:31112
faas-cli login -g http://127.0.0.1:31112
```

Use an environmental variable:

```
export OPENFAAS_URL=https://gw.my-openfaas.com
faas-cli login
```

Some other verbs or commands that can take a `gateway` URL are: `list`, `store deploy`, `version`, `logout`, `invoke` and more. For a full list type in `faas-cli help` 

## Tip 4: Use static and build dynamic tags for versioning

There are several ways you can version your functions and the simplest way is to change the tag of the Docker image between commits.

```
functions:
  test:
    lang: go
    handler: ./test
    image: alexellis2/test:latest
```

To statically change the version you can alter the word `test:latest` to `test:0.1` and so-forth. This will result in a number of different Docker images being pushed and maintained in your registry allowing you to go back to a known version easily using a rolling-update and without down-time.

You can also generate a dynamic tag based upon `git` meta-data in the repository such as SHA ID and branch.

```
mkdir -p tester
cd tester

git init
faas-cli new --lang go test1 --prefix=alexellis2
git add .
git commit -s -m "Initial commit"

faas-cli build --yaml test1.yml --tag=sha
```

In this example the short-format Git SHA ID was appended to the tag in the YAML file:

```
Successfully tagged alexellis2/test1:latest-b6d5661
```

If we change the tag in the YAML file from `latest` to `0.1` then the image tag would have been: `test1:0.1-b6d5661`. This is useful for CI/CD jobs and is supported by the verbs: `build`, `push`, `deploy` and `up`.

You can also omit the `--yaml/-f` flag if you rename your YAML file to `stack.yml`

## Tip 5: Use `faas-cli up` and save on typing

From early on contributors and users requested an alias or new CLI command to prevent having to type in something like the following after each change:

```
faas-cli build && \
  faas-cli push && \
  faas-cli deploy
```

It might not look bad, but if you decide to add some flags it could become repetitive:


```
faas-cli build --filter=filter1 && \
  faas-cli push --filter=filter1 && \
  faas-cli deploy --filter=filter1 --gateway https://alt-gw.my-openfaas.com
```

Spurred by great developer experiences found in Docker Compose and other similar tooling I raised an issue and looked for a contributor to help build the new feature. After a couple of weeks John Mccabe volunteered to take a look. His work was merged in the 0.7.0 version of the CLI.

The above examples become:

```
faas-cli up
```

Or

```
faas-cli up --filter=filter1 --gateway https://alt-gw.my-openfaas.com
```

You can also skip the push step with `--skip-push` if you're working locally.

Here's the feature in action in a handy gif made by John for his PR:

![](https://user-images.githubusercontent.com/83862/44221456-71f81a80-a179-11e8-9153-31a35ee140aa.gif)

## Wrapping up

I hope you've enjoyed my list of top 5 productivity boosts for the CLI. If you want to learn more and get started then the community has produced a set of hands-on labs for you in the [OpenFaaS Workshop](https://github.com/openfaas/workshop). 

<blockquote class="twitter-tweet" data-lang="en"><p lang="en" dir="ltr">From the hands-on workshop today at <a href="https://twitter.com/DevNetCreate?ref_src=twsrc%5Etfw">@DevNetCreate</a> - engineers and students learning how to build functions with Python and <a href="https://twitter.com/Docker?ref_src=twsrc%5Etfw">@Docker</a> <a href="https://t.co/k8Owa5h5iC">https://t.co/k8Owa5h5iC</a> <a href="https://t.co/UtuEwyYXlI">pic.twitter.com/UtuEwyYXlI</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/984270331094315008?ref_src=twsrc%5Etfw">April 12, 2018</a></blockquote>
<script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

Do you have your own tips? It'd be great to hear them over on [Twitter @openfaas](https://twitter.com/openfaas) or in the [Slack community](https://docs.openfaas.com/community).

Curious about who is using OpenFaaS in production? Check out the list of companies that have let us know so far over at [https://docs.openfaas.com/](https://docs.openfaas.com/).

