---
title: "How to Integrate WebSockets with Serverless Functions and OpenFaaS"
description: "We show you how to deploy an existing WebSocket server as a function, and how to modify an existing template to support WebSockets."
date: 2025-02-27
author_staff_member: alex
categories:
- websockets
- sse
- ai
- agents
- streaming
dark_background: true
image: /images/2025-02-ws/background.png
hide_header_image: true
---

We show you how to deploy an existing WebSocket server as a function, and how to modify an existing template to support WebSockets.

We'll also cover:

* How OpenFaaS can support WebSockets natively, when cloud-based solutions do not
* Auto-scaling for WebSockets
* A singleton approach for maintaining state for AI agents and chat applications
* Extended timeouts to support long-lived WebSockets
* Server Sent Events (SSE) as an alternative to WebSockets

When we talk about serverless functions, that typically means a short-lived, stateless piece of code that is triggered by an event. WebSockets take a different approach, and need to run for an extended period of time, and maintain a stateful connection to the client. Cloud-based functions offerings like AWS Lambda and Google Cloud Run tend to have very short timeouts, and make it difficult to maintain state. This is where a framework like OpenFaaS, which is built to run with containers, on infrastructure that you control, comes into its own.

[WebSockets](https://en.wikipedia.org/wiki/WebSocket) offer bidirectional streaming, which makes them ideal for chat interfaces, notifications, LLM agents, and other cases where you need to push data to the client.

WebSocket servers need to handle the various events that occur during a connection: *open*, *message*, *close*, and *error*. They also support broadcasting messages to all of the currently connected clients, or sending messages to a specific client.

An alternative to WebSockets is [Server Sent Events (SSE)](https://en.wikipedia.org/wiki/Server-sent_events), which is a server push technology. It's what you use when you work with the [OpenAI](https://platform.openai.com/docs/overview) or [Ollama](https://github.com/ollama/ollama/blob/main/docs/api.md) REST APIs. An initial connection is made to the server, the client sends its request and then the server streams the response back to the client. This is a simpler approach, and is easier to implement in a serverless environment, and we added support for this in OpenFaaS in January 2024: [Stream OpenAI responses from functions using Server Sent Events](/blog/openai-streaming-responses/).

Server Sent Events fit the serverless paradigm well, and allow for many of the same use cases as WebSockets, so we'd recommend them as a first port of call.

That said, WebSockets now be used with [OpenFaaS Standard/Enterprise](https://openfaas.com/pricing/) and the [OpenFaaS Edge (faasd-pro)](https://docs.openfaas.com/deployment/edge/). We'll take a look at how in this post.

## Two options for WebSocket support in a function

There are two options for WebSocket support in a function: modify an existing template to handle WebSocket events such as *open*, *message*, *close*, and *error*, or package a HTTP server in a Dockerfile.

Option 1 is to pick one of the existing templates and to adapt its entrypoint and handler to handle WebSockets in the way you want.

Whilst we did add SSE support to our official templates, we did not do the same for WebSockets, because one size does not fit all.

Option 2 is that you can write your code in exactly the same way you would, any other application in your preferred language, with your preferred frameworks. You then package it into a container image using Docker, and deploy it via faas-cli, as if it were a function.

For Go, that's likely going to be [gorilla/websocket](https://github.com/gorilla/websocket), for Python that might be [Flask-SocketIO](https://flask-socketio.readthedocs.io/en/latest/), and for Node.js it's probably [ws](https://github.com/websockets/ws).

In order to deploy your code as a function, you'll just need to make sure its HTTP server binds to port 8080, and implements a health `/_/health` and a readiness `/_/ready` handler. It's OK if you only return a 200 from these endpoints whilst you're getting started. You'll also need to write a Dockerfile that builds and packages your application and then you can build/deploy it via the OpenFaaS CLI.

To test out the WebSocket support for existing applications, I tried packaging the server component of our [inlets](https://inlets.dev) product as a function. Inlets is used to expose HTTP or TCP services to the Internet over a WebSocket. I was able to deploy its container image via `faas-cli` and then connected a regular inlets-pro client to the function and accessed the exposed service.

So how do you decide which option to use?

The purpose of templates in OpenFaaS is to remove duplication and boilerplate between functions. For each new function, you pull down your custom template, and scaffold only the handler, and a way to provide dependencies.

If you end up feeling like the template approach doesn't fit your specific use case, then you can always package an application as a function with a Dockerfile.

## Option 1: Modify an existing template for WebSockets

I spent some time modifying the underlying index.js file to include similar code to our first example.

The changes the user will see involve the `handler.js` file, where we now export a `wsHandler` function, in addition to the existing `handler` function.

```js
module.exports = {
  handler,
  wsHandler
};
```

This allows the index.js to send normal HTTP REST requests to one handler, and the WebSocket connections/events to another.

```js
'use strict'

// handler handles a single HTTP request
const handler = async (event, context) => {
  const result = {
    'body': JSON.stringify(event.body),
    'content-type': event.headers["content-type"]
  }

  return context
    .status(200)
    .succeed(result)
}

// WebSocketHandler responds to events from all connected
// WebSocket connections
class WebSocketHandler {
  constructor(server) {
    this.server = server;
  }

  init(server) {
    this.server = server;
  }

  handleConnection(ws, request) {
    console.log('[wsHandler] Client connected');
  }

  handleMessage(message) {
    console.log('[wsHandler] Received:', message.toString());
  }

  handleClose() {
    console.log('[wsHandler] Client disconnected');
  }

  handleError(error) {
    console.error('[wsHandler] error:', error);
  }
}

const wsHandler = new WebSocketHandler();

module.exports = {
  handler,
  wsHandler,
}
```

The WebSocketHandler class will handle the various events from the WebSocket connection.

Here's how you could respond to a message from a client:

```js
handleMessage(message) {
  this.server.clients.forEach(client => {
    if (client.readyState === ws.OPEN) {
      client.send(message.toString());
    }
  };
}
```

To use this template, you'll need to pull down the template from my sample repository on GitHub:

```bash
faas-cli template pull https://github.com/alexellis/node20-ws

faas-cli new --lang node20-ws ws1
```

Then you can edit the `handler.js` file to add your custom logic.

If the style doesn't fit your needs, but you are sure that WebSockets are the right approach, then you can [fork the repository](https://github.com/alexellis/node20-ws) and modify the template to your needs.

## Option 2: Package existing code as a function with a Dockerfile

This example follows the first approach, which uses JavaScript/Node along with the express.js HTTP framework. WebSocket support is then added via the [ws](https://github.com/websockets/ws) library.

```bash
mkdir -p ws/

faas-cli new --lang dockerfile fn1

cd ws/fn1
npm init -y
npm install express ws
```

Delete the contents of the `./fn1/Dockerfile` file, and replace it with the following:

```dockerfile
FROM --platform=${TARGETPLATFORM:-linux/amd64} node:20-alpine AS ship

ARG TARGETPLATFORM
ARG BUILDPLATFORM

RUN apk --no-cache add curl ca-certificates \
    && addgroup -S app && adduser -S -g app app

# Turn down the verbosity to default level.
ENV NPM_CONFIG_LOGLEVEL warn

RUN chmod 777 /tmp

USER app

RUN mkdir -p /home/app

# Entrypoint
WORKDIR /home/app
COPY --chown=app:app package.json ./

RUN npm i

COPY --chown=app:app . .

# Run any tests that may be available
RUN npm test

# Set correct permissions to use non root user
WORKDIR /home/app/

CMD ["node /home/app/index.js"]
```

Create an index.js file:

```js
const express = require('express')
const app = express()
const ws = require('ws');

const okHandler = (req, res) => {
  res.status(200).send()
};

app.use("/_/health", okHandler);
app.use("/_/ready", okHandler);

const wsServer = new ws.Server({ noServer: true });

wsServer.on('connection', function connection(ws) {
  ws.on('error', error => {
    console.error('WebSocket error:', error);
  })

  ws.on('message', function incoming(message) {
    console.log('received: %s', message);
    ws.send(`echo ${message}`);
  });

});

const server = app.listen(8080);

server.on('upgrade', function upgrade(request, socket, head) {
  wsServer.handleUpgrade(request, socket, head, function done(ws) {
    wsServer.emit('connection', ws, request);
  });
});
```

Now deploy the function to OpenFaaS:

```bash
faas-cli up -f fn1.yml --tag=digest
```

You should really update the image tag inside of `stack.yaml` every time you change it i.e. `0.0.1` to `0.2.0` and so forth. For convenience, the `--tag=digest` flag will generate a new tag based upon the contents of the handler folder, and saves some typing during development.

You can now connect your WebSocket client to the `fn1` function using the gateway's URL:

When using TLS:

```
wss://openfaas.example.com/function/fn1
```

When using plain HTTP, i.e. on 127.0.0.1:

```
ws://127.0.0.1:8080/function/fn1
```

The following client can be used to test the function:

```js
const ws = require('ws');
const client = new ws('ws://127.0.0.1:8080/function/fn1');
client.on('open', () => {

    client.on('message', (data) => {
      console.log(`Got message ${data.toString()}`);
    });

    client.on('close', () => {
      console.log('Connection closed');
    });

    let n = 0;
    
    let i = setInterval(() => {
        console.log('Sending message');
        client.send(`Hello ${n++}`);
    }, 1000);

    setTimeout(() => {
        clearInterval(i);
        client.close();
    }, 10000);
});
```

## Timeouts for WebSockets

The default timeout for a function and the installation of OpenFaaS can be extended to very long periods of time. Whilst there is no specific limit, we'd encourage you to try to right-size the timeout to your typical needs, so that might mean setting it to 1 hour, instead of 24 hours. Browser-based clients can also be configured to reconnect.

If you're using your own code, then you just need to configure the Helm chart with a longer timeout.

If you're using one of our templates, with the of-watchdog, then you'll also need to timeouts for the function via environment variables.

You can learn more in the docs: [Extended timeouts](https://docs.openfaas.com/tutorials/expanded-timeouts/)

## Scaling WebSockets

Functions which expose WebSockets can be scaled horizontally by adding in extra replicas, or scaled to zero if there are no connections.

You can also force a function to act like a singleton, if you want to make sure it has the same state between multiple connections. If you were implementing a chat application or an AI agent, you may want to have one individual function deployment per customer, to maintain state. Idle replicas can be scaled to zero to save on resources.

The best scaling mechanism for WebSockets is the `capacity` type which works on the amount of TCP connections running against all the replicas of a function.

```yaml
functions:
  fn1:
    labels:
      com.openfaas.scale.min: 1
      com.openfaas.scale.max: 10
      com.openfaas.scale.type: capacity
      com.openfaas.scale.target: 10
```

The above rules will create a function with a minimum of 1 replica, a maximum of 10 replicas, and a target of 10 connections per replica.

The value of `com.openfaas.scale.target` is a target number, replicas may end up with slightly more or less than this

For hard-concurrency limits use the `max_inflight` environment variable, and make sure your code uses the OpenFaaS of-watchdog, which implements the limiting.

```yaml
functions:
  fn1:
    environment:
      max_inflight: 10
```

When using `max_inflight`, replicas of a function with at least 10 ongoing connections will be taken out of the load balancer's pool, and if they do receive a request will respond with a 429 "Too many requests" error. If you use this option, configure your client to retry requests until it can connect successfully.

If you want to create a singleton, you can override scaling to that there is only ever one replica of the function.

```yaml
functions:
  fn1:
    labels:
      com.openfaas.scale.min: 1
      com.openfaas.scale.max: 1
```

Scale to zero is also supported with WebSockets:

```yaml
functions:
  fn1:
    labels:
      com.openfaas.scale.zero: true
      com.openfaas.scale.zero-duration: 15m
```

The above will scale any functions to zero if they haven't had a new connection established within the last 15 minutes.

Learn more:

* [Autoscaling functions](https://docs.openfaas.com/architecture/autoscaling/)
* [Scale to zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/)

## Conclusion

We covered two approaches for integrating with WebSockets. In the first approach, we created a new template called `node20-ws` based upon an existing one. We added support for the Node.js ws library through functions in the handler for the lifecycle events of a WebSocket connection. That custom template could be shared with your team very easily by pushing it to a public or private git repository. In the second example, we packaged existing code as a function with a Dockerfile, which gave us more flexibility, but at the cost of having duplication between each function.

In both cases, a standard client was used to connect to the function, and messages were echoed back and forth between the client and the function.

We then touched on how to scale WebSockets, and how to configure timeouts for functions.

But why isn't there "WebSocket support" in every official OpenFaaS template?

1. Server Sent Events (SSE) is a simpler, and more compatible, approach to streaming data to the client.
2. WebSockets are complex, and used in many different ways, we couldn't build a template that suited every developer's needs.
3. We'd rather have a small number of templates that are well-supported, and have a near-perfect developer experience.

We instead have provided a starting point where you can write your applications as if they were just being deployed through Docker, and an example of how to modify the template to support WebSockets.

If you'd like to try out websockets in OpenFaaS, feel free to [get in touch](https://forms.gle/g6oKLTG29mDTSk5k9) or join our [Weekly Community Call](https://docs.openfaas.com/community) to see a live demo.
