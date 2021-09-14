---
title: "Serverless storage for your functions from the Datastax Astra DB"
description: "Learn how Astra DB provides convenient Pay As You Go storage for serverless functions."
date: 2021-08-26
image: /images/2021-08-astra/background.jpg
categories:
 - apis
 - database
 - functions
 - dbaas
 - sponsored
author_staff_member: alex
dark_background: true

---

If you need storage based upon open source technology that can scale as you do, I think Cassandra and Astra DB could be a good fit. It also makes for a great option for free storage for side projects, which you can push quite hard before you get through your recurring credit.

I'll start off by talking you through Cassandra, then about the Datastax Kubernetes Operator called K8ssandra and its "data API gateway" which provides a REST and GraphQL API for any collections you create. Then I'll show you how to access storage from your functions using Node.js, the standard Cassandra driver and then the Astra DB Document API.

## What is Cassandra?

[Apache Cassandra](https://www.datastax.com/cassandra?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas) is billed as "a highly available, partitioned, replicated, open source distributed database." So we're not talking about something you can run on a 5 USD VPS here, this is a serious piece of software that is designed to be used in production and at scale.

From a developer's point of view, Cassandra has some similarities with MySQL and Postgresql in that it is primarily driven by a schema and uses a familiar SQL-like language for querying and inserting data. The main differences lie in how it is operated and how it scales.

If you'd like to install Cassandra locally or in a cluster, Datastax provides their own distribution which is aptly named [K8ssandra](https://k8ssandra.io/?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas). The K8ssandra bundle contains the open source Cassandra component, plus a number of other components that are useful for running a production system. I found the documentation to be clear and concise, it even has instructions for running with [KinD](https://kind.sigs.k8s.io/).

![K8ssandra docs](/images/2021-08-astra/k8ssandra.jpg)

The only draw-back that I saw was that 8GB of RAM is needed to run the package locally, which is where their Astra database really starts to get interesting. Astra DB is the full K8ssandra package deployed on a cloud of your choice, with a generous free tier.

> Unlike many managed databases, you do not get billed for idle instances and don't require capacity planning for times of peak traffic.

You've heard of API gateways like Kong and AWS' API Gateway, but have you ever heard of a "Data API gateway"? The Datastax [Stargate data API gateway](https://dtsx.io/3m3ZXF5) project is probably the first project of this kind that I've seen so far. For any Cassandra collections you create, it can automatically expose a REST API and GraphQL endpoint. So you then have three ways to interact with the data: REST, GraphQL and the native Cassandra driver.

## Getting started with Astra DB

![Astra DB overview](/images/2021-08-astra/astra-overview.jpg)

> [The high level overview of Astra DB benefits](https://www.datastax.com/products/datastax-astra) vs. self-hosted Cassandra.

Sign up for a free account on the [Astra DB website](https://dtsx.io/2VYD4I4register?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas), then create a new database in the cloud provider and region of your choice. Let's say that you pick *eu-central-1* on AWS, which will deploy Astra DB to the Datastax AWS account, not your own. They manage everything for you, just like any other managed database you may have used.

![Create your database](/images/2021-08-astra/create-db.jpg)

Along with your free account, you also get an additional 25 USD of usage credit (at time of writing) each month to use after that.

![Credit balance](/images/2021-08-astra/balance.jpg)

> "Free tier includes up to 30 million reads, 4.5 million writes and 40GB storage every month (up to $25 credit)
Elastic and *Pay As You Go* for usage over free tier" [Read more](https://www.datastax.com/products/datastax-astra/pricing?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas)

## Trying the Cassandra driver

Here's an example of what we'll configure first with a basic dataset, and a query using the native Cassandra driver.

![Example function with Cassandra driver](/images/2021-08-astra/function-driver.jpg)

First of all, you'll need to deploy OpenFaaS to a Kubernetes cluster, you can follow [our deployment instructions here](https://docs.openfaas.com/deployment/kubernetes/). You can use a local cluster like [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/) or a managed Kubernetes engine on your favourite cloud.

I was pleasantly surprised to see a console for CQL built into the UI, where you can run queries and create tables. Why is that useful? It means I didn't have to install and configure a CLI on my local computer to test things out.

![CQL console](/images/2021-08-astra/cql.jpg)

The cyclists example is from the [Datastax Enterprise docs](https://docs.datastax.com/en/dse/5.1/cql/examples/cycling/doc/cyclingks.html), insert the following statements into the console:

```sql
// Keyspace creation is done via UI in the case of Astra DB
// (use this command on Cassandra instead)
CREATE KEYSPACE IF NOT EXISTS cycling
WITH replication = {
  'class' : 'SimpleStrategy',
  'replication_factor' : 1
};

DROP TABLE IF EXISTS cycling.cyclist_name;

// Create a table with a simple partition key
// START-simple
CREATE TABLE cycling.cyclist_name (
  id UUID PRIMARY KEY,
  lastname text,
  firstname text
);
// END-simple
```

You can switch keyspace with the `use KEYSPACE;` command such as `use cycling;`

```sql
// Insert a cyclist record record
INSERT INTO cycling.cyclist_name (
  id,
  lastname,
  firstname
) VALUES (
  uuid(),
  'Froome',
  'Chris'
);

INSERT INTO cycling.cyclist_name (
  id,
  lastname,
  firstname
) VALUES (
  uuid(),
  'Ellis',
  'Alex'
);
```

Check the contents of the table with a select statement:

```sql
use cycling;
select * from cyclist_name;

token@cqlsh:cycling> select * from cyclist_name;

 id                                   | firstname | lastname
--------------------------------------+-----------+----------
 9b252280-cf44-11eb-9470-9d93e1b6f866 |   geraint |   thomas
 1c9fadc0-ce7e-11eb-9470-9d93e1b6f866 |     chris |   froome
 1033bf40-ce7e-11eb-9470-9d93e1b6f866 |      alex |    ellis

(3 rows)
```

Feel free to add yourself and any other cyclists you follow.

Next let's create an OpenFaaS function using the node.js template, currently the latest version is called `node14`.

```bash
# Update with your Docker Hub username, or ghcr.io/username
# if using GitHub's container registry
export OPENFAAS_PREFIX="alexellis2"

faas-cli new --lang node14 \
  cycling
```

We'll need three secrets to access Astra DB, the secure connect zip file which contains keys and certificates, a username and a password.

Update the `cycling.yml` file as follows:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  cycling:
    lang: node14
    handler: ./cycling
    image: alexellis2/cycling:0.1.0
    secrets:
    - astra-clientid
    - astra-clientsecret
    - astra-secure-connect
```

Next visit the [Astra DB portal](https://dtsx.io/2VYD4I4register?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas) to create an *Application Token*. Click on "Token Management" then select the role of: *R/W Svc Acct* and *Generate Token*.

![Service account](/images/2021-08-astra/svc-account.jpg)

Save the three values as different files named `astra-clientid`, `astra-clientsecret` and `astra-token` without any file extension.

To download the secure connect bundle click on *Connect* then *Connect using a driver* then *Node.js*, followed by *Download Bundle*.

Rename the file to `astra-secure-connect`, then run the following to create all the secrets in the OpenFaaS environment:

```bash
faas-cli secret create astra-clientid \
--from-file astra-clientid --trim

faas-cli secret create astra-clientsecret \
--from-file astra-clientsecret --trim

faas-cli secret create astra-secure-connect \
--from-file astra-secure-connect
```

> The `astra-secure-connect` secret is a binary file, and whilst writing this blog post I learned that the OpenFaaS CLI and API didn't support binary secrets, so I made the necessary changes. You'll need a recent version of OpenFaaS and faas-cli (0.13.13) or newer.

At this stage, we now have the three required credentials ready for a function to connect to Cassandra using the native driver, which also works with open source Cassandra installations.

Write the following code in the function's handler.js file to query the cyclist names that we entered earlier:

```javascript
"use strict"

const { Client } = require("cassandra-driver");
const fs = require("fs").promises

module.exports = async (event, context) => {
  const clientID = await fs.readFile("/var/openfaas/secrets/astra-clientid", "utf8")
  const clientSecret = await fs.readFile("/var/openfaas/secrets/astra-clientsecret", "utf8")

  const client = new Client({
    cloud: {
      secureConnectBundle: "/var/openfaas/secrets/astra-secure-connect",
    },
    credentials: {
        username: clientID.trim(),
        password: clientSecret.trim(),
    },
  });

  await client.connect();

  // Execute a query
  const result = await client.execute("SELECT * FROM cycling.cyclist_name");

  console.log(`Your cluster returned ${result.rowLength} row(s)`);
  await client.shutdown();

  return context
    .status (200)
    .succeed (result. rows)
}
```

Next make sure that the `cassandra-driver` is in the `package.json` file via:

```bash
cd cycling
npm install --save cassandra-driver
```

Now deploy the function, and invoke it:

```bash
cd ..
faas-cli up -f cycling.yml
```

Once the function is deployed, you can check if it's ready with:

```bash
faas-cli describe -f cycling.yml \
  cycling

Status:              Not Ready
Status:              Ready
```

Then open a browser or invoke it via curl: [http://127.0.0.1:8080/function/cycling](http://127.0.0.1:8080/function/cycling)

```bash
curl -s http://127.0.0.1:8080/function/cycling | jq

[
  {
    "id": "9b252280-cf44-11eb-9470-9d93e1b6f866",
    "firstname": "geraint",
    "lastname": "thomas"
  },
  {
    "id": "1c9fadc0-ce7e-11eb-9470-9d93e1b6f866",
    "firstname": "chris",
    "lastname": "froome"
  },
  {
    "id": "1033bf40-ce7e-11eb-9470-9d93e1b6f866",
    "firstname": "alex",
    "lastname": "ellis"
  }
]
```

The `jq` tool can pretty-print and query JSON.

The Datastax team also recommends [httpie](https://httpie.io) which combines both ideas into one tool. They developed their own plugin for httpie named [httpie-astra](https://pypi.org/project/httpie-astra/), you can use it to send queries directly to Astra DB.

If you would like to insert data, then you can update the query syntax to use the `INSERT` keyword, along with a set of parameters which help mitigate SQL injection attacks.

Batching of queries or commands is also supported, for example:

```javascript
const queries = [
  {
    query: 'UPDATE user_profiles SET email=? WHERE key=?',
    params: [ emailAddress, 'hendrix' ]
  }, {
    query: 'INSERT INTO user_track (key, text, date) VALUES (?, ?, ?)',
    params: [ 'hendrix', 'Changed email', new Date() ]
  }
];

await client.batch(queries, { prepare: true });
console.log('Data updated on cluster');
```

You can find plenty of examples of how to use the driver in the [npm module's documentation](https://docs.datastax.com/en/developer/nodejs-driver/4.6/).

## Using the Astra DB Stargate API

One of the benefits of using Astra DB or the K8ssandra stack, is that Stargate makes a GraphQL and REST API available for any collections you have created at that point. There's also a client library called "collections" that replicates the look and feel of a document database such as MongoDB. The collections wrapper for Astra DB doesn't have all the features of a fully-fledged document database like MongoDB, for instance full text search is not available. Elasticsearch and Solr can be used in tandem with Astra DB for this purpose.

Let's take a look at the collections library: [@astrajs/collections](https://www.npmjs.com/package/@astrajs/collections).

I'll be adapting the quick-start, and because we are now targeting Astra DB instead of Cassandra directly, we'll need slightly different secrets for the connection.

Create a new function called "newsletter", we'll use it to input links that we want to send out to subscribers of our weekly newsletter on tech news.

The HTTP POST method will be used to submit an article, and the HTTP GET method will be used to retrieve the list of articles.

```bash
export OPENFAAS_PREFIX="alexellis"

faas-cli new --lang node14 \
  weekly-newsletter
```

We'll need a mix of confidential and non-confidential configuration information for the function. You already have the Astra DB API token from a previous step saved in the `astra-token` file.

Open a browser, navigate to [DataStax Astra DB](https://dtsx.io/2VYD4I4).

Create a new keyspace called "functions" in the UI, then copy the *Cluster ID* of your database and the *Database region*, these are also available on the *Connect* page.

Now populate the `weekly-newsletter.yml` file with the following contents:

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  weekly-newsletter:
    lang: node14
    handler: ./weekly-newsletter
    image: alexellis/weekly-newsletter:0.0.1
    environment:
      ASTRA_DB_ID: 991f9b02-8fff-4d03-bc93-cfebbe1d41cc
      ASTRA_DB_REGION: eu-central-1
      ASTRA_DB_KEYSPACE: functions
    secrets:
    - astra-token
```

Note that the astra-token is considered confidential and must not be shared, for that reason we are creating it as a Kubernetes secret.

```bash
faas-cli secret create astra-token \
  --from-file astra-token --trim
```

Our JSON document will look like this, save it as `sample.json`:

```json
{
    "added": "2021-07-09",
    "note": "Self-hosted tunnels for local development",
    "sent": false,
    "url": "https://docs.inlets.dev"
}
```

Create the `handler.js` file with the following contents:

```js
'use strict'

const { createClient } = require("@astrajs/collections");
const fs = require("fs").promises

module.exports = async (event, context) => {
  let token = await fs.readFile("/var/openfaas/secrets/astra-token", "utf8")

  const astraClient = await createClient({
    astraDatabaseId: process.env.ASTRA_DB_ID,
    astraDatabaseRegion: process.env.ASTRA_DB_REGION,
    applicationToken: token.trim(),
  });

  // create a shortcut to the links in the ASTRA_DB_KEYSPACE keyspace
  const linksCollection = astraClient.
    namespace(process.env.ASTRA_DB_KEYSPACE).
    collection("links");

  if(event.method == "POST") {
    // application/json is parsed by default
    let newLink = event.body;
    const createdLink = await linksCollection.create(newLink);
    return context.
      status(200).
      succeed(createdLink);
  } else if(event.query.url) {
    try {
      let links = await linksCollection.find({ url: { $eq: event.query.url } });
      return context.
        status(200).
        succeed(links);
    } catch (err) {
      if(err.stack.includes("Request failed with status code 404")) {
        return context.
          status(200).
          succeed({});
      } else {
        console.error(err);
        return context.
          status(500).
          fail("Unable to query database");
      }
    }
  }

  let links;
  try {
    // Default with no url querystring
    links = await linksCollection.find({});
  } catch(err) {
    if(err.stack.includes("Request failed with status code 404")) {
      return context.
        status(200).
        succeed({});
    } else {
     console.error(err);
     return context.
      status(500).
      fail("Unable to query database");
    }
  }

  return context.
    status(200).
    succeed(links);
}
```

Note that when performing a `find()` operation with the Astra SDK, you will receive a 404 error if the collection hasn't been created yet. Astra DB creates collections when the first record is inserted. In this instance, the function returns an empty set of results.

Now install the required npm module:

```bash
cd weekly-newsletter/
npm install --save @astrajs/collections
cd ../
```

And deploy the function:

```bash
faas-cli up -f weekly-newsletter.yml
```

There's three ways to use the function:

1) Send a HTTP POST with a JSON body, containing a link to the article.
2) Access the root path to list all URLs that have been submitted.
3) Use the `?url=` query parameter to fetch a specific URL.

As discussed earlier, we've added logic that will allow the function to return an empty set of links even when the collection doesn't exist in Astra DB yet. You can try it with the following `curl` statement:

```bash
$ curl -s
 http://127.0.0.1:8080/function/weekly-newsletter | jq
{}
```

If you run into an error, just type in the following to check for a syntax error or issue with a secret:

```bash
faas-cli logs weekly-newsletter
```

If that shows nothing, but it still isn't working, there's a `kubectl get events` command we list in the [OpenFaaS troubleshooting documentation](https://docs.openfaas.com/deployment/troubleshooting/) that will more than likely pinpoint the issue.

In production, you'll also want to add authentication to the submission endpoint. You can learn how with my Serverless For Everyone Else eBook listed at the end of the article. Here, I just want to focus on getting you connected and getting/putting documents into Astra DB.

Create a new link:

```bash
$ curl -s -H "Content-type: application/json" \
--data-binary @sample.json \
 http://127.0.0.1:8080/function/weekly-newsletter | jq

{
  "documentId": "116a5b7e-74f3-4abd-bac4-0b2e3e558930"
}
```

Note that the documentId is a unique key that can be used to retrieve the document later.

List all links:

```bash
$ curl -s \
  http://127.0.0.1:8080/function/weekly-newsletter | jq

{
  "116a5b7e-74f3-4abd-bac4-0b2e3e558930": {
    "added": "2021-07-09",
    "note": "Self-hosted tunnels for local development",
    "sent": false,
    "url": "https://docs.inlets.dev"
  },
}
```

Now let's fetch a specific link by URL:

```bash
$ curl -s \
  "http://127.0.0.1:8080/function/weekly-newsletter?url=https://docs.inlets.dev" | jq
```

You will see the link from earlier.

Looking up the document by `url` is less efficient than by `documentId`, however it is more convenient and human readable.

If you're interested, you can view the dynamic schema for the "links" collection via the *CQL Console*:

![Dynamic fields](/images/2021-08-astra/pfields.jpg)

If you were using the traditional Cassandra Driver, you would have had to create your own `links` table manually, with something like the following:

```sql
use functions;

CREATE TABLE links (
  id UUID PRIMARY KEY,
  note text,
  added date,
  sent boolean,
  url text
);
```

With Astra DB's Document API, we don't have to write schemas, they are generated and can save time.

You can learn more about the [Astra DB Collection](https://docs.datastax.com/en/astra/docs/astra-collection-client.html) library here.

Why not take things further? Add the ability to the function to look up the link from the documentId, and the ability to mark a link as `sent` using `linksCollection.update()`.

## Wrapping up

You can find the code examples from this article on GitHub: [openfaas/astradb-openfaas](https://github.com/openfaas/astradb-openfaas). Feel free to fork the repository and adapt it to your own needs.

I've been learning about Cassandra and Astra DB for a few weeks now and feel much more comfortable understanding where to use it. The native Cassandra driver is convenient and means I can use a familiar SQL query language. The add-ons provided by Stargate bring additional options for: REST, Document access and GraphQL.

What about the cost? Datastax is calling this database a "Serverless database" because of consumption pricing coupled with the ability to scale out or down based on demand. All this is done without the user having to think about operations or server management.

The free credit coupled with not having to pay for idle means that many users will not be paying the usual 15-35 USD / month per database seen with other offerings.

Disclosure: Datastax is a client of OpenFaaS Ltd, this is a sponsored article but the opinions and views expressed are my own.

Here are some additional links for taking things further.

* [Get started with Astra DB](https://dtsx.io/2VYD4I4)
* [Stargate Data API Gateway](https://stargate.io/?utm_source=openfaas&utm_medium=referral&utm_campaign=node-webapp&utm_term=backend-devplay&utm_content=serverless-storage-functions-openfaas)
* [Document DB library for Astra DB and Node.js](https://www.npmjs.com/package/@astrajs/collections)
* [Go deeper with OpenFaaS with Serverless for Everyone Else](https://gumroad.com/l/serverless-for-everyone-else)

Datastax has a series of live videos that they wanted to share with you, aimed at beginners.

* [Introduction to Apache Cassandra](https://www.youtube.com/watch?v=wOyQlbFM1Uk)
* [Clone the Netflix UI with GraphQL, React and Astra DB](https://www.youtube.com/watch?v=ldEj7593fIA)
* [Build your own TikTok Clone with ReactJS and Netlify](https://www.youtube.com/watch?v=E5RtsqP53ic)
