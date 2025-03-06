---
title: "Learn how to access the Kubernetes API from a Function"
description: "We'll show you how to access any part of the Kubernetes API or a Custom Resource using a ServiceAccount and granular permissions."
date: 2022-10-14
image: /images/2022-access-k8s-from-functions/background.png
categories:
- golang
- kubernetes
- functions
- operator
- integration
author_staff_member: han
author_staff_member_editor: alex
---

We'll show you how to access any part of the Kubernetes API or a Custom Resource using a ServiceAccount and granular permissions

You'll learn how you're already using the Kubernetes API, what an Operator is, and why a Function may be a better fit some of the time. We've also included a code-example so you can get going with that today.

**Introduction by Alex**

If you're using Kubernetes on a regular basis, then you're probably already familiar with its API: from Pods to Deployments to Ingress to Secrets, these are all API objects. Most of the time, we don't think about RESTful operations like GET/POST/DELETE, but we write declarative YAML files like this:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx
spec:
  containers:
  - name: nginx
    image: nginx:1.14.2
    ports:
    - containerPort: 80
```

But under the hood, these objects are brought into Kubernetes not by magic, or a Go binary, but by a REST API just like the ones you may be developing as part of a business application.

Now, working with the Kubernetes API directly can be tedious and complex, especially when it comes to implementing its authentication, so the community built a library in Go called [client-go](https://github.com/kubernetes/client-go). It's simply called "Go client for Kubernetes." on GitHub, which is underselling it somewhat!

With client-go, you can do all the same things you've seen in a Helm chart, or in a YAML file.

Here's a code snippet from a utility I wrote a few weeks ago to make it easier to run a job on Kubernetes and to collect its results:

```golang
	jobID := uuid.New().String()

	parallelism := int32(1)
	ctx := context.Background()
	jobSpec := &batchv1.Job{
		ObjectMeta: metav1.ObjectMeta{
			Name:      name,
			Namespace: namespace,
			Labels: map[string]string{
				"app":    "run-job",
				"job-id": jobID,
			},
		},
		Spec: batchv1.JobSpec{
			Parallelism:  &parallelism,
			BackoffLimit: &parallelism,
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":    "run-job",
						"job-id": jobID,
					},
					Name:      name,
					Namespace: namespace,
				},
				Spec: corev1.PodSpec{
					RestartPolicy:      corev1.RestartPolicyNever,
					ServiceAccountName: sa,
					Containers: []corev1.Container{
						{
							Image:           image,
							Name:            name,
							ImagePullPolicy: corev1.PullAlways,
							Command:         command,
							Args:            args,
						},
					},
				},
			},
		},
	}
```

See the full source-code on GitHub: [alexellis/run-job](https://github.com/alexellis/run-job/blob/master/main.go)

So if you squint, you can see that we really have written something very similar to what we're used to with YAML files, but with code, which means we can write control-loops, iterate over collections of objects, and build custom behaviour.

And when you do all that, you're looking at what the CoreOS team (RIP) calls an "Operator".

According to [operatorhub.io](https://operatorhub.io):

> "Operators are a design pattern made public in a 2016 CoreOS blog post. The goal of an Operator is to put operational knowledge into software. Previously this knowledge only resided in the minds of administrators, various combinations of shell scripts or automation software like Ansible. It was outside of your Kubernetes cluster and hard to integrate. With Operators, CoreOS changed that."

OpenFaaS itself is an operator, and you can view its source code here:

[https://github.com/openfaas/faas-netes](https://github.com/openfaas/faas-netes)

One of our sister projects called inlets has an operator that doesn't just control in-cluster, Kubernetes APIs, but can provision cloud VMs to give you quick access to local services from the Internet:

[https://github.com/inlets/inlets-operator](https://github.com/inlets/inlets-operator)

So if Operators are so great, why would you need a function?

Operators are complex beasts requiring frameworks like kube-builder and lots of packaging, Dockerfiles, and ongoing maintenance.

We love them here, but perhaps there's an option you can reach for, which will solve the problem without all the overheads?

If you already get the value of functions, then you won't need any convincing.

But here are a few ideas:

* ChatOps - you are running a multi-tenant cluster, someone opens a ticket in ServiceNow and needs a new namespace. You open Slack and type in `/create-namespace teama` and team a gets their namespace, because that chat bot was really and OpenFaaS Function just like the one we're going to see today
* Debugging - Han's example will show you one of the most underappreciated features of Kubernetes, events. Events are where you go when you've already checked Pods logs and don't know what's going wrong. Why not access them from a function?
* Garbage collection & maintenance - if you've got a bug in a controller and it's leaving orphaned objects in the cluster, a function could run on a cron schedule to clean these up. It may even be that you delete any objects in staging that are more than 30 days old, but don't have the time to maintain an operator
* Integration - OpenFaaS has various event connectors for AWS SQS, AWS SNS, NATS, webhooks and Apache Kafka, rather than adding this code into your operators, you could write a function and have it get triggered by an event

I'll turn it over to Han, who's going to show you how to create a function using the Go template in OpenFaaS, to get the events from a namespace and return them from a function.

## Write a function to find the events in a namespace

Pods can be given a Service Account with its own set of Roles and permissions so it can access the Kubernetes API.

Here is a ServiceAccount and ClusterRole that can be used to list events for different namespaces. You could also restrict this to a Role and RoleBinding, if you only needed to access one namespace.

```yaml
# SA
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fn-events
  namespace: openfaas-fn
---

# ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    app: openfaas
  name: fn-events
rules:
- apiGroups: [""]
  resources: ["events"]
  verbs:
  - list

# ClusterRoleBinding
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    app: openfaas
  name: fn-events
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fn-events
subjects:
  - kind: ServiceAccount
    name: fn-events
    namespace: openfaas-fn
---
```

Functions can only assume a ServiceAccount in the namespace in which they are deployed. The `fn-events` ServiceAccount is created in the `openfaas-fn` namespace. This is the default namespace used for OpenFaaS functions.

> Learn more about [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) and [Service Accounts](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/) in the Kubernetes documentation.

Now let's create a new function named `get-events` using the [golang-middleware template](https://github.com/openfaas/golang-http-template)

```bash
export OPENFAAS_URL="docker.io/username"

faas-cli template store pull golang-middleware
faas-cli new get-events --lang golang-middleware
```

You can assign a ServiceAccount to a function by adding the annotation `com.openfaas.serviceaccount` in the functions `stack.yaml` file. 

```yaml
functions:
  get-events:
    lang: golang-middleware
    handler: ./get-events
    image: welteki2/get-events:0.1.1
    annotations:
      com.openfaas.serviceaccount: fn-events
```

> If you want to learn how to build functions with Go, check out [Alex's book (Premium Edition)](http://store.openfaas.com/l/everyday-golang?layout=profile) for lots of examples.

We will be using the Kubernetes client package for Go to access data and resources in the cluster. The function first creates a new clientset with an in-cluster configuration. The clientset is then used to list the events for a specific namespace.

The namespace can be passed in as the request body. If no namespace is passed in we list the events for the `openfaas-fn` namespace.

Add the required dependencies for the function:

```bash
cd get-events

go get "k8s.io/apimachinery/pkg/apis/meta/v1"
go get "k8s.io/client-go/kubernetes" 
```

Edit the function handler `./get-events/handler.go`:

```golang
package function

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"text/tabwriter"
	"time"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

var clientset *kubernetes.Clientset

func Handle(w http.ResponseWriter, r *http.Request) {
	if clientset == nil {
		cs, err := getClientset()
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(fmt.Sprintf("failed to get clientset: %s", err)))
			return
		}

		clientset = cs
	}

	var namespace string
	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		namespace = string(body)
	}

	if len(namespace) == 0 {
		namespace = "openfaas-fn"
	}

	ctx := context.Background()
	events, err := clientset.CoreV1().Events(namespace).List(ctx, metav1.ListOptions{})

	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte(fmt.Sprintf("failed to list events: %s", err)))
		return
	}

	var b bytes.Buffer
	tabw := tabwriter.NewWriter(&b, 0, 3, 1, ' ', 0)
	fmt.Fprintf(tabw, "LAST SEEN\tTYPE\tREASON\tOBJECT\tMESSAGE\n")

	for _, e := range events.Items {
		object := fmt.Sprintf("%s/%s", e.InvolvedObject.Kind, e.InvolvedObject.Name)
		lastSeen := e.LastTimestamp.Format(time.RFC822)
		fmt.Fprintf(tabw, "%s\t%s\t%s\t%s\t%s\n", lastSeen, e.Type, e.Reason, object, e.Message)
	}

	tabw.Flush()

	w.WriteHeader(http.StatusOK)
	w.Write(b.Bytes())
}

func getClientset() (*kubernetes.Clientset, error) {
	config, err := rest.InClusterConfig()
	if err != nil {
		return nil, fmt.Errorf("error building kubeconfig: %s", err)
	}

	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		return nil, err
	}

	return clientset, nil
}
```

Deploy the function with `faas-cli up -f get-events.yml`

Then invoke it with `curl`. This should return a formatted list of events for a namespace.

```bash
curl -i http://127.0.0.1:8080/function/get-events

HTTP/1.1 200 OK
Content-Length: 798
Content-Type: text/plain; charset=utf-8
Date: Thu, 13 Oct 2022 13:41:09 GMT
X-Call-Id: b1af2c1b-bd06-4b9c-969a-a7d8e065a2e8
X-Duration-Seconds: 0.005199
X-Start-Time: 1665668469270352257

LAST SEEN           TYPE   REASON OBJECT                      MESSAGE
13 Oct 22 13:40 UTC Normal Synced Function/bcrypt             Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/cows               Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/delay-sleep        Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/health             Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/list-of-namespaces Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/sleep              Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/ready              Function synced successfully
13 Oct 22 13:40 UTC Normal Synced Function/get-events         Function synced successfully
```

## Trigger workloads on a schedule

Depending on the workload you are running in your function you might want to trigger it on a timed-basis. OpenFaaS has support for this through the [cron event-connector](https://docs.openfaas.com/reference/cron/#kubernetes).

You can deploy the cron-connector with [arkade](https://github.com/alexellis/arkade).

```bash
arkade install cron-connector
```

Two annotation are required to trigger the function, a `topic` of `cron-function` and a `schedule` using a valid Cron expression.

Add these annotations to the `stack.yaml`:

```yaml
functions:
  get-events:
    lang: golang-middleware
    handler: ./get-events
    image: welteki2/get-events:0.1.1
    annotations:
      com.openfaas.serviceaccount: fn-events
      topic: cron-function
      schedule: "* */1 * * *"
```

This will trigger the function every hour.

# Wrapping up

It is possible to access the Kubernetes API form within your functions. We walked through a short example where we create a function to list events for different namespaces. What you choose to do with your cluster from your functions code is entirely up to you. You could create a function to:

- Do any kind of reconciliation like cleaning up orphaned objects or applying a certain label to workloads
- Build a self-service integration with Slack, where a chatbot can provision namespaces for teams
- Run diagnostics against your cluster. We did something like this with the [OpenFaaS config-checker](https://github.com/openfaas/config-checker)

Take a look at what you are using the Kubernetes API for. Maybe you could benefit from running some of that code as a function.

**What about authentication?**

Once you've [given your function a Service Account](https://docs.openfaas.com/reference/workloads/#custom-service-account), if it's read-only and the OpenFaaS gateway is behind a firewall, the chances for abuse are low.

But if your Service Account can write to resources in the cluster, then you need to enable some form of authentication on the function. [An API token might be a good starting point](https://docs.openfaas.com/reference/authentication/), especially if this is going to be called from another server or microservice in your system.

We are interested to hear what workloads you would run using this approach. Let us know by tweeting to [@openfaas](https://twitter.com/openfaas).

You may also like:

- [A Deep Dive into Golang for OpenFaaS Functions](https://www.openfaas.com/blog/golang-deep-dive/)
- [Gracefully handling Kubernetes API deprecations: The Tale of Two Ingresses.](https://www.openfaas.com/blog/ingress-api-deprecation/)
