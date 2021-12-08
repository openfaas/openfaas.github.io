---
title: "Learn how to unit-test your OpenFaaS Functions using Pytest"
description: "Lucas will show you how to test OpenFaaS functions written in Python with the Pytest framework"

date: 2021-06-15
image: /images/2021-06-pytesting/conor-samuel-K5BFXOsFp7g-unsplash.jpg
categories:
  - python
  - flask
  - testing
  - pytest
  - usecase
author_staff_member: lucas
dark_background: false
---

Lucas will show you how to test OpenFaaS functions written in Python with the Pytest framework.

In a recent [Pull Request](https://github.com/openfaas/python-flask-template/pull/42), we integrated unit-testing to the build process of the [OpenFaaS Python Flask templates](https://github.com/openfaas/python-flask-template). Since there are multiple test frameworks including [pytest](https://docs.pytest.org/en/6.2.x/), we opted to integrate with a test runner called [tox](https://tox.readthedocs.io/), so that you can pick whichever unit test framework you prefer.

The upshot is that you can focus on implementing your functions _and_ tests and then let OpenFaaS handle the rest. The `faas-cli up` command can then be run locally or in a CI/CD environment to build, test, and deploy your Python functions with a single.

In blog post, I'll show you how to take advantage of unit tests written with Pytest in your OpenFaaS workflow. 

## Introduction

In this post we are going to build a _very small_ calculator function and then write a few tests that show how we can ensure our calculator works _before_ we deploy it.  We will show you how to run the tests locally during development and then show how this is integrated into the OpenFaaS build flow so that you you can run the tests automatically in your CI/CD flows with a single command.

### Setup the project

All of the code in this example can be found on [Github](https://github.com/LucasRoesler/pytest-openfaas-sample), if you are already familiar with the python3-flask template and pytest, then you can jump ahead and see what the final implementation looks like.

Fetch the template from the store:

```sh
$ mkdir pytest-sample
$ cd pytest-sample
$ faas-cli template store pull python3-flask
```

Create a new function called `calc` and then rename its YAML file to the default `stack.yml`, to avoid needing the `-f` flag later on.

```sh
$ faas-cli new --lang python3-flask calc
$ mv calc.yml stack.yml
```

Since the templates are never committed to Git, each time someone clones the repository, they would need to run `faas-cli template store pull`. Fortunately, there is a work-around which adds the template name and source to the `stack.yml` file to automate this task.

```yaml
configuration:
  templates:
    - name: python3-flask
      source: https://github.com/openfaas/python-flask-template
```

### Setup the local python environment

It's possible to install dependencies like `flask`, `tox` and `pytest` directly to your system using `pip3 install`, however Python practitioners will often use a virtual environment so that each project or function can have a different version of dependencies.

> See also: [RealPython's primer on virtual environments](https://realpython.com/python-virtual-environments-a-primer/)

I use [conda](https://docs.conda.io/projects/conda/en/latest/) for my local virtual environments, but you can of course use [`virtualenv`](https://virtualenv.readthedocs.org/en/latest/) or [`venv`](https://docs.python.org/3/library/venv.html).

In short this creates an isolated and repeatable development environment which you can delete and recreate if you need.

```sh
$ conda create -n pytest-sample tox
$ conda activate pytest-sample
$ cat <<EOF >> requirements.txt
pydantic==1.7.3
flask==1.1.2
EOF

$ cat <<EOF >> dev.txt
tox
pytest
black
pylint
EOF
$ conda install --yes --file requirements.txt
$ conda install --yes --file dev.txt
```

Now we are ready to develop the calculator.

### The calculator implementation

The calculator will be a simple web endpoint that accepts payloads like the following:

```json
{
"op":"+",
"var1":"1",
"var2":"2"
}
```

This is the output you can expect:

```json
{
"value":"3"
}
```

There are several ways that this request could fail. To help validate the request (and to give us more a few more things to test) we can use [`pydantic`](https://pydantic-docs.helpmanual.io/) to do the hard validation work and keep our function lean.

Update your `requirements.txt` to include

```
pydantic==1.7.3
```

Put this into your `handler.py`:

```py
from pydantic import BaseModel, ValidationError
from enum import Enum, unique


@unique
class OperationType(Enum):
    ADD = "+"
    SUBTRACT = "-"
    MULTIPLY = "*"
    DIVIDE = "/"
    POWER = "^"


class Calculation(BaseModel):
    op: OperationType
    var1: float
    var2: float

    def execute(self) -> float:
        if self.op is OperationType.ADD:
            return self.var1 + self.var2

        if self.op is OperationType.MULTIPLY:
            return self.var1 * self.var2

        raise ValueError("unknown operation")


def handle(req) -> (dict, int):
    """handle a request to the function
    Args:
        req (str): request body
    """

    try:
        c = Calculation.parse_raw(req)
    except ValidationError as e:
        return {"message": e.errors()}, 422
    except Exception as e:
        return {"message": e}, 500

    return {"value": c.execute()}, 200
```

At this point we could deploy the function and use it

```sh
$ faas-cli deploy
Deploying: calc.

Deployed. 202 Accepted.
URL: http://127.0.0.1:8080/function/calc
$ echo '{"op":"+", "var1": 1, "var2": 1}' | faas-cli invoke calc
{"value":2.0}
```

We can see the  nice work `pydantic` does for us by sending an empty `{}` payload

```sh
$  echo '{}' | faas-cli invoke calc
Server returned unexpected status code: 422 - {"message":[{"loc":["op"],"msg":"field required","type":"value_error.missing"},{"loc":["var1"],"msg":"field required","type":"value_error.missing"},{"loc":["var2"],"msg":"field required","type":"value_error.missing"}]}
```

## Adding tests
[`pytest`](https://docs.pytest.org/en/6.2.x/) is a popular testing framework that provides automated test discovery and detailed info on failing assert statements, among [other features](https://docs.pytest.org/en/6.2.x/#id1). We will setup our project so that `pytest` works out of the box, this means we will name the test files `*_test.py` and prefix out test functions with `test_`.

Create a new file in your function

```sh
$ touch calc/handler_test.py
```
then add the following test cases for a couple of our happy paths

```py
from . import handler as h

class TestParsing:
    def test_operation_addition(self):
        req = '{"op": "+", "var1": "1.0", "var2": 0}'
        resp, code = h.handle(req)
        assert code == 200
        assert resp["value"] == 1.0

    def test_operation_multiplication(self):
        req = '{"op": "*", "var1": "100.01", "var2": 1}'
        resp, code = h.handle(req)
        assert code == 200
        assert resp["value"] == 100.01
```

Note that we import then `handler` from `.`, we don't use an absolute import like `from calc import handler as h`. This is required to be compatible with the the OpenFaaS build process.

Now, change into the function directory and run the tests using `pytest`

```sh
$ pytest
==================== test session starts =====================
platform linux -- Python 3.8.8, pytest-6.2.2, py-1.10.0, pluggy-0.13.1
rootdir: pytest-sample/calc
collected 2 items

handler_test.py ..                                     [100%]

===================== 2 passed in 0.03s ======================
```

If you want to see an error, just change the assertion in one of the tests to a "wrong" value and run pytest again:

```sh
pytest
==================== test session starts =====================
platform linux -- Python 3.8.8, pytest-6.2.2, py-1.10.0, pluggy-0.13.1
rootdir: /home/lucas/code/openfaas/sandbox/pytest-sample/calc
collected 2 items

handler_test.py F.                                     [100%]

========================== FAILURES ==========================
____________ TestParsing.test_operation_addition _____________

self = <calc.handler_test.TestParsing object at 0x7f01f8a08400>

    def test_operation_addition(self):
        req = '{"op": "+", "var1": "1.0", "var2": 0}'
        resp, code = h.handle(req)
        assert code == 200
>       assert resp["value"] == 2.0
E       assert 1.0 == 2.0

handler_test.py:51: AssertionError
================== short test summary info ===================
FAILED handler_test.py::TestParsing::test_operation_addition
================ 1 failed, 1 passed in 0.04s =================
```


A test for the validation will look like

```python
def test_operation_parsing_error_on_empty_obj(self):
    req = '{}'

    resp, code = h.handle(req)
    assert code == 422
    # should be a list of error
    errors = resp.get("message", [])
    assert len(errors) == 3
    assert errors[0].get("loc") == ('op', )
    assert errors[0].get("msg") == "field required"

    assert errors[1].get("loc") == ('var1', )
    assert errors[1].get("msg") == "field required"

    assert errors[2].get("loc") == ('var2', )
    assert errors[2].get("msg") == "field required"
```

Checkout the [example repo](https://github.com/LucasRoesler/pytest-openfaas-sample/blob/main/calc/handler_test.py) for the other example tests.

### Integrate testing into the OpenFaaS workflow

The `python3-flask` template can run pytest unit tests automatically. If one of your tests fails, the build will fail and you can see the `pytest` output

```sh
$ faas-cli build
# truncated ....
#24 7.477 test run-test: commands[0] | pytest
#24 7.662 ============================= test session starts ==============================
#24 7.662 platform linux -- Python 3.7.10, pytest-6.2.4, py-1.10.0, pluggy-0.13.1
#24 7.662 cachedir: .tox/test/.pytest_cache
#24 7.662 rootdir: /home/app/function
#24 7.662 collected 8 items
#24 7.662
#24 7.662 handler_test.py ...F....                                                 [100%]
#24 7.689
#24 7.689 =================================== FAILURES ===================================
#24 7.689 _____________________ TestParsing.test_operation_addition ______________________
#24 7.689
#24 7.689 self = <function.handler_test.TestParsing object at 0x7fc06f52bf50>
#24 7.689
#24 7.689     def test_operation_addition(self):
#24 7.689         req = '{"op": "+", "var1": "1.0", "var2": 0}'
#24 7.689         resp, code = h.handle(req)
#24 7.689         assert code == 200
#24 7.689 >       assert resp["value"] == 2.0
#24 7.689 E       assert 1.0 == 2.0
#24 7.689
#24 7.689 handler_test.py:51: AssertionError
#24 7.689 =========================== short test summary info ============================
#24 7.689 FAILED handler_test.py::TestParsing::test_operation_addition - assert 1.0 == 2.0
#24 7.689 ========================= 1 failed, 7 passed in 0.07s ==========================
#24 7.709 ERROR: InvocationError for command /home/app/function/.tox/test/bin/pytest (exited with code 1)
#24 7.709 ___________________________________ summary ____________________________________
#24 7.709   lint: commands succeeded
#24 7.709 ERROR:   test: commands failed
#24 ERROR: executor failed running [/bin/sh -c if [ "$TEST_ENABLED" == "false" ]; then     echo "skipping tests";    else     eval "$TEST_COMMAND";     fi]: exit code: 1
------
 > [stage-1 18/19] RUN if [ "true" == "false" ]; then     echo "skipping tests";    else     eval "tox";     fi:
------
executor failed running [/bin/sh -c if [ "$TEST_ENABLED" == "false" ]; then     echo "skipping tests";    else     eval "$TEST_COMMAND";     fi]: exit code: 1
[0] < Building calc done in 16.67s.
# truncated ....
```

If you are working locally and need to disable the tests for a build, you can use the build arg `--build-arg TEST_ENABLED=false`.

### Running the tests in CI

If you are a fan of Github Actions, you only need two steps:

```yaml
- name: Setup tools
  env:
    ARKADE_VERSION: "0.6.21"
  run: |
    curl -SLs https://github.com/alexellis/arkade/releases/download/$ARKADE_VERSION/arkade > arkade
    chmod +x ./arkade
    ./arkade get faas-cli

- name: Build and Test Functions
  run: faaas-cli build
```

Here the [arkade tool](https://get-arkade.dev/) created by the OpenFaaS community is used as a downloader for `faas-cli`. 

## Wrapping up

In this post we've shown how to add unit tests to your Python functions and how to run those tests in your local development and CI environments.

Do you have any tips and tricks for testing in Python?  [Let us know on Twitter @openfaas](https://twitter.com/openfaas).

Would you like to keep learning? The Python 3 template is a core part of the new [Introduction to Serverless course by the LinuxFoundation](https://www.openfaas.com/blog/introduction-to-serverless-linuxfoundation/)

If Python is not your language of choice, then the [Go](https://github.com/openfaas/templates/blob/6b8c6082ffb98bd4e951b11509508e99c769bce1/template/go/Dockerfile#L35), [Node12](https://github.com/openfaas/templates/blob/6b8c6082ffb98bd4e951b11509508e99c769bce1/template/node12/Dockerfile#L44), and the [Node14](https://github.com/openfaas/templates/blob/6b8c6082ffb98bd4e951b11509508e99c769bce1/template/node14/Dockerfile#L44) templates also have testing integrated into the build process.

Would like to have automated testing in _your_ favorite language template? Checkout out the implementation in the [`python3-flask` template](https://github.com/openfaas/python-flask-template/blob/12db680950b42c7cfcc7d21ba036bd1397d62eb7/template/python3-flask/Dockerfile#L45-L49) and let us know how to adapt it to your favorite [template](https://github.com/openfaas/templates/tree/master/template).
