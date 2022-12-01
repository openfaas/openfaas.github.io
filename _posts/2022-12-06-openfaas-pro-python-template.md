---
title: Introducing our new Python template for production.
description: "Learn how to use our new OpenFaaS Pro template with private pip modules, Postgresql and Flask."
date: 2022-12-06
categories:
- python
- postgres
- templates
- openfaaspro
author_staff_member: han
image: ./images/2022-python-pro/background.jpg
---

Learn how to use our new OpenFaaS Pro template with private pip modules, Postgresql and Flask.

In collaboration with customers, we have created a new OpenFaaS Pro template for Python, suited for commercial uses. The template is based upon our prior Open Source work, but comes with some extra features that make it easier and more convenient to run Python in a production environment. This saves you from having to fork and maintain your own version of our template, whilst still being able to use the latest features and improvements.

The OpenFaaS CLI supports [mounting secrets into the build process](https://docs.openfaas.com/cli/build/#plugins-and-build-time-secrets) through the OpenFaaS Pro plugin. This enables you to provide the private key, password or token required to use private Python packages from your functions in a secure way.

The new template supports two ways to install private [pip modules](https://packaging.python.org/en/latest/tutorials/installing-packages/):

- Install packages from private PyPI repositories like AWS Codeartifact using pip.conf
- Install packages from a private Git repositories using .netrc

Through [build options](https://docs.openfaas.com/reference/yaml/#function-build-options) the template makes it easy to meet build prerequisites required for certain Python packages like Pandas, Numpy, Pillow, Postgres, etc. Adding a build option to your function configuration will install a list of predefined packages into the function image at build time.

As a final feature we have made the Flask app instance available within the function handler. This allows users to make changes to the Flask app in the handler.py file for things like modifying loggers or adding OpenTelemetry. Previously the template had to be forked and modified to make changes to the Flask app instance.

In the next sections we will walk you through some examples to show you how to use the different features of the OpenFaaS Pro python template to build Python functions.

We assume some familiarity with the OpenFaaS CLI and how to build functions. If this is completely new to you take a look at:

- [Your first OpenFaaS Function with Python](https://docs.openfaas.com/tutorials/first-python-function/)

## Use private Python packages in your function.

To use private Python packages inside a function pip will need to authenticate to git or your private PyPI repository to install the Packages. To do this we need a way to provide these authentication credentials during the function build. The OpenFaaS Pro CLI plugin can mount different secrets into the build process. Any other mechanism should be considered insecure and risks leaking secrets into the final image.

To download and enable the OpenFaaS Pro plugin run:
```
faas-cli plugin get pro
faas-cli pro enable
```

### Install Python packages from a private git repository.

For this example we are going to create a simple private Python package:

1. In this example the package name will be `private_package`. Create the required files `__init__.py` and `setup.py` in a new directory. The directory tree should look like this:

    ```
    private_package/
        private_package/
            __init__.py
        setup.py
    ```

2. Edit `setup.py` to contain some basic information about the Python package:

    ```python
    from setuptools import setup

    setup(
        name = "private_package",
        version = "0.0.1",
        author = "OpenFaaS",
        packages=['private_package'],
    )
    ```

3. Add a simple function to `__init__.py`:

    ```python
    def greet():
        return "Hello from this private python package!!!"
    ```

Create a new private repo for this package, then commit and push the code.

A new function can be created using the OpenFaaS Pro Python template. We are going to use the private python package from within this function:

```bash
faas-cli template pull https://github.com/openfaas/openfaas-pro

faas-cli new --lang python@3.8-debian \
   withprivaterepo
mv withprivaterepo.yml stack.yml
```

Pip supports installing packages from a [Git repository](https://pip.pypa.io/en/stable/topics/vcs-support/#vcs-support) using the URI form:

```
git+https://gitprovider.com/user/repo.git@{version}
```

Make sure to add the URI for your private package to the `requirements.txt` file of your OpenFaaS function.

The private package can now be used in the function handler:

```python
from private_package import greet

def handle(event, context):
    return {
        "statusCode": 200,
        "body": greet()
    }
```

If you would try to build your function now the build would fail because there are no authentication credentials in place to access the private git repository.

Pip supports loading credentials from a user's `.netrc` file.

> See the [pip documentation](https://pip.pypa.io/en/stable/topics/authentication/#netrc-support) for more information on netrc support.

Create a `.netrc` file with credentials to access your repo:

```
machine github.com
login username
password PAT
```

Add the `.netrc` file as a build secret in the `stack.yaml` file of the function:

```diff
functions:
  withprivaterepo:
    lang: python@3.8-debian
    handler: ./withprivaterepo
    image: withprivaterepo:0.0.1
+   build_secrets:
+     netrc: ${HOME}/.netrc
```

The function can now be build and deployed using the OpenFaaS Pro CLI:

```bash
faas-cli pro publish -f stack.yml
faas-cli deploy
```

### Install packages from a private PyPi repository.

If you are using a private PyPI registry the steps are very similar to the whet we described in the previous section for private git repositories:

- Create a `pip.conf` file with the configuration and credentials for your registry.
- Mount the `pip.conf` file as a build secret.
- Use `faas-cli pro build` or `faas-cli pro publish` to build the function.

Depending on the registry you are using your `pip.conf` file might look something like this. In this example we are using AWS Codeartifact.

```
[global]
index-url = https://aws:CODEARTIFACT_TOKEN@OWNER-DOMAIN.d.codeartifact.us-east-1.amazonaws.com/pypi/REPOSITORY/simple/
```

The `stack.yaml` file has to be updated to add the `pip.conf` file as a build secret.
```diff
functions:
  withprivate:
    lang: python@3.8-debian
    handler: ./withprivate
    image: withprivate:0.0.1
+   build_secrets:
+     pipconf: ${HOME}/.config/pip/pip.conf
```

You can now use any private package from your repository in your function by including them in the `requirements.txt` file.

## Query a postgres database
Some libraries like [psycopg2](https://pypi.org/project/psycopg2/) require additional packages before they can be installed with pip. The OpenFaaS Pro template makes it easy to add these dependencies. It includes a [build_option](https://docs.openfaas.com/reference/yaml/#function-build-options) for Postgresql.

In this section we will walk through an example showing how to create a function that queries a Postgres database.

We will not go into detail on how to set up a Postgres database. You can use one of the many DBaaS services available or use [arkade](https://github.com/alexellis/arkade) to quickly deploy a database in your cluster.

Run `arkade install postgresql` to install a Postgresql database. After the installation it will print out all the instructions to get the password and connect to the database.

These are the sql statements we used to create a table and insert some data:

```sql
CREATE TABLE IF NOT EXISTS employee
(
    id INT   PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL
);

INSERT INTO employee (id,name,email) VALUES
(1,'Alice','alice@example.com'),
(2,'Bob','bob@example.com')
```

If you did not download the OpenFaaS Pro template yet you can do so with the faas-cli:

```bash
faas-cli template pull https://github.com/openfaas/openfaas-pro
```

Next create a simple function to query the database.

```
faas-cli new --lang python@3.8-debian \
   query-db
mv query-db.yml stack.yml
```
Update the `handler.py` file for the function and don't forget to add `psycopg2` to the `requirements.txt` file.

```python
import os
import json
import psycopg2
from psycopg2.extras import RealDictCursor

dbConn = None

def initConnection():
    global dbConn

    with open('/var/openfaas/secrets/postgres-password', 'r') as s:
        password = s.read()
    
    database = os.getenv('DB_NAME')
    user = os.getenv('DB_USER')
    host = os.getenv('DB_HOST')
    port = os.getenv('DB_PORT')

    dbConn = psycopg2.connect(database=database,
        user=user,
        password=password,
        host=host,
        port=port)

def handle(event, context):
    if dbConn == None:
        initConnection()

    cur = dbConn.cursor(cursor_factory=RealDictCursor)
    cur.execute("""
        SELECT
            id, name, email
        FROM employee
    """)

    data = json.dumps(cur.fetchall(), indent=2)
    
    return {
        "headers": {
            "Content-type": "application/json"
        },
        "statusCode": 200,
        "body": data
    }
```

Note that we defined a function `initConnection` to initialize the database connection. This way the connection can be reused for multiple function invocation.

The database connection parameters are read from environment variables and the password from an [OpenFaaS secret](https://docs.openfaas.com/reference/secrets/). 

The OpenFaaS philosophy is that environment variables should be used for non-confidential configuration values only, and not used to inject secrets. The secret can be created using the `faas-cli`.

Update the `stack.yml` file and add the environment variables and secret for the database connection. Also don't forget to include the `libpq` build option:

```diff
functions:
  query-db:
    lang: python@3.8-debian
    handler: ./query-db
    image: query-db:0.0.1
+   build_options:
+     - libpq
+   environment:
+     DB_NAME: postgres
+     DB_USER: postgres
+     DB_HOST: postgresql.default.svc.cluster.local
+     DB_PORT: 5432
+   secrets:
+     - postgres-password
```

Build and deploy the function with the `faas-cli`. Invoking the function should return a json response that looks like this:

```
$  curl -i http://127.0.0.1:8080/function/query-db

HTTP/1.1 200 OK
Content-Length: 163
Content-Type: application/json
Date: Thu, 01 Dec 2022 11:48:40 GMT
Server: waitress
X-Call-Id: 49e750b6-d813-4139-9d4e-96adcf79d596
X-Duration-Seconds: 0.008393
X-Start-Time: 1669895320281999527

[
  {
    "id": 1,
    "name": Slice",
    "email": "alice@example.com"
  },
  {
    "id": 2,
    "name": "Bob",
    "email": "bob@example.com"
  }
]
```

## Customise the flask app

Flask's app variable is available from within the handler. This saves you from having to fork the template and make changes when you need more control over the app instance.

The function handler, `handler.py`, that is generated when you create a new function using the OpenFaaS Pro python template includes this import statement:

```python
from flask import current_app
app = current_app.app_context().app
```

Changes to the app instance, like changing the log format or adding OpenTelemetry, can simply be made in the handler.py file.

### Use a custom log formatter

We are going to change the formatter for Flask's default log handler to inject the `X-Call-Id` header and some other request information in each log statement. Having the call-id in the log message can help with debugging errors as it allows you to trace back log messages to a specific request.

To log messages with a custom format we have to:

- Sub-class [logging.Formatter](https://docs.python.org/3/library/logging.html#logging.Formatter) to inject our own fields that can be used in messages.
- Change the formatter for Flask’s default log handler.

You can add the required code to the `handler.py` file for your OpenFaaS function before the `handle` function definition:

```python
import logging
from flask import has_request_context, request
from flask.logging import default_handler

class RequestFormatter(logging.Formatter):
    def format(self, record):
        if has_request_context():
            record.call_id = request.headers.get("X-Call-Id", None)
            record.path = request.path
            record.method = request.method
        else:
            record.call_id = None
            record.path = None
            record.method = None

        return super().format(record)

formatter = RequestFormatter(
    '[%(asctime)s] %(method)s %(path)s - Call-Id: %(call_id)s\n'
    '%(levelname)s:%(message)s'
)

default_handler.setFormatter(formatter)
app.logger.setLevel(logging.INFO)
```

> See [Flask's documentation](https://flask.palletsprojects.com/en/2.2.x/logging/) to learn more about logging in Flask.

To validate that messages are logged using the custom formatter we can log some messages in our function handler:

```python
def handle(event, context):
    app.logger.info('Running function handler')
    
    return {
        "statusCode": 200,
        "body": "Hello from this OpenFaaS Pro template!"
    }
```

Use the `faas-cli` to build and deploy your function. The `faas-cli logs` command can be used to fetch the logs.

Invoking the function should output logs that look something like this:

```
2022-11-30T09:32:04Z 2022/11/30 09:32:04 stderr: [2022-11-30 09:32:04,473] GET / - Call-Id: d49de5df-7085-466e-b871-86c018212352
2022-11-30T09:32:04Z 2022/11/30 09:32:04 stderr: INFO:Running function handler
2022-11-30T09:32:04Z 2022/11/30 09:32:04 GET / - 200 OK - ContentLength: 38B (0.0016s)
```

By default the OpenFaaS watchdog prefixes every log line read from the function process with "Date Time" + "stderr/stdout". In some cases this might clutter your logs. The prefixes can be disabled by setting the environment variable `prefix_logs` to false on the function.

```diff
functions:
  logging:
    lang: python@3.8-debian
    handler: ./logging
    image: welteki2/flask-logging:latest
+    environment:
+     prefix_logs: false
```

## Conclusion

We took a look at the new features of the OpenFaaS Pro Python template and showed you how to use them by means of some examples.

- We provide a safe and easy way to use private Python packages within your functions - whether that's using a private PyPi server or a private Git repository.
- The new `libpq` *build option* in the template makes it easy to use Python drivers for Postgresql.
- We made the Flask app instance available within the function handler allows you to easily change it without needing to fork the template.

If there are native packages you need, or combinations of apt packages you often use, please let us know so we can improve the template and add additional build options.

Some of our other content that uses Python functions:

- [Exploring the Fan out and Fan in pattern with OpenFaaS](https://www.openfaas.com/blog/fan-out-and-back-in-using-functions/)

