---
title: Serving Data Science Models with OpenFaaS
# TODO
description: "Build and deploy a name classification function with OpenFaaS [<--FUN SUGGESTIONS WELCOME]"
date: 2019-06-01
image: /images/multifile-python-function/pexels-book-stack-books-bookshop-264635.jpg
categories:
  - python
  - coding
  - examples
  - datascience
  - templates
author_staff_member: lucas
dark_background: true
---

Last month OpenFaaS was at [Kubecon Barcelona][kubecon-homepage]

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Up bright and early? We&#39;re meeting for an OpenFaaS f2f with end-users, contributors and community. 10.20am outside the keynote hall. See you there? <a href="https://twitter.com/hashtag/serverless?src=hash&amp;ref_src=twsrc%5Etfw">#serverless</a> <a href="https://twitter.com/hashtag/community?src=hash&amp;ref_src=twsrc%5Etfw">#community</a> <a href="https://twitter.com/hashtag/faas?src=hash&amp;ref_src=twsrc%5Etfw">#faas</a> <a href="https://twitter.com/hashtag/microservices?src=hash&amp;ref_src=twsrc%5Etfw">#microservices</a> <a href="https://twitter.com/hashtag/gitops?src=hash&amp;ref_src=twsrc%5Etfw">#gitops</a> <a href="https://t.co/Af3BmXvaKl">pic.twitter.com/Af3BmXvaKl</a></p>&mdash; OpenFaaS (@openfaas) <a href="https://twitter.com/openfaas/status/1131450940807098368?ref_src=twsrc%5Etfw">May 23, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

A frequent topic was deploying data science models to Kubernetes and, of course, can OpenFaaS help deploy models? In this post we will introduce a new function template aimed at Python data scientists and walk through a concrete example of deploying a [PyTorch][pytorch-homepage] model.

## The `pydatascience template`
The [pydatascience template][pydata-template] showcases a couple of ideas that anyone can leverage in their own functions and templates:

1. using the [Conda package manager][conda-homepage]
2. setting up a non-root user Python environment
3. [multi-module Python function][multifile-blog-post]
4. using HTTP mode in [of-watchdog][of-watchdog-homepage] to load an asset (in this case a model) into memory during startup

## The name classifier function

In this post, we share an example [name classifier][name-classifier-repo].  It is a relatively simple function that accepts a `name` and then attempts to guess the nationality of that name, returning the top three guesses.

```sh
echo "Lucas" | faas-cli invoke classify
[
  ["(-1.4300)","Irish"],
  ["(-1.6112)","Italian"],
  ["(-2.0314)","Dutch"]
]
```

You can try this in your own OpenFaaS cluster using

```sh
faas-cli deploy --image=theaxer/classify:latest --name=classify
```

Caution, I did not say it would be a great guesser. This model was built on a relatively small data set and is intended to be a fun toy. And remember, with all things data science, "with great power comes great responsibility".

## Understanding the template

### Why Conda
I have recently started to use Conda for many of my own experiments with Python, especially when they involve Pandas and Numpy, because the install is very fast and environment management is fairly easy.  For function development and build, the speed is really nice. For this project it was also the easiest way to [install PyTorch][pytorch-install].  Finally, Conda also supports non-Python packages, e.g. curl, yarn-js, and zeromq are installable via Conda.

### Setting up a non-root function
If you spend much time with Docker containers, you will hear people talk about using non-root images. These images tend to be much safer to deploy. Fortunately, OpenFaaS [makes it easy to enforce][of-force-non-root], even when the original image is not non-root by default.  When we build new templates, it is important that we consider non-root deployments as the default. For Python environments, Conda made this very easy.

The first thing the Dockerfile does is create a new user and then setup and fix the permissions on some standard folders.  This will ensure that when we change users later, Conda and the function code will run smoothly. The `/opt/conda` folder is often used by Conda and the function code will eventually be put into `/root` (as is done in many of the core templates).

```dockerfile
RUN addgroup app && adduser app --system --ingroup app \
    && mkdir -p /opt/conda && chown -R app /opt/conda \
    && chown -R app /root && chmod -R go+rX /root

ENV HOME /home/app
ENV PATH=$HOME/conda/bin:$PATH

RUN apt-get update \
    && apt-get -y install curl bzip2 ${ADDITIONAL_PACKAGE} \
    && curl -sSL https://repo.continuum.io/miniconda/Miniconda3-latest-Linux-x86_64.sh -o /tmp/miniconda.sh \
    && curl -sSL https://github.com/openfaas-incubator/of-watchdog/releases/download/0.5.1/of-watchdog > /usr/bin/fwatchdog \
    && chown app /tmp/miniconda.sh \
    ...
```

Once the additional packages and watchdog are installed, we can switch to the non-root `app` user and finish the Python installation

```dockerfile
WORKDIR /root/
USER app

RUN bash /tmp/miniconda.sh -bfp $HOME/conda \
    && conda install -y python=3 \
    && conda update conda \
    && conda clean --all --yes \
    && rm -rf /tmp/miniconda.sh
```

From here on out, the Docker image will use the `app` user, improving the security of the final function.  This pattern should work for almost any template.  The hard part is knowing which folders the `app` user will need full permissions for. This is where Conda was helpful, because it was easy to find and setup the required permissions and once those folders are configured, Conda behaves as expected when run as a non-root user.

### A multi-module template

Earlier [this year][multifile-blog-post] we highlighted how to use multiple files and modules to organize your Python functions. This new template follows this pattern out of the box.  It provides a "core" module for putting utility methods, a handler file, which is where you need to implement your function logic, and a "training" file where you can put the logic for training your model.

```
function
├── __init__.py
├── core
│   ├── README.md
│   ├── __init__.py
│   └── utils.py
├── handler.py
└── train.py
```

Like the basic `python` template, only the `handler.py` implementation is required, and both the `core` module and the `train.py` could be replaced if you needed, but this structure starts you on a path to keeping the code organized.

## Name classifier implementation

### From a template to actual code
The name classifier function uses the [neural network implementation in PyTorch][pytorch-nn-docs].  PyTorch has a great [introduction and walk-through][pytorch-nn-intro] for neural network package and [model training][pytorch-training]. In this post we focus on what a concrete and complete implementation looks like. All of the interesting details about the [implementation of the model][classifier-impl], the utilities used to parse the training data, and the utility for applying the model to a new inputs are stored in the `core` module.  This `core` module can then be used in _both_ the function handler and the training script. This code is also easier to reuse in a new function because it is cleanly isolated from the function itself.

```
classify
├── __init__.py
├── core
│   ├── README.md
│   ├── __init__.py
│   ├── const.py
│   ├── model.py
│   └── utils.py
├── data
│   ├── char-rnn-classification.pt
│   └── names
│       ├── Arabic.txt
│       ├── Chinese.txt
│       ├── ...
│       └── Vietnamese.txt
├── handler.py
├── requirements.txt
└── train.py
```

### Training
Another point to note is the training data folder is also included here, `data/names` and a serialized model is also include `data/char-rnn-classification.pt`.

This template is designed to run the training as part of the build process.  You can easily trigger the training using

```bash
python train.py
```

This will generate a new serialized model `data/char-rnn-classification.pt`.

There are two methods for [saving PyTorch models][pytorch-saving-models]:

1. save the entire model using `pickle`, or
2. saving just the model `state_dict`.


We have opted for the second method because it is more portable.  The `pickle` method is sensitive to the Python environment and I had issues making sure that it would load correctly in the deployed function.

```python
torch.save(rnn.state_dict(), "data/char-rnn-classification.pt")
```

### Loading the model into function memory
Using the `HTTP` mode in the [of-watchdog][of-watchdog-homepage] enables us to load this model into memory once and reuse it for multiple requests. We only need to load the model at the start of the `handler.py` implementation

```python
import json
import os
from pathlib import PurePath
from typing import Any, List

import torch
from torch.autograd import Variable

from .core import const, model, utils

FUNCTION_ROOT = os.environ.get("function_root", "/root/function/")

# init model
RNN = model.RNN(const.N_LETTERS, const.N_HIDDEN, const.N_CATEGORIES)
# fill in weights
RNN.load_state_dict(
    torch.load(str(PurePath(FUNCTION_ROOT, "data/char-rnn-classification.pt")))
)


def predict(line: str, n_predictions: int = 3) -> List[Any]:
    """omitted for brevity"""

def handle(req: bytes) -> str:
    """handle a request to the function
    Args:
        req (bytes): request body
    """

    if not req:
        return json.dumps({"error": "No input provided", "code": 400})

    name = str(req)
    output = predict(name)

    return json.dumps(output)
```

When a function instance is instantiated, e.g. during scaling or deployment, this file is parsed and the model is loaded into memory. This will happen exactly once because the HTTP mode loads this handler as a very small background web sever.  The original forking mode in the watchdog would instead load this file for every invocation. When loading models, this creates additional latency.

This template uses Flask to power the background web server. The `handle` can return any value that [Flask would accept][flask-return-values].  This provides a lot of flexibility to control the response. For example, you could instead set the error status code and body like this

```python
return json.dumps({"error": "No input provided"}), 400
```

### Deployment
This template is designed to bundle the pre-trained model into the final Docker image. This means that the deployment steps look like this

```bash
cd classify && python train.py && cd -
faas-cli build classify --tag=sha
```

This results in a completely self-contained Docker image that does not need access to a database or S3 during runtime. This provides several benefits:

1. This model becomes very easy to share because you don't need to share access to your model storage.
2. It also means that each new deployment is completely versioned, you know the version of the model from the Docker tag. This makes rolling backward or forward as simple as changing the Docker tag on the deployment.
3. One final benefit is that startup time can be slightly faster because once a node has the Docker image in its cache, it has everything it needs to start new instances of the function.  If you load the model from an external source, then every function instance that starts _must_ curl/copy from that external location, there is no way to cache it for new instances.

You can try the latest version of this function in your own cluster using

```bash
faas-cli deploy --image=theaxer/classify:latest --name=classify
```

## A note about Python 2 deprecation

<blockquote class="twitter-tweet"><p lang="en" dir="ltr">Remember that Python 2 will reach end of life on 1/1/2020. For the impact on *your* project, see <a href="https://t.co/giiS9CNn8V">https://t.co/giiS9CNn8V</a></p>&mdash; Guido van Rossum (@gvanrossum) <a href="https://twitter.com/gvanrossum/status/1133496146700058626?ref_src=twsrc%5Etfw">May 28, 2019</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

You will not find a Python 2 template in the [pydatascience-template][pydata-template] repo because we are coming very quickly to the end-of-life for Python 2.  If you are still using Python 2, the templates could be forked and modified, but please be careful. Most packages will start deprecating Python 2 support soon.


## Wrapping up

Data science is of course a popular topic these days and OpenFaaS can help [simplify, standardize, and speed up][kubecon-bt-journey] the deployment process for your team. This post introduces just one example of what a data science focused template could look like. If you are building and deploying data science models, let us know what you think through the [Slack community][of-slack] or [Twitter][of-twitter].


### Going further
Want to help improve the template, join our slack and ping `@Lucas Roesler` or open an [issue on Github][name-classifier-issues].

PyTorch has also provided a [C++ frontend][pytorch-cpp] that allows deploying the serialized model as a C++ function.  There is also a [Go frontend][pytorch-golang] in progress.  The `pydatascience-template` is designed to be reusable for any data science library, but it would be interesting to see what kind of optimizations could be created using one of these other frontends for deployment.

[conda-homepage]: https://docs.conda.io/projects/conda/en/latest/
[flask-return-values]: http://flask.pocoo.org/docs/1.0/quickstart/#about-responses
[kubecon-homepage]: https://events.linuxfoundation.org/events/kubecon-cloudnativecon-europe-2019/
[kubecon-bt-journey]: https://kccnceu19.sched.com/event/MPeF/accelerating-the-journey-of-an-ai-algorithm-to-production-with-openfaas-joost-noppen-bt-plc-alex-ellis-openfaas-ltd
[of-slack]: https://docs.openfaas.com/community
[of-twitter]: https://twitter.com/openfaas
[pytorch-cpp]: https://pytorch.org/tutorials/advanced/cpp_frontend.html
[pytorch-golang]: https://github.com/orktes/go-torch
[pytorch-homepage]: https://pytorch.org/
[pytorch-install]: https://pytorch.org/get-started/locally/
[pytorch-nn-docs]: https://pytorch.org/docs/stable/nn.html#module
[pytorch-nn-intro]: https://pytorch.org/tutorials/beginner/blitz/neural_networks_tutorial.html
[pytorch-training]: https://pytorch.org/tutorials/beginner/blitz/cifar10_tutorial.html
[pytorch-saving-models]: https://pytorch.org/tutorials/beginner/saving_loading_models.html
[pydata-template]: https://github.com/LucasRoesler/pydatascience-template
[multifile-blog-post]: /blog/multifile-python-functions/
[of-watchdog-homepage]: https://github.com/openfaas-incubator/of-watchdog
[name-classifier-repo]: https://github.com/LucasRoesler/name-classifier
[name-classifier-issues]: https://github.com/LucasRoesler/name-classifier/issues
[classifier-impl]: https://github.com/LucasRoesler/name-classifier/blob/master/classify/core/model.py
<!-- TODO -->
[of-force-non-root]: FIND_LINK_FOR_OF_FORCE_NONROOT_USER