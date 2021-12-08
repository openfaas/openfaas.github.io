---
title: "Gain access to your functions with CORS"
description: This post will show you how to gain access to your functions from a known endpoint through the use of CORS headers.
date: 2020-04-08
image: /images/2020-function-cors/light-45072.jpg
categories:
  - microservices
  - kubernetes
  - serverless
  - security
author_staff_member: alex
dark_background: true

---

In this post I'll show you how to gain access to your functions from a known endpoint through the use of CORS headers.

The first time most people come across Cross-origin resource sharing or CORS, is through an angry red message in the console of their browser.

![CORS error](/images/2020-function-cors/cors-error.png)

This error usually occurs when you try to access an API or service on a different domain to the one you're serving your webpage from. The browser generate this error when the call it makes didn't have a valid CORS header to allow the request.

[Wikipedia defines CORS](https://en.wikipedia.org/wiki/Cross-origin_resource_sharing) as:

> Cross-origin resource sharing (CORS) is a mechanism that allows restricted resources on a web page to be requested from another domain outside the domain from which the first resource was served.

> A web page may freely embed cross-origin images, stylesheets, scripts, iframes, and videos. Certain "cross-domain" requests, notably Ajax requests, are forbidden by default by the same-origin security policy. CORS defines a way in which a browser and server can interact to determine whether it is safe to allow the cross-origin request. It allows for more freedom and functionality than purely same-origin requests, but is more secure than simply allowing all cross-origin requests.

Paraphrased: CORS is the gatekeeper which decides if a request gets to be served from a certain origin or not and the good news is that there's a workaround that means you can use your functions with your other APIs, websites and static pages.

## An example function

For New Year's eve I wrote a tiny JavaScript function using the node12 template which prints out some ASCII for people to share their New Year message.

Now the message has turned from good wishes to "Stay at home", and so if I wanted to invoke the function it'd look a bit like this:

```
curl https://alexellis.o6s.io/ascii-2020?q=stayathome
```

![Invoking the function](/images/2020-function-cors/invoke.png)

Whilst I am sure that you have more productive applications than my ascii-2020 example, I wanted to show you a simple example so that you can go on and benefit from this technique for your own functions.

> At the end of the post I'll share a link to a static React.js website created with `create-react-app` that reads a JSON API rendered from a Postgresql query.

## An example webpage

Now let's imagine we have a webpage that should invoke the function from another domain and then display the result.

This webpage could be static and then use some APIs to render its data, a technique which as been popularised by the creation of the ["JAM Stack"](https://jamstack.org) - JavaScript APIs and Markup. Once built, sites can be hosted at a relatively low cost, or absolutely from a CDN or global storage such as [Netlify](https://netlify.com), [GitHub pages](https://github.com/), or an S3 bucket.

Create a new folder for the example webpage:

```
mkdir -p ~/cors-example/

touch ~/cors-example/index.html
```

Create `index.html` in your home directory:

```html
<html>
<head>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.4.1/jquery.min.js"></script>
<script>
  var uri = "https://alexellis.o6s.io/ascii-2020?q=stayathome";

  $.get(uri, function( data ) {
    $( ".result" ).html( data );
    console.log("Content loaded.");
  });

</script>
</head>

<body>
  <h3>CORS example</h3>
  <div class="result">

  </div>
</body>
</html>
```

The webpage uses a simple jQuery call of `$.get()` to instruct the browser to fetch the contents.

Now run a temporary HTTP server, if you have Python installed run:

```bash
cd ~/cors-example/
python -m SimpleHTTPServer
```

Now view your static website at [http://127.0.0.1:8000/](http://127.0.0.1:8000/)

Unfortunately you'll run into this error, and maybe it's already familiar. It may be why you're reading this page now.

![CORS error](/images/2020-function-cors/cors-error.png)

## How do we fix it?

There is a simple solution to "fixing" the CORS error with a HTTP header returned from the function.

Before going ahead and making changes, you should first consider whether opening your API to calls from browsers on other domains is a good idea and absolutely necessary. If both domains are within your control you could move the functions into the other domain for instance and not have to get involved with CORS at all.

In Node.js the change I was made as simple as the following:

```js
"use strict"
const wordwrap = require('wordwrap')

module.exports = async (event, context) => {
    let wrapped = wordwrap
        .soft(17)(event.query['q'].toUpperCase())

    let result = `┏━━┓┏━━┓┏━━┓┏━━┓
┗━┓┃┃┏┓┃┗━┓┃┃┏┓┃
┏━┛┃┃┃┃┃┏━┛┃┃┃┃┃
 ${wrapped}
┃┏━┛┃┃┃┃┃┏━┛┃┃┃┃
┃┗━┓┃┗┛┃┃┗━┓┃┗┛┃
┗━━┛┗━━┛┗━━┛┗━━┛
`

  return context
    .headers(
        {
          'Content-type': 'text/plain',
          "Access-Control-Allow-Origin": "http://127.0.0.1:8000"
        }
    )
    .status(200)
    .succeed(result)
}
```

Can you see what I changed?

A HTTP header of `"Access-Control-Allow-Origin"` was added. You should make the value as specific as possible, so if you are calling a function from `https://host.example.com/customers/`, put that instead of `https://host.example.com` to limit the scope as much as possible.

Now I'll try to load our custom webpage again:

![CORS error](/images/2020-function-cors/cors-working.png)

## Wrapping up

### Templates compatible with CORS

There are various openfaas templates which support setting HTTP headers, these tend to be newer and use the [of-watchdog](https://github.com/openfaas-incubator/of-watchdog) component. The older classic templates do not support this feature, so you may want to upgrade and move off them if CORS is required.

Some of the most popular HTTP-based templates (with of-watchdog) include:

* node12
* golang-http
* golang-middleware
* java11-vertx
* python3-flask-http
* csharp-httprequest
* ruby-http

Run `faas-cli template store list` for a complete list of community templates.

If you don't find what you're looking for, you can build your own templates, or use a Dockerfile and an existing HTTP server.

### What should I do with this?

Well you can now create a static webpage with create-react-app, or the JAM Stack and add dynamic data to it via functions hosted on your own OpenFaaS cluster, or [on the free Community Cluster](https://github.com/openfaas/community-cluster).

As a further example I built out a [React.js](https://reactjs.org) with the `create-react-app` utility to render data from a JSON API we built to track non-code contributions via GitHub issues and issue comments.

* Find the code example at [alexellis/alexellis.github.io](https://github.com/alexellis/alexellis.github.io)

* It's deployed at: [https://alexellis.github.io/docs/](https://alexellis.github.io/docs/) and looks like this:

![React leaderboard example](/images/2020-function-cors/leaderboard.png)

### You're not on your own!

Finally, if you do run into technical issues with OpenFaaS and you need support, do feel free to join the Slack community and ask away. I recently heard from one user who abandoned his OpenFaaS project after assuming that the project couldn't support CORS functionality. His story is part of the driving force for putting this tutorial together.

> We're here to help you, and if you need more than can be offered by the community, [OpenFaaS Ltd](mailto:sales@openfaas.com) offers reassurance and consulting services.

### Connect with the community

* Get a head-start with OpenFaaS with our [Official Workshop](https://github.com/openfaas/workshop).

Do you have questions, comments or suggestions? Tweet to [@openfaas](https://twitter.com/openfaas).

> Want to support our work? You can become a sponsor as an individual or a business via GitHub Sponsors with tiers to suit every budget and benefits for you in return. [Check out our GitHub Sponsors Page](https://github.com/sponsors/openfaas/)
