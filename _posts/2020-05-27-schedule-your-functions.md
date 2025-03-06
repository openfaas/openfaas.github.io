---
title: Keep your functions running to schedule with the cron-connector
description: "In this post Martin will show you how to schedule your functions with the cron-connector, for regular tasks and scheduled jobs"
date: 2020-05-27
image: /images/2020-schedule-your-functions/accuracy-alarm-clock-analogue-business.jpg
categories:
  - cron
  - kubernetes
  - serverless
  - linux
  - tutorial
  - example
author_staff_member: martin
dark_background: true

---

In this post Martin will show you how schedule your functions with the cron-connector, for regular tasks and scheduled jobs.

One of the things we need very often is our functions to be executed on a schedule. This is where the cron-connector shines. For our example we will create `Lockbot` which will lock conversation on outdated issues. With the `cron-connector` your functions will run on time.

## Motivation

OpenFaaS provides a very convenient and flexible way to quickly write and expose your code to be used by external systems. Often times those systems don't have a hook to which you can schedule function execution. Also very often we need to run those functions without external systems, we just want our code to be ran on an interval.

For those purposes [connector-sdk](https://github.com/openfaas-incubator/connector-sdk) was created. It provides the means to quickly adapt different systems to invoke functions. Some of them are [Kafka](https://github.com/openfaas-incubator/kafka-connector), [NATS](https://github.com/openfaas-incubator/nats-connector), [MQTT](https://github.com/openfaas-incubator/mqtt-connector) and [many more](https://docs.openfaas.com/reference/triggers/).

Now we need our functions to to be invoked on an interval. [Cron](https://en.wikipedia.org/wiki/Cron) is often used on GNU/Linux systems to execute tasks to a pre-defined schedule. In Kubernetes, this was abstracted into the `CronJob` object. For any OpenFaaS cluster, the [cron-connector](https://github.com/openfaas-incubator/cron-connector) uses the `connector-sdk` to provide the same functionality, running our functions on a predefined schedule.

Now lets roll up our sleeves and see how we can execute our OpenFaaS functions on time.

## Prerequisites

Before we start we need a couple of tools to help us quickly set up our environment:

* [docker](https://docs.docker.com/get-docker/) - the container runtime used in this post
* [kubernetes](https://kind.sigs.k8s.io/docs/user/quick-start/) - cluster which will manage our containers
* [arkade](https://github.com/alexellis/arkade) - one line installation of applications with which we will install OpenFaaS
* [faas-cli](https://docs.openfaas.com/cli/install/) - the CLI which communicates with the OpenFaaS gateway
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) - the CLI which communicates with your Kubernetes cluster

## Prepare environment

Before showing you how to run our functions on a schedule, first we need to set up the environment with the tools mentioned above.

### Create cluster

First thing we need is running Kubernetes cluster:

```bash
kind create cluster
```

Wait for the installation to finish and verify the pods in the `kube-system` namespace are `1/1`:

```bash
kubectl get pods -n kube-system
```

### Install OpenFaaS

With `arkade` the installation of OpenFaaS boils down to single line command:

```bash
arkade install openfaas
```

Wait for the OpenFaaS gateway to be ready:

```bash
kubectl rollout status -n openfaas deploy/gateway
```

Follow the instructions provided by `arkade` after the installation to set up the `faas-cli`. Also we will use Dockerhub to store the images so before we continue set `OPENFAAS_PREFIX`:

```bash
export OPENFAAS_PREFIX="<dockerhub_username>"
```

## Schedule the functions

After we have the environment up and running, now we can install the cron-connector and schedule our functions to run at specific intervals.

### Deploy the cron-connector

In order to install our `cron-connector` and schedule a function run the following command:

```bash
arkade install cron-connector
```

Wait for the `cron-connector` to be deployed:

```bash
kubectl rollout status -n openfaas deploy/cron-connector
```

The cron connector has a [helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/cron-connector) which you can explore.

## How to schedule

The schedule of the function is configured through the `schedule` annotation following the normal cron syntax `* * * * *`. See [this](https://www.cyberciti.biz/faq/how-do-i-add-jobs-to-cron-under-linux-or-unix-oses/) blog post for some examples of the cron format.

Couple of quick cron schedule examples are:

* `*/5 * * * *` - will run once every five minutes
* `0 0 */1 * *` - will run once every day of the month at 00:00
* `0 0 * * */7` - will run once a week on the seventh day at 00:00

The cron-connector recognizes which functions should be ran on a schedule by annotation `topic` with value `cron-function`, we can add this annotation to the function's configurtion or during deployment

Now lets go head and create a function which will run on a schedule.

## Meet Lockbot

The `Lockbot` will run once per day at `00:00` and will check for old GitHub issues. The issue will be locked in case it is older than the days we will chose. For our example we can go with 3 months, which is roughly 90 days.

### Get the function template from store

The OpenFaaS framework has rich variety of language templates which you can use to write your own functions. In our example we will use Python 3 with the Debian based template `python3-flask-debian`:

```bash
faas-cli template store pull python3-flask-debian
```

### Generate the function

In order to generate the function's backbone we will run the following command:

```bash
faas-cli new lockbot --lang python3-flask-debian
```

### Generate access token

Go to the [personal access tokens](https://github.com/settings/tokens) page in GitHub and press the `Generate new token` button. The bot will use this to authenticate to the repository you chose.

Now copy the generated token and create `auth-token` secret using the `faas-cli` where you need to replace the `<token>` with the actual copied access token:

```bash
faas-cli secret create auth-token --from-literal='<token>'
```

### Configure the function

Open the function's configuration file called `stack.yaml`. Append the following lines to the file:

```yml
    environment:
      github_repository: <repository>
      inactive_days: 90
      exec_timeout: 30s
      read_timeout: 30s
      write_timeout: 30s
    secrets:
      - auth-token
    annotations:
      topic: cron-function
      schedule: "0 0 */1 * *"
```

> The schedule used `0 0 */1 * *` means once every day of the month at 00:00

We have increased the default timeout of the function to `30s`. Replace `<repository>` with one of your own repositories. The whole `stack.yaml` file should look something like this:

```yml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:31112
functions:
  lockbot:
    lang: python3-flask-debian
    handler: ./lockbot
    image: martindekov/lockbot:latest
    environment:
      github_repository: push2
      inactive_days: 90
      exec_timeout: 30s
      read_timeout: 30s
      write_timeout: 30s
    secrets:
      - auth-token
    annotations:
      topic: cron-function
      schedule: "0 0 */1 * *"
```

> The `image` and `repository` should be different

### Augment the code

Inside the `lockbot` folder you can see the `handler.py` file which contains the `handle` method which is the entry point to your function. Replace what's inside with the lockbot's code:

```python
import os
from datetime import datetime
from github import Github


def get_issues():
    desired_repo = os.getenv("github_repository")
    desired_days = int(os.getenv("inactive_days"))
    auth = None
    with open("/var/openfaas/secrets/auth-token") as file:
        auth = Github(file.read().strip())

    issues_for_lock = []
    for repo in auth.get_user().get_repos():
        if repo.name == desired_repo:
            for issue in repo.get_issues():
                if not issue.pull_request and not issue.locked:
                    last_comment = issue.get_comments()[
                        issue.comments-1].updated_at
                    difference = datetime.now() - datetime(last_comment.year,
                                                           last_comment.month,
                                                           last_comment.day)
                    if difference.days > desired_days:
                        issues_for_lock.append(issue)

    return issues_for_lock


def lock(issues):
    response = "no unlocked inactive issues"
    if len(issues) > 0:
        response = "issues locked:"
        for issue in issues:
            issue.lock("off-topic")
            response = response + f"\n{issue.title}"
    return response


def handle(req):
    issues = get_issues()
    response = lock(issues)
    return response
```

Finally add the Github SDK to the `requirements.txt` which is in the same folder as `handler.py`:

```text
PyGithub
```

The function will fetch the issues from the repository you chose in the configuration section then it will filter them and calculate, using the date when they were opened, whether they are older than the 90 days we chose. If this is the case the lockbot will authenticate itself against the GitHub API with the access token we generated and will lock the issue from further conversation, marking it as `off-topic`. The lockbot will respond with the locked issues or the lack of such.

### Deploy the function

Deploy lockbot so that it can start locking inactive issues on your GitHub repositories:

```bash
faas up -f lockbot.yml
```

A full working example of the function can be see in the [lockbot](https://github.com/martindekov/lockbot) repository.

>Note: To see the function in action you can directly invoke it using the UI or the CLI.

## Wrapping up

In this post we have shown how you can run minimal OpenFaaS environment with simple function and how with the help of the cron-connector you can execute the function on a desired schedule.

Learn how to create your own functions with the [OpenFaaS workshop](https://github.com/openfaas/workshop) and all the ways you can [trigger them](https://docs.openfaas.com/reference/triggers/). We used one of the templates from the store in our example, but you'll find many others, just run `faas-cli template store list` or view the [Template Documentation](https://docs.openfaas.com/cli/templates/) and make sure your functions always run on time!
