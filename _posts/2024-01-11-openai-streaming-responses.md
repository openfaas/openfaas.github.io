---
title: "Stream OpenAI responses from functions using Server Sent Events"
description: "OpenAI models can take some time to fully respond, so we'll show you how to stream responses from functions using Server Sent Events (SSE)."
date: 2024-01-11
categories:
- openfaas
- ai
- openai
- python
dark_background: true
image: "/images/images/2024-openai-streaming/background.jpg"
author_staff_member: alex
hide_header_image: true
---

[OpenAI](https://openai.com/) models can take some time to fully respond, so we'll show you how to stream responses from functions using [Server Sent Events (SSE)](https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events).

With the latest versions of the OpenFaaS Standard helm charts, watchdog and python-flask template, you can now stream responses using Server Sent Events (SSE) directly from your functions. Prior to these changes, if a chat completion was going to take 10 seconds to emit several paragraphs of text, the user would have had to wait that long to see the first word.

Now, the first word will be displayed as soon as it's available from the OpenAI API. This is a great way to improve the user experience of your OpenAI-powered applications and was requested by one of our customers building a chat-driven experience for DevOps.

## What are Server Sent Events and why are they useful?

Server Sent Events (SSE) are a way to stream data from a server to a client. They are a simple way to push data from a server to a client, and are used in a variety of applications, including chat applications, real-time analytics, and more.

An alternative to SSE is long polling, where the client makes a request to the server and waits for a response. This is a less efficient way to stream data, as it requires the client to make a new request every time it wants to receive new data.

SSEs only work in one direction, so the client cannot send data back to the server. If two-way communication is required, then websockets are a better option.

* SSE: The server can send data over a long period of time to the client, but the client cannot send data to the server.
* Long polling: The client makes a request to the server and waits for a response. Over the lifetime of the transaction, the client may have to make multiple new connections to the server. This approach is used in AWS SQS.
* Websockets: The client and server can send data to each other over a long period of time. This approach is used in [inlets](https://inlets.dev) to build secure network tunnels to expose websites from private networks.

## How to use SSE with OpenFaaS

If we use the python3-flask template, it has built-in support for returning a streaming response from Flask, using the `stream_with_context()` helper. This is a generator function that yields data to the client as it becomes available.

You can pull down the Python template using `faas-cli template store pull python3-flask-debian`, then create a new function with: `faas-cli new --lang python3-flask-debian stream-l`.

We're using the `debian` variant instead of the normal, smaller alpine variant of the image because it contains everything required to build the dependencies we'll need. On balance, the Debian image is still smaller than the Alpine one when all the build tools have been added in.

To learn more about the Python template, [see the docs](https://docs.openfaas.com/languages/python/).

Example `handler.py`:

```python
from flask import stream_with_context, request,Response
import requests

from langchain_community.chat_models import ChatOpenAI
from os import environ

environ["OPENAI_API_KEY"] = "Bearer foo"

chat_model = ChatOpenAI(
    model="gpt-3.5-turbo",
    openai_api_base="https://openai.inlets.dev/v1",
)

def handle(req):
    prompt = "You are a helpful AI assistant, try your best to help, respond with truthful answers, but if you don't know the correct answer, just say sorry I can't help. Answer this question: {}".format(req)

    print("Prompt: {}".format(prompt))

    def stream():
        for chunk in chat_model.stream(prompt):
            print(chunk.content+"\n", flush=True, end="")
            yield f'data: {chunk.content}\n\n'

    return Response(stream(), mimetype='text/event-stream')
```

Example `requests.txt`:

```bash
requests
langchain_community
openai
```

Next, in your stack.yaml file, set `buffer_body: true` under the `environment:` section. This reads all of the request input into memory, then sends it to the function, so there's no streaming input, just a streaming output.

I set up a self-hosted API endpoint that is compatible with OpenAI for this testing, but you can use the official API endpoint too. Just make sure you pass in your OpenAI token using an OpenFaaS secret and not an environment variable. Definitely don't hard-code it into your function's source code because it will be readable by anyone with the image.

```bash
curl -i http://127.0.0.1:31112/function/stream-l \
    -H "Content-Type: text/plain" \
    -H "Accept: text/event-stream" \
    -d "What are some calorie dense foods?"
```

Example output:

```
HTTP/1.1 200 OK
Content-Type: text/event-stream; charset=utf-8
Date: Thu, 11 Jan 2024 13:33:04 GMT
Server: waitress
Transfer-Encoding: chunked

data:  Some
data:  cal
data: orie
data:  dense
data:  food
data: s
data:  include
data:  n
data: uts
data: ,
data:  se
data: eds
data: ,
data:  av
data: oc
data: ados
data: ,
data:  che
data: ese   
data: ,
data:  pe
data: an
data: ut
data: ut
data:  but
data: ter
data: ,
data:  dark
data:  ch
data: oc
data: olate
...
```

I trimmed the response, but you get the idea. This gave me text quite quickly, but if we'd had to wait for the full text it would have taken up to 30 seconds.

As a quick note, you'll need to [pay attention to your timeout values](https://docs.openfaas.com/tutorials/expanded-timeouts/) as the default timeouts for your function and installation may not be enough to stream a complete response from the remote API.

The prompt could probably do with some tuning, just edit handler.py and let me know what you come up with.

I used [c0sogi/llama-api](https://github.com/c0sogi/llama-api) to set up a local OpenAI REST API endpoint using a free model. The answers are not the same caliber as gpt-3.5, however it is a good way to test the SSE functionality.

You can learn more about the [official OpenAI Python SDK here](https://github.com/openai/openai-python)

## Wrapping up

In a short period of time, we were able to add support to the various OpenFaaS components and Python template in order to support SSE for OpenAI. You could also use a generator to stream back your own data to a client, just remember that the response is text-based. So to stream back binary data like an image, you'd need to base64 encode each chunk.

From here, you can now consume the streaming function in a front-end built with React, Vue.js, or Nuxt.js, etc, or from a CLI application.

If you'd like to learn more about OpenFaaS, we have a weekly call every Wednesday and we'd love to see you there to hear how you're using functions.

* [OpenFaaS weekly community call](https://docs.openfaas.com/community/)
