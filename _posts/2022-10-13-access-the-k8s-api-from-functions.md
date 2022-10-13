---
title: "How to access the Kubernetes API from a function"
description: "We'll show you how to access any part of the Kubernetes API from a function securely, with a granular ServiceAccount."
date: 2022-10-13
image: /images/2022-access-k8s-from-functions/background.png
categories:
- golang
- kubernetes
- functions
author_staff_member: han
---

We'll show you how to access any part of the Kubernetes API from a function securely, with a granular ServiceAccount.

If you are running OpenFaaS on kubernetes, OpenFaaS Pro functions can assume a ServiceAccount to run a workloads that require accessing the Kubernetes API.

For some use-cases using functions might be a better solution compared to the effort required to write and maintain an operator.

In this post we will walk you through a short example where we use a function to get the events for a namespace for debugging purposes.

## Get events for a namespace

Create a new function named `get-events` using the [golang-middleware template](https://github.com/openfaas/golang-http-template)
```
faas-cli template store pull golang-middleware
faas-cli new get-events --lang golang-middleware
```

> You can check out this blog post by Alex for [a deep dive into Golang for OpenFaaS functions](https://www.openfaas.com/blog/golang-deep-dive/)

We are using the kubernetes client package for Go to access data and resources in the cluster. The function first creates a new clientset with an in-cluster configuration. The clientset is then used to list the events for a specific namespace.

The namespace can be passed in as the request body. If no namespace is passed in we list the events for the `openfaas-fn` namespace.

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

Processes in containers can access the Kubernetes apiserver. They are authenticated as a particular Service Account to do so. 
We will have to create some RBAC Roles and a ServiceAccount for our function.

Here is a ServiceAccount and ClusterRole that can be used to list events for different namespaces:

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

Deploy the function and invoke it with `curl`:

```bash
export OPENFAAS_URL="http://127.0.0.1:8080"
curl -i $OPENFAAS_URL/function/get-events

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
```
arkade install cron-connector
```

Two annotation are required to trigger the function, a `topic` of `cron-function` and a `schedule` using a valid Cron expression.

Add these annotations to the `stack.yml`:

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


# Conclusion
It is possible to access the Kubernetes API form within your functions. We walked through a short example where we create a function to list events for different namespaces. What you choose to do with your cluster from your functions code is entirely up to you.

We are interested to hear what workloads you would run using this approach. Let us know by tweeting to [@openfaas](https://twitter.com/openfaas).
