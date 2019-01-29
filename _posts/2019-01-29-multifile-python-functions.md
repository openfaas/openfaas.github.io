---
title: Designing Python Functions with multiple files
description: "Are your Python functions bringing you joy? Or, what happens when you want to split your Python function into multiple modules?"
date: 2019-01-29
image: /images/multifile-python-function/pexels-book-stack-books-bookshop-264635.jpg
categories:
  - python
  - coding
  - examples
author_staff_member: lucas
dark_background: true
---

As a core contributor to OpenFaaS, I hangout in the OpenFaaS Slack a lot (to help new users and contributors?). You can join the community [here][openfaas-slack-signup]. A new user joined the community recently and asked:

"How can I write a function in Python that uses multiple source files so that the main `handler.py` is able to import helper functions from separate source files."

Using multiple files to create sub-modules helps keep the code organized and makes reusing code between projects/functions much easier. Functions and variables defined within a module importable into other modules and allows you to scope your function and variable names without worrying about conflicts. From [the Python docs](https://docs.python.org/3/tutorial/modules.html#more-on-modules):

> Each module has its own private symbol table, which is used as the global symbol table by all functions defined in the module. Thus, the author of a module can use global variables in the module without worrying about accidental clashes with a user’s global variables.

Today, I will demonstrate how to do this in OpenFaaS by creating a Python 3 word count function that is split across multiple files.

I assume some familiarity with OpenFaaS, so ou will need a basic understanding of how to create functions in OpenFaaS, but if you're new you can get up to speed using the [workshop][workshop-repo]. Instead, I want to focus on how to comfortably develop a Python function as it goes from a small "one-liner" function to a larger multi-module project.

## Start the function

Next, to start a new Python 3 function, I like to use the flask template because I am going to load a static list of "stop words" into memory when the function starts. Using the flask templates allows the function to do this only once instead of on each invocation.

Change `--prefix` to your Docker Hub account or your private registry. Note you will need to use docker login before the next step.

```sh
$ faas-cli template store pull python3-flask
$ faas-cli new wordcount --lang python3-flask --prefix=alexellis
```

The project should now look like

```txt
.
├── stack.yml
├── template
│   ├── python27-flask
│   │   ├ ...
│   ├── python3-flask
│   │   ├ ...
│   └── python3-flask-armhf
│       ├ ...
└── wordcount
    ├── __init__.py
    ├── handler.py
    └── requirements.txt
```

## Relative imports

Python allows you to reuse code from other files [by `import`ing it][pep-328]. For functions, [relative imports][abs-vs-rel-imports] allow us to specify those resources relative to the file doing the import. This provides maximum flexibility because the import is then agnostic to how/where the package is installed, which is perfect for OpenFaaS functions.

We're going to start by creating two more files:

```sh
touch wordcount/stopwords
touch wordcount/wordcount.py
```

The project should now look like this

```txt
.
├── stack.yml
├── template
│   ├── ...
└── wordcount
    ├── __init__.py
    ├── handler.py
    ├── requirements.txt
    ├── stopwords
    └── wordcount.py
```

The `stopwords` is a plain text file of words that will be excluded in the wordcount. These are short common words that you would not want to include in a wordcount visualization such as:

```txt
a
an
him
her
```

This list of words will depend on your use case and local, you should add more to match your needs, for example [the 100 most common English words][100-common-en-words] or [the 100 most common French words][100-common-fr-words].

All of the code for processing text and generating the counts is found in `wordcount.py`:

```py
# modified wordcount.py
import unicodedata
import os
from typing import Dict, List

from operator import itemgetter
from collections import defaultdict

FILE = os.path.dirname(__file__)
STOPWORDS = set(
    map(str.lower,
        map(str.strip,
            open(os.path.join(FILE, 'stopwords'), 'r').readlines()
            )
        )
)


def process_text(text: bytes) -> Dict[str, int]:
    """Splits a long text into words a count of interesting words in the text.

    process_text will eliminate any of the stopwords, punctuation, and normalize
    the text to merge cases and plurals into a single value.
    """
    words = text.decode("utf-8").split()
    # remove stopwords
    # remove 's
    words = [
        word[:-2] if word.lower().endswith(("'s",))
        else word
        for word in words
    ]
    # remove numbers
    words = [word for word in words if not word.isdigit()]
    words = [strip_punctuation(word) for word in words]
    words = [word for word in words if word.lower() not in STOPWORDS]

    return process_tokens(words)

def process_tokens(words: List[str]) -> Dict[str, int]:
    """Normalize cases and remove plurals.
    """
    # ...

def strip_punctuation(text: str) -> str:
    # ...
```

Note that processing the `STOPWORDS` at the start of the file means it will be loaded into memory once the package is imported rather than on every request, which would create additional latency and I/O overhead.

Using a relative import, we can very easily use the `process_text` method to create a very simple `handler.py`:

```py
# handler.py
import json
from .wordcount import process_text


def handle(req):
    """handle a request to the function
    Args:
        req (str): request body
    """

    return json.dumps(process_text(req))
```

This style of relative imports will work for any file or sub-package you include inside of your function folder. Additionally, your IDE and linter will be able to resolve the imported code correctly!

## Deploy and test the function

You should have [OpenFaaS deployed][openfaas-deployment] and have run `faas-cli login` already.

```sh
$  faas-cli up -f wordcount.yml
# Docker build output ...
Deploying: wordcount.

Deployed. 202 Accepted.
URL: http://127.0.0.1:31112/function/wordcount

$ echo 'This is some example text that we want to see a frequency response for.  It has text like apple, apples, apple tree, etc' | faas-cli -f wordcount.yml invoke wordcount
{"example": 1, "text": 2, "want": 1, "see": 1, "frequency": 1, "response": 1, "for": 1, "apple": 3, "tree": 1, "etc": 1}
```

## A note on Python 2 usage

Using the [`__future__` package][python-future] you can get the same behavior in your Python 2 functions. Add `from __future__ import absolute_import` as the first import in `handler.py` and `wordcount.py` to ensure that the relative imports are resolved correctly.

Note, Python 2 is [End Of Life this year][python2-eol] and will not receive any bugfix releases after 2020. If you are still transitioning to Python 3, use the `__future__` package to help smooth the transition.

## Wrapping up

Using relative imports allows the creation of Python functions that are split between several files. We could take this further and import from sub-folders or sub-folders of sub-folders. This has the added benefit that the code is valid in both your local environment and the final docker container. Try the [completed code example in this repo.][project-repo]

Checkout the [OpenFaas Workshop][workshop-repo] for a step-by-step guide of writing and deploying a Python function detailing the other features of OpenFaas: asynchronous functions, timeouts, auto-scaling, and managing secret values.

For questions, comments and suggestions follow us on [Twitter @openfaas][openfaas-twitter] and [join the Slack community][openfaas-slack-signup].

[openfaas-homepage]: https://openfaas.com
[openfaas-slack-signup]: https://docs.openfaas.com/community/#slack-workspace
[openfaas-twitter]: https://twitter.com/openfaas
[openfaas-deployment]: https://docs.openfaas.com/deployment/
[project-repo]: https://github.com/LucasRoesler/openfaas-multifile-example
[workshop-repo]: https://github.com/openfaas/workshop
[100-common-en-words]: https://www.espressoenglish.net/the-100-most-common-words-in-english/
[100-common-fr-words]: https://www.vistawide.com/french/top_100_french_words.htm
[python2-eol]: https://legacy.python.org/dev/peps/pep-0373/
[python-future]: https://docs.python.org/2/library/__future__.html
[abs-vs-rel-imports]: https://realpython.com/absolute-vs-relative-python-imports/#relative-imports
[pep-328]: https://www.python.org/dev/peps/pep-0328/
