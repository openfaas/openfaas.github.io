---
title: "Introducing a New OpenFaaS Golang Template with OpenTelemetry Support"
description: "Explore the new OpenFaaS Golang template with built-in OpenTelemetry for better observability."
date: 2025-06-04
author_staff_member: han
categories:
  - golang
  - opentelemetry
  - template
dark_background: true
image: ""
hide_header_image: true
---

We have created a new OpenFaaS template for Golang with OpenTelemetry support.

In our previous blog post on OpenTelemetry, [How to Trace functions with OpenTelemetry](https://www.openfaas.com/blog/trace-functions-with-opentelemetry/), we showed how [auto-instrumentation](https://opentelemetry.io/docs/zero-code/) can be used to quickly instrument Python and Node.js functions. In this post, you’ll learn how to add tracing to your Golang functions in OpenFaaS using a new template we’ve created with baked-in OpenTelemetry support. We’ll walk through some examples, including querying a PostgreSQL database and adding custom tracing data.

![Grafana visualisation for the default HTTP trace from a function using the golang-otel template.](/images/2025-05-opentelemetry-golang/http-trace.png)
> Grafana visualisation for the default HTTP trace from a function using the golang-otel template. 

[OpenTelemetry](https://opentelemetry.io/) is an open-source observability framework that provides a standardized way to instrument, generate, collect, and export telemetry data like traces from your applications. Traces specifically represent the end-to-end journey of a single request as it flows through various services and components within a distributed system, enabling you to visualize its path and identify performance bottlenecks or errors.

Without this template, configuring an exporter manually and adding traces to existing Golang functions requires quite some boilerplate code. While there is support for auto-instrumentation for Go, the [OpenTelemetry Go Auto-instrumentation project](https://github.com/open-telemetry/opentelemetry-go-instrumentation) is still in beta. Moreover, it requires a privileged container which we strongly discourage if possible. 

To eliminate the need for users to clone the official Golang templates and add instrumentation themselves, we have created an official template with OpenTelemetry instrumentation support baked-in.

The template is named `golang-otel` and allows users to get traces for Golang functions with minimal code changes. Some of the key benefits of the `golang-otel` template are:

- **No boilerplate** - Avoid boilerplate code to configure providers and traces in Go functions. No need to fork and maintain your own version of the golang templates.
- **Configuration using environment variables** - Simplify configuration with environment-based settings, reducing the need for code changes.
- **HTTP instrumentation** - Incoming HTTP requests to the function handler are automatically instrumented.
- **Extensibility with custom traces** - Easily add custom spans using the [OpenTelemetry Go Trace API](https://pkg.go.dev/go.opentelemetry.io/otel) without much boilerplate code.

In the next section we will walk through a couple of examples that shows you how to create instrumented Golang functions with the new template.

## Prerequisites

We won't go into detail on how to deploy OpenFaaS and assume you already have a working OpenFaaS deployment either on Kubernetes or on a single host with [OpenFaaS Edge](https://docs.openfaas.com/deployment/edge/#openfaas-edge).

We will also assume that your OpenFaaS deployment is configured to collect, export and persist telemetry data from functions. In the post [How to Trace functions with OpenTelemetry](https://www.openfaas.com/blog/trace-functions-with-opentelemetry/) we show how to prepare a cluster for collecting telemetry data from functions.

You can follow the instructions in the post to get started with collecting and storing traces in your cluster using open-source tools like [Grafana Alloy](https://grafana.com/docs/alloy/latest/) and [Grafana Tempo](https://grafana.com/oss/tempo/). Alternatively you can use a cloud based platform like [Grafana Cloud](https://grafana.com/docs/grafana-cloud/send-data/otlp/send-data-otlp/) or [Datadog](https://docs.datadoghq.com/opentelemetry/) for storing and inspecting traces.


## Collect traces from a Golang function

The new `golang-otel` template is based on the [golang-middleware](https://github.com/openfaas/golang-http-template?tab=readme-ov-file#10-golang-middleware-recommended-template) template and can be used as a drop-in replacement to get HTTP invocation traces for your existing Golang functions without any code changes. All that is required is to change the `lang` field in the `stack.yaml` configuration.

```diff
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  echo:
-   lang: golang-middleware
+   lang: golang-otel
    handler: ./echo
    image: echo:latest
```

When creating a new function use the [OpenFaaS CLI](https://github.com/openfaas/faas-cli) to scaffold a new function with the `golang-otel` template:

```sh
faas-cli new echo --lang golang-otel
```

Environment variables can be used to configure the OpenTelemetry traces exporter for functions:

```diff
functions:
  echo:
    lang: golang-otel
    handler: ./echo
    image: echo:latest
+    environment:
+      OTEL_TRACES_EXPORTER: console,otlp
+      OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-collector:4317}
```

The `golang-otel` template supports a subset of [OTEL SDK environment variables](https://opentelemetry.io/docs/languages/sdk-configuration/) to configure the exporter.

In this example we also use [environment variable substitution](https://docs.openfaas.com/reference/yaml/#yaml-environment-variable-substitution) in the stack file to make parameters easily configurable when deploying the function.

- `OTEL_TRACES_EXPORTER` specifies which tracer exporter to use. In this example traces are exported to `console` (stdout) and with `otlp` to send traces to an endpoint that accepts OTLP via gRPC. 
- `OTEL_EXPORTER_OTLP_ENDPOINT` sets the endpoint where telemetry is exported to.
- `OTEL_SERVICE_NAME` sets the name of the service associated with the telemetry and is used to identify telemetry for a specific function. By default `<fn-name>.<fn-namespace>` is used as the service name on Kubernetes or `<fn-name>` when running the function with OpenFaaS Edge, or locally with `faas-cli local-run`.
- `OTEL_EXPORTER_OTLP_TRACES_INSECURE` can be set to true to disable TLS if that is not supported by the OpenTelemetry collector.

You can deploy the function locally using `faas-cli local-run` to quickly verify instrumentation is working. Since the `console` exporter is set, telemetry data is being written to stdout/console.

```sh
faas-cli local-run echo
```
Invoke the function to verify traces get exported to the console:

```sh
curl -i http://127.0.0.1:8080 -d "Hello OpenFaaS!"
```

## Use instrumentation libraries

The `golang-otel` template initializes OpenTelemetry and configures traces exporters for you. The function handler is instrumented by default. If you are using third-party libraries and frameworks you might want to avoid spending additional time to manually add traces to these libraries. You can use [instrumentation libraries](https://opentelemetry.io/docs/specs/otel/glossary/#instrumentation-library) to generate telemetry data for a library or framework.

For example, the [instrumentation library for net/http](https://pkg.go.dev/go.opentelemetry.io/contrib/instrumentation/net/http/otelhttp) is used in the template to automatically create [spans](https://opentelemetry.io/docs/concepts/signals/traces/#spans) based on the HTTP requests.

In this section we will walk through an example showing how to create and instrument a function that queries a PostgreSQL database.

### Prepare the database

We assume you are already running a Postgres database somewhere. You can use one of the many DBaaS services available, run a postgres with docker or use [arkade](https://github.com/alexellis/arkade) to quickly deploy a database in your cluster. If you are running OpenFaaS Edge, the official guide [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) has a chapter that shows how to deploy PostgreSQL as an additional service.

You could use a managed PostgreSQL service from AWS, GCP, DigitalOcean, etc, or deploy a development version of PostgreSQL into your Kubernetes cluster using `arkade install postgresql`. After the installation it will print out all the instructions to get the password and connect to the database.

We will create a table and insert some records that can be queried by our function:

```sql
CREATE TABLE IF NOT EXISTS employee
(
    id INT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL
);

INSERT INTO employee (id,name,email) VALUES
(1,'Alice','alice@example.com'),
(2,'Bob','bob@example.com');
```

### Create a function

Create a new OpenFaaS function using the `golang-otel` template. This template is available in the OpenFaaS template store.

```sh
faas-cli template store pull golang-otel
faas-cli new --lang golang-otel employee-api
```

Add the code that queries the database and returns a list of employees to the function handler. In this example we use the [database/sql](https://pkg.go.dev/database/sql) package from the standard library and the [lib/pq](https://github.com/lib/pq) driver to query the database.

We start with an un-instrumented version of the code and will show you the changes required to add instrumentation.

```go
package function

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

	_ "github.com/lib/pq" // PostgreSQL driver
)

var db *sql.DB

func init() {
	data, err := os.ReadFile("/var/openfaas/secrets/pg-connection")
	if err != nil {
		log.Fatalf("failed to read pg-connection secret: %v", err)
	}
	connStr := string(data)

	db, err = sql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}

	if err := db.Ping(); err != nil {
		log.Fatalf("Error connecting to the database: %v", err)
	}

	log.Println("Successfully connected to the database")
}

// Employee struct to represent a row in the 'employee' table
type Employee struct {
	ID    int
	Name  string
	Email string
}

func Handle(w http.ResponseWriter, r *http.Request) {
	// Query to select all employees
	rows, err := db.Query("SELECT id, name, email FROM employee")
	if err != nil {
		http.Error(w, fmt.Sprintf("Error querying employees: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close() // Close the rows when done

	var employees []Employee

	// Iterate over the result set
	for rows.Next() {
		var employee Employee
		// Scan the columns of the current row into the Employee struct
		if err := rows.Scan(&employee.ID, &employee.Name, &employee.Email); err != nil {
			http.Error(w, fmt.Sprintf("Error scanning employee row: %v", err), http.StatusInternalServerError)
			return
		}
		employees = append(employees, employee)
	}

	// Check for any errors encountered during iteration
	if err = rows.Err(); err != nil {
		http.Error(w, fmt.Sprintf("Error during rows iteration: %v", err), http.StatusInternalServerError)
		return
	}

	// Set the Content-Type header to application/json
	w.Header().Set("Content-Type", "application/json")

	// Encode the employees slice into JSON and write it to the response writer
	if err := json.NewEncoder(w).Encode(employees); err != nil {
		http.Error(w, fmt.Sprintf("Error encoding JSON: %v", err), http.StatusInternalServerError)
		return
	}
}
```

The `init` function is used to set up the database connection. The function reads a secret with the PostgreSQL connection string from `/var/openfaas/secrets/pg-connection` and uses it to open a new connection to the database.

The OpenFaaS philosophy is that environment variables should be used for non-confidential configuration values only, and not to inject secrets. That's why we encourage users to use the secrets functionality built into OpenFaaS. See [OpenFaaS secrets](https://docs.openfaas.com/reference/secrets/) for more information.

Save your database connection string in a file `pg-connection` in the `.secrets` directory. By storing secrets in this directory they can be picked up by `faas-cli local-run` which can be used to run and test functions locally.

> See: [The faster way to iterate on your OpenFaaS functions](https://www.openfaas.com/blog/develop-functions-locally/)

The connection string for Postgres should be formatted like this:

```sh
"postgres://<user>:<password>@<host>:<port>/<dbName>?sslmode=<sslmode>"
```

Before you deploy the function to OpenFaaS make sure the secret exists. This can be done with the faas-cli:

```sh
faas-cli secret create pg-connection \
  --from-file .secrets/pg-connection
```

Update the `stack.yaml` file:

```diff
functions:
  employee-api:
    lang: golang-otel
    handler: ./employee-api
    image: ttl.sh/employee-api:latest
+   secrets:
+     - pg-connection
```

### Add instrumentation

To get traces for the database queries we will be using two instrumentation libraries:

- [splunksql](https://github.com/signalfx/splunk-otel-go/tree/main/instrumentation/database/sql/splunksql) - Instrumentation for database/sql
- [splunkpq](https://github.com/signalfx/splunk-otel-go/tree/main/instrumentation/github.com/lib/pq/splunkpq) - Instrumentation for github.com/lib/pq that uses splunksql

> To find instrumentation libraries for the packages and frameworks used by your application you can search the [OpenTelemetry Registry](https://opentelemetry.io/ecosystem/registry/?language=go&component=instrumentation).

Add the instrumentation packages to the function.

```sh
# Move into the handler directory 
cd employee-api

# Add required packages
go get \
  "github.com/signalfx/splunk-otel-go/instrumentation/database/sql/splunksql" \
  "github.com/signalfx/splunk-otel-go/instrumentation/github.com/lib/pq/splunkpq"
```

Only a couple of small changes to the function are required to get traces for database queries using the instrumentation libraries we just added.

Update the imports to add `splunksql` and swap out `lib/pq` for `splunkpq`:

```diff
package function

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"

+	"github.com/signalfx/splunk-otel-go/instrumentation/database/sql/splunksql"

-	_ "github.com/lib/pq" // PostgreSQL driver
+	_ "github.com/signalfx/splunk-otel-go/instrumentation/github.com/lib/pq/splunkpq"
)

```

Update the `init` function and use `splunksql` to open the database connection.

```diff
func init() {
	data, err := os.ReadFile("/var/openfaas/secrets/pg-connection")
	if err != nil {
		log.Fatalf("failed to read pg-connection secret: %v", err)
	}
	connStr := string(data)

-	db, err = sql.Open("postgres", connStr)
+	db, err = splunksql.Open("postgres", connStr)
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}

	if err := db.Ping(); err != nil {
		log.Fatalf("Error connecting to the database: %v", err)
	}

	log.Println("Successfully connected to the database")
}
```

This last step is important. Queries should be able to inherit the parent span and create a nested span to track work in a nested operation. In golang spans are passed using a `context.Context`. Make sure your code is passing on the context when making database queries, e.g. use `db.QueryContext`.

```diff
func Handle(w http.ResponseWriter, r *http.Request) {
	// Query to select all employees
-	rows, err := db.Query("SELECT id, name, email FROM employee")
+	rows, err := db.QueryContext(r.Context(), "SELECT id, name, email FROM employee")
	if err != nil {
		http.Error(w, fmt.Sprintf("Error querying employees: %v", err), http.StatusInternalServerError)
		return
	}
	defer rows.Close() // Close the rows when done

...
```

Deploy the function and invoke it:

```sh
faas-cli up
```

```sh
echo | faas-cli invoke employee-api

[{"ID":1,"Name":"Alice","Email":"alice@example.com"},{"ID":2,"Name":"Bob","Email":"bob@example.com"}]
```

Depending on how you collect traces the trace from this invocation will now be available for inspection. The following screenshot shows the trace visualized in [Grafana](https://grafana.com/grafana/).

We can see the total duration of the invocation with metadata like http method, path etc. We can also see a span for the database query that was made as part of the invocation. This span shows how long the query took and includes metadata about the database and the SQL statement used.

![Visualization in Grafana of a trace produced by the employee-api function](/images/2025-05-opentelemetry-golang/postgresql-trace.png)
> Visualization in Grafana of a trace produced by the employee-api function

## Create custom traces

There may be cases where an instrumentation library is not available or you may want to add custom tracing data for some of your own functions and methods.

When using the `golang-otel` template the registered global trace provider can be retrieved to add custom spans in the function handler. A span represents a unit of work or operation. Spans are the building blocks of traces.

> Check out the [OpenTelemetry docs](https://opentelemetry.io/docs/languages/go/instrumentation/#creating-spans) for more information on how to work with spans.

On your code you can call the [otel.Tracer](https://pkg.go.dev/go.opentelemetry.io/otel#Tracer) function to get a named tracer and start a new span.

Make sure to add the required packages to the function handler:

```sh
go get "go.opentelemetry.io/otel"
```

Add custom spans in the function handler:

```go
package function

import (
	"fmt"
	"io"
	"net/http"
	"sync"

	"go.opentelemetry.io/otel"
)

func callOpenAI(ctx context.Context, input []byte) {
	// Get a tracer and create a new span
	ctx,  span := otel.Tracer("function").Start(ctx, "call-openAI")
	defer span.End()

	// Sleep for 2 seconds to simulate some work.
	time.Sleep(time.Second * 2)
}


func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		input = body
	}

	// Call function with the request context to pass on any parent spans.
	callOpenAI(r.Context(), input)

	w.WriteHeader(http.StatusOK)
	fmt.Fprintf(w, "Done processing.")
}
```

To create a new span with a tracer, you’ll need a handle on a `context.Context` instance. These will typically come from the request object and may already contain a parent span from an [instrumentation library](https://opentelemetry.io/docs/languages/go/libraries/).

You can now add [attributes](https://opentelemetry.io/docs/languages/go/instrumentation/#span-attributes) and [events](https://opentelemetry.io/docs/languages/go/instrumentation/#events), [set the status](https://opentelemetry.io/docs/languages/go/instrumentation/#set-span-status) and [record errors](https://opentelemetry.io/docs/languages/go/instrumentation/#record-errors) on the span as required.

## Conclusion

We walked through a couple of examples to show you how to use the `golang-otel` template to get traces for Golang functions. By using the new `golang-otel` template you can quickly instrument functions with minimal code changes and boilerplate. You don't have to clone and maintain your own Golang template anymore to get OpenTelemetry support.

If you already have existing function that use the `golang-middleware`, the `golang-otel` template can be used as drop-in replacement to immediately get traces for function invocations. By using instrumentation libraries or adding your own custom spans these traces can be extended to show requests as they flow through various services and components within a distributed system, allowing you to visualize its path and identify performance bottlenecks or errors.

For a more in depth overview on how to collect, store and inspect traces for OpenFaaS functions check out our blog post: [How to Trace Functions with OpenTelemetry](https://www.openfaas.com/blog/trace-functions-with-opentelemetry/)

[Reach out to us](https://www.openfaas.com/pricing/) if you have any questions about OpenTelemetry for OpenFaaS functions, or OpenFaaS in general.