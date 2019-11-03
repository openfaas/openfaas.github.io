---
title: "Build data-driven GitHub Badges with Node.js and OpenFaaS Cloud"
description: Learn how you can write your own data-driven GitHub badges for your projects and codebases on GitHub using Node.js and OpenFaaS Cloud
date: 2019-11-03
image: /images/2019-github-badges/blue-sky-flowers.jpg
categories:
  - github
  - golang
  - go
author_staff_member: alex
dark_background: true

---
Learn how you can write your own data-driven GitHub badges for your projects and codebases on GitHub using Node.js and [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud)

I'll show you how I built my own data-driven GitHub badge with Node.js and OpenFaaS Cloud, at the end of the post you'll find some ways you can engage and try it out for yourself. I'll also mention several real-world case-studies where others are already making use of OpenFaaS Cloud to innovate and solve problems.

## What's a GitHub badge?

GitHub badges are graphics that you can add to your README.md to bubble up key information. Not all GitHub badges are created equal, but most big projects make use of them and in the OpenFaaS community we are big fans.

Examples of data you can show includes:

* Status of CI - i.e. passing/failing (popularised by [Travis CI](https://travis-ci.org))
* License - MIT/Apache 2/GPL etc
* Where the code is deployed - i.e. Azure/Heroku/OpenFaaS Cloud
* What language the code is written in - Go/Node etc

Here's an example from the [openfaas/faas](https://github.com/openfaas/faas) GitHub repo showing a range of badges:

![GitHub badges](https://pbs.twimg.com/media/EIc4Y5LWkAI1Pnd?format=jpg&name=medium)

Since OpenFaaS is written in Golang, we include a number of other interesting badges, like the generated Go documentation and a "go report" which has given us an A+ on quality. Each link can also navigate to a webpage where you can find out more.

## How do badges work?

My [inlets](https://inlets.dev) project also includes downloads statistics from the GitHub releases API. Inlets is an open-source replacement for Ngrok, or Cloudflare Argo, but without any limitations and a deep integration into Kubernetes.

![](https://pbs.twimg.com/media/EIdC6odWkAE1J9C?format=jpg&name=medium)

How does this specific badge work? It's hard to say exactly, because the badge is provided by a third-party called [shields.io](https://shields.io). I would imagine that some server-side or client-side code polls the [GitHub API for downloads](https://developer.github.com/v3/repos/downloads/).

Static badges can be formed very simply and are a good way of indicating some kind of status or affiliation. The [OpenFaaS Cloud](https://github.com/openfaas/openfaas-cloud) dashboard offers that kind of badge:

![Static badge](https://docs.openfaas.com/images/openfaas-cloud/welcome-12.png)

To create a static badge simply write the following:

```md
[![OpenFaaS](https://img.shields.io/badge/openfaas-cloud-blue.svg)](https://www.openfaas.com)
```

Whatever text you enter in the URL will be read by `shields.io` to generate data.

## Use-case: How do I make my own?

You can pick one of the pre-made examples from [shields.io](https://shields.io/), and that may cover your needs, but when you need more, you can build an endpoint to return your own.

I decided to build a badge that would show how many features a GitHub repo is using from a bot I maintain called Derek. Derek is modular and comes with around a dozen commands and features to help companies manage community and GitHub.

Here's a summary of what Derek can do once installed on your GitHub repo or organisation:

* `dco_check` - check if commits are signed-off with the Developer Certificate of Origin
* `comments` - delegate permissions to manage Issues and PRs to normal users who are not administrators in your GitHub org
* `pr_description_required` - inform users that they need to fill in a PR description, when they fail to do so
* `hacktoberfest` - close spam PRs and inform users how to contribute constructively
*  `release_notes` - scan merged PRs since the last release and update the release notes automatically

Derek's configuration file sits at the top level of any enabled GitHub repo just like a `.travis.yml` or other configuration file.

Here's an example configuration file for Derek:

```yaml
maintainers:
 - alexellis
 - rgee0
 - martindekov

features:
 - dco_check
 - comments
 - pr_description_required
 - hacktoberfest
 - release_notes
```

I wanted to create a badge which would count how many features a repo is using and then show that as a badge. You may have your own data and config files you can read and report back on.

## How I built the code

I started off by building my function for OpenFaaS Cloud on [The Community Cluster](https://github.com/openfaas/community-cluster/), which provides free TLS-enabled URLs which are public. All you do is put code into a GitHub repo and the rest is automated.

* Create a new GitHub repo and enable OpenFaaS Cloud

    I created a GitHub repo [alexellis/derek-fn](https://github.com/alexellis/derek-fn), which was public, but private repos work too.

    I then added the OpenFaaS Cloud integration, if you don't have access click the link for the Community Cluster above

* Create a new function

    I wanted to write my code with a Node.js template with a similar style to AWS Lambda, so I picked the `node10-express` template. Other templates are listed via `faas-cli template store list`.

    ```
    faas-cli template store pull node10-express

    # This generated my badge/handler.js and badge/handler.json files
    faas-cli new --lang node10-express badge

    # The YAML file must be called stack.yml
    mv badge.yml stack.yml
    ```

* Add the dependencies

    I knew I wanted to parse Derek's YAML file, make HTTP requests and parse query strings, so I added this to `handler.js`
    ```js
    const axios = require("axios")
    const YAML = require('yaml')
    const querystring = require('querystring');
    ```

    I then ran `npm install --save axios yaml` inside the `badge` folder, which updated `package.json` for me.

* Next I wrote the code

    I had to pull the `.DEREK.yml` file from GitHub's CDN using the *raw* URL and not the HTML URL, this could be calculated easily from the URL passed in via the querystring.

    After parsing the code I then made a request to the server using `axios` to `GET` the text file and parse it using the `yaml` npm module.

    I started by writing a function called `get` which would download Derek's YAML file, parse it and return the result.


    ```js
    function get(uri) {
        return new Promise((resolve, reject) => {
            console.log("get",uri)

            axios.get(uri)
            .then(function (response) {

                if(response.status == 200) {
                    let doc = YAML.parse(response.data)
                    if(doc.redirect) {
                        return resolve({"redirect": doc.redirect})
                    }

                    return resolve({"numFeatures": doc.features.length});
                }

                return reject("error")
            }).catch(e => {
                reject(e);
            })
        });
    }
    ```

    Sometimes users have many GitHub repos so they use one central Derek config and a redirection file in every other repo. OpenFaaS does that for instance. The `openfaas/faas-cli` repo simply points to the `openfaas/faas` repo because they share the same configuration for Derek.

    ```yaml
    redirect: https://raw.githubusercontent.com/openfaas/faas/master/.DEREK.yml
    ```
    
    I wrote some additional code in my handler that calls `get` an additional time if required, which means we can follow at most one redirect. This could be made recursive, but I haven't seen anyone use Derek redirect files that way yet.

    Here's the main handler:

    ```js
    module.exports = (event, context) => {
        if(event.query) {

            let repo = event.query.repo;
            let owner = event.query.owner;

            if (!repo || !owner) {
                return context.fail(`Give a repo and owner in the querystring.`);
            }

            let uri = `https://raw.githubusercontent.com/${owner}/${repo}/master/.DEREK.yml`

            get(uri)
            .then(res => {
                if(res.redirect) {
                    get(res.redirect)
                    .then(res => {
                        return context
                            .status(307)
                            .headers({"Location": `https://img.shields.io/badge/Derek::Features-${res.numFeatures}-blue`})
                            .succeed()
                    }).catch(e => {
                        return context.fail(e.toString());
                    });
                } else {
                    return context
                        .status(307)
                        .headers({"Location": `https://img.shields.io/badge/Derek::Features-${res.numFeatures}-blue`})
                        .succeed()
                }
            }).catch(e => {
                return context.fail(e.toString());
            });
        } else {
            return context
                .status(307)
                .headers({"Location": `https://img.shields.io/badge/derek-errored.svg`})
                .succeed()
        }
    }
    ```

Each time I want to change the code I simply type in the following and wait a few seconds.

```sh
git add .
git commit
git push origin master
```

And a new version of my code appears with its URL and detailed statistics:

![](https://docs.openfaas.com/images/openfaas-cloud/welcome-10.png)

If anything went wrong, GitHub provides me with GitHub statuses and error messages:

![](https://docs.openfaas.com/images/openfaas-cloud/welcome-06.png)

## How about testing?

To test the code I wrote a "stub" that I could use to invoke the code. There's nothing stopping us going deeper here and using `chai` and `mocha` (common testing tools for Node.js) to write a full test suite against a fake or mock HTTP server.

Since I was short on time I wrote a quick `tester.js` file that I could run in the terminal:

```js
"use strict"

let t = require("./handler.js")

// let owner="alexellis"
// let repo="derek"

let owner="openfaas"
let repo="faas"

t({query:{"repo":repo,"owner":owner}},
{
    status:function(s){
        console.log("status",s)
        return this;
    },
    headers:function(s){
        console.log("headers",s)
        return this;
    },
    fail:function(s){
        console.log("fail",s)
        return this;
    },
    succeed:function(s){
        console.log("succeed",s)
        return this;
    }
})
```

After proving that a repo with a redirect worked and a repo with a top-level Derek file worked, I made a commit and pushed my code up into OpenFaaS Cloud.

## See it in action

Try it out for yourself by viewing these GitHub repos:

* [Inlets README](https://github.com/inlets/inlets/)
* [OpenFaaS README](https://github.com/openfaas/faas)
* [Derek README](https://github.com/alexellis/derek) - yes Derek is even using the badge

## What else can you do?

Now that you have a worked-example, you can go on to customise the code and build your own GitHub badge. There's also nothing stopping you from generating images dynamically which you can embed in your README file without using shields.io at all.

I often have the need to embed a YouTube video in a newsletter, but I can never remember the secret URL to get a thumbnail from the video, which YouTube.com provides. What about writing a function that would look up the YouTube URL and then redirect? That is something you could probably write in 15 minutes and then host for free on The Community Cluster. You'd have a public URL with TLS and full CI/CD all for free.

Rajat Jindal from Proofpoint has written two bots which he hosts on The Community Cluster:

* [Good First Issue Bot](https://www.openfaas.com/blog/good-first-issue/) - helping new contributors to find issues on repos from Google, Microsoft, Jetstack, and many more
* [translatethread.com](https://translatethread.com) - a Twitter bot which translates entire threads using an OpenFaaS function and then commits the generated HTML into a repository for Netlify to deploy.

Tarun Mangukiya from [Iconscout](https://iconscout.com) made a version of his image resize available on The Community Cluster for free use too:

* [How to resize your images on-the-fly with OpenFaaS](https://www.openfaas.com/blog/resize-images-on-the-fly/)

OpenFaaS Official functions:

* [Bot to thank new Patreon backers](https://github.com/openfaas/backer-thankyou/)

* [HTTPS short-URLs](https://github.com/openfaas/cloud-functions/blob/master/stack.yml) - we built a number of short/pretty-URLs for the community to use for joining Slack, Zoom calls and for [becoming an OpenFaaS Insider](https://insiders.openfaas.io/)

The cloud company Civo.com has an OpenFaaS function on The Community Cluster which filters Twitter mentions and then forwards them onto their Slack community so that the team can engage better with their own community:

* [Civo Twitter Filter](https://github.com/civo/openfaas-functions)

This is just scratching the surface of what can be done. OpenFaaS can provide a quick and easy way for you to host anything including microservices, integrations, APIs, or even static sites.


Get started today

* Apply for [access to The Community Cluster](https://github.com/openfaas/community-cluster/)
* [Deploy OpenFaaS on Kubernetes](https://docs.openfaas.com/deployment/kubernetes/)

### Join the community

The OpenFaaS community values are: developers-first, operational simplicity, and community-centric.

If you have comments, questions or suggestions or would like to join the community, then please [join us on OpenFaaS Slack](https://docs.openfaas.com/community/).

You can [follow me @alexellisuk](https://twitter.com/alexellisuk/) and [@openfaas on Twitter](https://twitter.com/openfaas/)

### You may also like:

* [Migrate Your AWS Lambda Functions to Kubernetes with OpenFaaS](https://www.openfaas.com/blog/lambda-to-openfaas/)
* [Build your own OpenFaaS Cloud with AWS EKS](https://www.openfaas.com/blog/eks-openfaas-cloud-build-guide/)
