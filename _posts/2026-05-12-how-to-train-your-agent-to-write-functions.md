---
title: "How To Train Your Agent"
description: "SOTA models are incredible, but often lack specific knowledge, learn how we taught agents how to create OpenFaaS functions the idiomatic way."
date: 2026-05-12
author_staff_member: han
categories:
  - agents
  - skills
  - ai
  - function development
dark_background: true
image: "/images/2026-05-how-to-train-your-agent/background.png"
hide_header_image: true
---

In this post we'll introduce [OpenFaaS Agent Skills](https://github.com/openfaas/agent-skills), a set of structured instructions that teach AI coding agents the right way to build and deploy OpenFaaS functions.

AI coding agents are good at writing code, but they often lack platform-specific knowledge. OpenFaaS has conventions around templates, secrets, image tagging, and tooling that general-purpose models tend to get wrong by default. Agent skills are there to fix that.

In this post we'll look at what the first skill covers, [`openfaas-function-dev`](https://github.com/openfaas/agent-skills/tree/master/skills/openfaas-function-dev), and walk through a real session that shows what happens when an agent actually has the right context to work with.


## Teaching an agent to write OpenFaaS functions

![A dragon learning to code, a nod to How to Train Your Dragon](/images/2026-05-how-to-train-your-agent/dragon-training.png)

When we started using AI coding agents to write OpenFaaS functions, the results were mixed. Agents can write perfectly reasonable Node.js, Python, or Go code, but they don't know OpenFaaS. They would reach for `kubectl create secret` instead of `faas-cli secret create`. They would store the secret value in an environment variable in `stack.yaml` rather than reading it from a file at `/var/openfaas/secrets/<name>`. They would deploy with a fixed `:latest` tag, and Kubernetes would quietly keep running the old image. They would pick an arbitrary base image instead of pulling the right template from the store. Each mistake on its own is fixable, together they add up to a function that doesn't behave the way it should.

Without the right context baked in, you end up correcting the same mistakes on every prompt, or pasting the same notes into every new session before the agent can do anything useful.

That is what agent skills are for. They give an agent the right context for a task automatically, without you having to repeat yourself every session.

The `openfaas-function-dev` skill does exactly that. Rather than explaining how to write a web handler or use `async/await`, it captures what we think about when we write functions for OpenFaaS.

## What we think about when we write functions for OpenFaaS

**Picking a template and language.**

To scaffold a function from a template you would typically run:

```bash
export OPENFAAS_PREFIX=docker.io/username

faas-cli new --lang python3-http my-function
```

That gives you a handler file and a `stack.yaml` configured with your image name, ready to build.

The docs list the [supported templates](https://docs.openfaas.com/cli/templates/#template-store), but you can write your own too.

Knowing which template to pick matters. The Python templates are a good example, the default `python3-http` is Alpine-based, but anything needing C extensions or `apt` packages (`psycopg2`, `Pillow`, ...) wants the Debian variant `python3-http-debian` instead.

**Runtime configuration, secrets, and credentials.**

`stack.yaml` is where most function-level configuration lives: environment variables, secrets, [timeouts](https://docs.openfaas.com/tutorials/expanded-timeouts/), [autoscaling](https://docs.openfaas.com/architecture/autoscaling/) labels, and resource limits/requests.

Secrets should be managed through the `faas-cli secret` commands and bound in `stack.yaml`. By convention, functions read them from files at `/var/openfaas/secrets/<name>`. Never put secrets in environment variables. Their values would be exposed in plain text by `faas-cli describe`.

**Local iteration.**

`faas-cli local-run --build` builds the function image and runs it as a local Docker container on `http://127.0.0.1:8080` in a single step. It is the quickest way to iterate on a function before deploying it. For a tighter loop on file changes, `faas-cli local-run --watch` rebuilds automatically on save.

When a function needs cluster services to test against, `faas-cli up --watch --tag=digest` keeps a deployment live and advances the tag each time code changes.

The function store also ships small helpers useful during development: `printer` logs everything it receives (handy as a callback target), `chaos` returns canned errors and delays to exercise error paths, and `env` dumps the function's environment to verify configuration was applied.

**Tags and versioning for container images.**

OpenFaaS functions are published to a container registry as OCI images. `stack.yaml` defaults to `:latest`, but every deploy needs a new, unique tag. Pushing to a tag the cluster has already seen often won't trigger a fresh pull, leaving the old image running.

The simplest option is to let `faas-cli` derive a tag automatically: `--tag=sha` appends the short Git commit SHA, `--tag=digest` a content hash of the handler folder.

Alternatively, pin the tag in `stack.yaml`, or use envsubst to keep registry, owner, and tag configurable across environments:

```yaml
functions:
  my-function:
    image: ${REGISTRY:-docker.io}/${OWNER:-}/my-function:${TAG:-latest}
```

**Troubleshoot and debug.**

When something goes wrong, start with the `faas-cli` describe and logs commands, plus the store helpers above. Together they cover most issues.

Only when those come up empty is it worth reaching for break-glass tools: kubectl on Kubernetes, or the faasd logs on faasd. For deeper, shareable reports the [diag plugin](https://docs.openfaas.com/cli/diagnostics/) bundles pod events, Function CRs, and Prometheus data.

**The OpenFaaS CLI (`faas-cli`).**

The CLI is a REST client for functions, secrets, namespaces, and more. It also acts as a wrapper around docker/buildkit.

- `faas-cli list`
- `faas-cli remove`
- `faas-cli describe`
- `faas-cli secret`
- `faas-cli namespace`
- `faas-cli build`
- `faas-cli push` / `faas-cli publish`
- `faas-cli deploy`
- `faas-cli up`

That covers most of the day-to-day workflow. Each command has a thorough `--help` with worked examples and documented flags, which is what makes the rest discoverable. Agents, like humans, are good at exploring once they have a basic framework in place.

## A real session: decrypting payloads with Node.js

To see the skill in action, here is a real session where OpenCode (running Claude Sonnet 4.6) was used to build a Node.js OpenFaaS function from scratch and deploy it to a live cluster. Since we often use local models alongside SOTA cloud-based ones, we also ran the same brief with Qwen3.6-35B-A3B (Q5 quantization) across 2x Nvidia 3090 cards, and the result was very similar.

The brief is a small payload-transformation function, a pattern we see customers use a lot: receive an event, reshape it, hand it back. In this case the function decrypts an AES-128 encrypted JSON payload using a master key bound as an OpenFaaS secret, adds a `processedAt` timestamp, and returns the result.

### Prompt 1: write the function

```
Write a function in node.js that takes an encrypted payload (internally
it's JSON), and uses a single master key AES 128-bit attached to it via
a secret. It decrypts it and adds a processedAt field

{
  "processedAt": "RFC time",
  "cipher": "ZUDWIOeeef==="
}

The body is returned back to the caller.
```

With the skill loaded, OpenCode worked through a sequence it would not have followed without it:

- **Pre-flight and scaffolding**: checked `faas-cli version` and `docker info`, browsed the template store, picked `node24`, and scaffolded the project with `faas-cli new`.
- **Handler implementation**: wrote a handler that reads the AES key from a file at `/var/openfaas/secrets/master-key` rather than an environment variable.
- **Local testing**: generated a test secret with `openssl rand`, wrote a small `encrypt-test.js` helper to produce AES-128-CBC ciphers, and validated everything end-to-end with `faas-cli local-run --build`.

`./decrypt-payload/handler.js`:

```js
'use strict'

const crypto = require('crypto')
const fs = require('fs')

const SECRET_PATH = '/var/openfaas/secrets/master-key'
const ALGORITHM = 'aes-128-cbc'
const IV_LENGTH = 16

function loadMasterKey () {
  const raw = fs.readFileSync(SECRET_PATH, 'utf8').trim()
  const key = Buffer.from(raw, 'hex')
  if (key.length !== 16) {
    throw new Error(`master-key must be 16 bytes (32 hex chars), got ${key.length}`)
  }
  return key
}

function decrypt (cipherB64, key) {
  const buf = Buffer.from(cipherB64, 'base64')
  if (buf.length <= IV_LENGTH) {
    throw new Error('cipher text too short — expected IV prepended to ciphertext')
  }
  const iv = buf.subarray(0, IV_LENGTH)
  const encrypted = buf.subarray(IV_LENGTH)
  const decipher = crypto.createDecipheriv(ALGORITHM, key, iv)
  const decrypted = Buffer.concat([decipher.update(encrypted), decipher.final()])
  return decrypted.toString('utf8')
}

module.exports = async (event, context) => {
  let body
  try {
    body = typeof event.body === 'string' ? JSON.parse(event.body) : event.body
  } catch (e) {
    return context.status(400).fail('invalid JSON body')
  }

  if (!body || !body.cipher) {
    return context.status(400).fail('missing required field: cipher')
  }

  let key
  try {
    key = loadMasterKey()
  } catch (e) {
    console.error('failed to load master-key:', e.message)
    return context.status(500).fail('could not load master key')
  }

  let plaintext
  try {
    plaintext = decrypt(body.cipher, key)
  } catch (e) {
    console.error('decryption failed:', e.message)
    return context.status(422).fail('decryption failed: ' + e.message)
  }

  let payload
  try {
    payload = JSON.parse(plaintext)
  } catch (e) {
    return context.status(422).fail('decrypted payload is not valid JSON')
  }

  payload.processedAt = new Date().toUTCString()

  return context
    .status(200)
    .headers({ 'Content-Type': 'application/json' })
    .succeed(JSON.stringify(payload))
}
```

`./stack.yaml`:

```yaml
version: 1.0
provider:
  name: openfaas
functions:
  decrypt-payload:
    lang: node24
    handler: ./decrypt-payload
    image: ttl.sh/example/decrypt-payload:latest
    secrets:
      - master-key
```

Local test output (via `faas-cli local-run --build`):

```json
{"user":"alice","amount":42,"processedAt":"Tue, 12 May 2026 09:55:47 GMT"}
```

### Prompt 2: deploy to the cluster

```
Deploy the function to my cluster
```

Rather than guessing at a registry prefix, the agent inspected the existing deployed functions to discover the convention already in use:

```bash
faas-cli list
faas-cli describe calc | grep Image
# Image: ttl.sh/example/calc:15aeb7f2722c94933abc1cc77f9ae5f6
```

It then updated `stack.yaml` with the correct image prefix, created the secret on the cluster, and deployed in the correct order:

```bash
# Create the secret on the cluster
faas-cli secret create master-key \
  --from-file .secrets/master-key

# Build, push, and deploy, advancing the tag so Kubernetes pulls the new image
faas-cli up -f stack.yaml --tag=digest
```

`--tag=digest` is something agents consistently get wrong without the skill: as covered earlier, redeploying with an unchanged tag leaves the cluster running stale code.

## A second session: a Hacker News monitor on a cron schedule

This time we'll build a small monitor that polls the Hacker News API every 15 minutes for posts and comments mentioning "serverless". Each new hit is posted to a Discord channel via a webhook. To avoid sending multiple notifications for the same post, they are deduplicated against a database. This example is a bit more involved than the first one with multiple moving parts, a cron schedule, persistent state, and calls to external services.

For this second function we used OpenCode again, with the Claude Sonnet 4.6 model.

### Prompt 1: write the function

The initial prompt:

```
Every 15 minutes, connect to Hacker News and look for comments or posts
on serverless. We want to keep everything we've seen in a database so we
don't have to re-scan it again. I want you to post each unique article
to a Discord channel using a webhook URL: https://discord.com/api/webhooks/
```

The brief leaves a lot of decisions to the agent: which template, where to keep state, how to schedule, how the Discord webhook is plumbed through. With the skill loaded.

- **Pre-flight and scaffolding**: ran `faas-cli version`, inspected `OPENFAAS_PREFIX`, browsed the template store, picked the `python3-http`, and scaffolded a new function with `faas-cli new`.
- **Handler implementation**: queried the [HN Algolia API](https://hn.algolia.com/api) for both `story` and `comment` hits matching `serverless`, used a small SQLite database for deduplication, and posted new items as Discord embeds. The Discord webhook URL was read from `/var/openfaas/secrets/discord-webhook-url`, not from an environment variable.
- **Cron schedule**: added the `cron-function` topic and `*/15 * * * *` schedule as annotations on the function in `stack.yaml`, which is how the [cron-connector](https://docs.openfaas.com/reference/cron/) picks functions up.

`./stack.yaml` (after the first prompt):

```yaml
version: 1.0
provider:
  name: openfaas
functions:
  hn-serverless-monitor:
    lang: python3-http
    handler: ./hn-serverless-monitor
    image: ttl.sh/example/hn-serverless-monitor:${TAG:-latest}
    secrets:
      - discord-webhook-url
    annotations:
      topic: cron-function
      schedule: "*/15 * * * *"
```

### Prompt 2: switch to PostgreSQL

For the initial implementation the agent used an SQLite database in the function. While this does not comply with the OpenFaaS runtime contract, functions should be stateless, it did clearly warn us about that and asked to consider using an external database service instead. So in the second prompt we asked it to switch to a PostgreSQL database.

```
Switch to using postgresql. The connection string should be configurable.
```

The interesting part here is what the agent did *not* do. PostgreSQL bindings on Python often need C extensions, which would normally push you to the Debian template variant of the python-http template. The skill calls this out, and the agent picked `psycopg2-binary` instead, a self-contained wheel that works on the default Alpine-based `python3-http` template. It correctly identified the limitations of the template and chose not to switch.

It also did the right thing with the connection string: stored it as a secret named `hn-pg-connection`, read it from `/var/openfaas/secrets/hn-pg-connection`, and added it to the `secrets:` list in `stack.yaml`.

`./hn-serverless-monitor/handler.py`:

```python
import json
import requests
import psycopg2
import psycopg2.extras
from datetime import datetime, timezone

HN_SEARCH_URL = "https://hn.algolia.com/api/v1/search"
DISCORD_SECRET_PATH = "/var/openfaas/secrets/discord-webhook-url"
PG_CONN_SECRET_PATH = "/var/openfaas/secrets/hn-pg-connection"


def get_pg_conn_string():
    with open(PG_CONN_SECRET_PATH) as f:
        return f.read().strip()


def get_db():
    conn_str = get_pg_conn_string()
    if not conn_str:
        raise RuntimeError("PostgreSQL connection string not configured")
    conn = psycopg2.connect(conn_str)
    with conn.cursor() as cur:
        cur.execute(
            """
            CREATE TABLE IF NOT EXISTS seen_items (
                id TEXT PRIMARY KEY,
                title TEXT,
                url TEXT,
                seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        )
    conn.commit()
    return conn


def is_new(conn, item_id):
    with conn.cursor() as cur:
        cur.execute("SELECT 1 FROM seen_items WHERE id = %s", (item_id,))
        return cur.fetchone() is None


def mark_seen(conn, item_id, title, url):
    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO seen_items (id, title, url) VALUES (%s, %s, %s) ON CONFLICT DO NOTHING",
            (item_id, title, url),
        )
    conn.commit()


def get_discord_url():
    with open(DISCORD_SECRET_PATH) as f:
        return f.read().strip()


def post_to_discord(webhook_url, title, hn_url, story_url, author, points):
    story_link = f" | [Story]({story_url})" if story_url else ""
    embed = {
        "title": title or "Hacker News item",
        "url": hn_url,
        "description": f"**Author:** {author} | **Points:** {points}{story_link}",
        "color": 0xFF6600,
        "footer": {"text": "Hacker News · serverless"},
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    payload = {"embeds": [embed]}
    resp = requests.post(webhook_url, json=payload, timeout=10)
    resp.raise_for_status()


def search_hn(query="serverless", tags="story", num_hours=1):
    params = {
        "query": query,
        "tags": tags,
        "numericFilters": f"created_at_i>{int(datetime.now(timezone.utc).timestamp()) - num_hours * 3600}",
        "hitsPerPage": 50,
    }
    resp = requests.get(HN_SEARCH_URL, params=params, timeout=15)
    resp.raise_for_status()
    return resp.json().get("hits", [])


def handle(event, context):
    webhook_url = get_discord_url()
    if not webhook_url:
        return {"statusCode": 500, "body": "Discord webhook URL not configured"}

    try:
        conn = get_db()
    except Exception as e:
        return {"statusCode": 500, "body": f"DB connection error: {e}"}

    posted = []
    errors = []

    hits = []
    for tags in ("story", "comment"):
        try:
            hits += search_hn(query="serverless", tags=tags, num_hours=24)
        except Exception as e:
            errors.append(f"HN search error ({tags}): {e}")

    for hit in hits:
        item_id = hit.get("objectID")
        if not item_id:
            continue

        title = hit.get("title") or hit.get("story_title") or hit.get("comment_text", "")[:80]
        story_url = hit.get("url") or ""
        hn_url = f"https://news.ycombinator.com/item?id={item_id}"
        author = hit.get("author", "unknown")
        points = hit.get("points") or 0

        if is_new(conn, item_id):
            try:
                post_to_discord(webhook_url, title, hn_url, story_url, author, points)
                mark_seen(conn, item_id, title, story_url)
                posted.append(item_id)
            except Exception as e:
                errors.append(f"Discord post error for {item_id}: {e}")

    conn.close()

    result = {"posted": len(posted), "posted_ids": posted, "errors": errors}
    return {"statusCode": 200, "body": json.dumps(result), "headers": {"Content-Type": "application/json"}}
```

### Debugging on a real cluster

The agent deployed the function to the OpenFaaS cluster and invoked it to discover not everything was right the first time. Invocations failed with `AttributeError: 'Context' object has no attribute 'status'`.

The agent quickly figured out the handler contract pointed at by the skill for the `python3-http` was not followed. By looking at function logs and source it fixed any errors and re-ran a smoke test until the function returned `200`.

A typical successful run looks like:

```json
{"posted": 2, "posted_ids": ["43928412", "43928577"], "errors": []}
```

![Screenshot of Discord embeds posted by the hn-serverless-monitor function in a #dev-test channel](/images/2026-05-how-to-train-your-agent/discord-hn-serverless-monitor.png)
> Discord embeds posted by the `hn-serverless-monitor` function for new Hacker News items mentioning "serverless".

Two prompts got us to fully working function on a live cluster, with the agent making the right calls on template choice, secret handling, cron annotations, image tagging, and the right CLI commands for the gateway it was talking to.

## A third session: geo-enriching telemetry events in Go

The first two examples used Node.js and Python. For the third we wanted to see how the skill held up against a different template, and a different problem: enriching a stream of telemetry events with geolocation data using the [MaxMind GeoLite2](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/) databases. Rather than calling out to an external service on every request, the `.mmdb` files are shipped inside the function image and queried from disk.

For this third function we used OpenCode again, with the Claude Sonnet 4.6 model.

### Prompt 1: write the function

The initial prompt:

```
Create a function the accepts telemetry events as input and enrich the
events with geolocation data: country, ASN, city, etc. This will require
downloading or embedding the geo2lite database:
https://dev.maxmind.com/geoip/geolite2-free-geolocation-data/.
```

The brief is open about the language and how to ship the database. With the skill loaded the agent made the choices we would expect:

- **Pre-flight and scaffolding**: ran `faas-cli version`, browsed the template store, picked `golang-middleware`, and scaffolded with `faas-cli new`. Go is a good fit here, the [`oschwald/geoip2-golang`](https://github.com/oschwald/geoip2-golang) library is the canonical client for the MaxMind format.
- **Database packaging**: extracted the `.mmdb` files from the provided tar into `enrich-telemetry/static/` so they get baked into the image at build time. No download at startup, no PVC, no secret to manage.
- **Handler implementation**: opened both databases once via `sync.Once` and reused the readers across invocations, parsed the request body as either a single event or an array, and merged geo fields into each event in place so original fields are preserved.
- **Repository hygiene**: added `enrich-telemetry/static/` to `.gitignore` so the `.mmdb` files (which are subject to MaxMind's EULA and are regenerated weekly) never get committed.

`./stack.yaml`:

```yaml
version: 1.0
provider:
  name: openfaas
functions:
  enrich-telemetry:
    lang: golang-middleware
    handler: ./enrich-telemetry
    image: ttl.sh/example/enrich-telemetry:${TAG:-latest}
```

`./enrich-telemetry/handler.go`:

```go
package function

import (
	"encoding/json"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"sync"

	"github.com/oschwald/geoip2-golang"
)

// databases are opened once and reused across invocations.
var (
	cityDB  *geoip2.Reader
	asnDB   *geoip2.Reader
	once    sync.Once
	initErr error
)

func dbDir() string {
	// The OpenFaaS watchdog sets the working directory to the handler folder,
	// which contains the embedded "static/" sub-directory.
	dir, _ := filepath.Abs("static")
	if _, err := os.Stat(dir); err == nil {
		return dir
	}
	return filepath.Join(filepath.Dir(os.Args[0]), "static")
}

func initDBs() {
	once.Do(func() {
		dir := dbDir()
		var err error
		cityDB, err = geoip2.Open(filepath.Join(dir, "GeoLite2-City.mmdb"))
		if err != nil {
			initErr = err
			log.Printf("ERROR opening GeoLite2-City.mmdb: %v", err)
			return
		}
		asnDB, err = geoip2.Open(filepath.Join(dir, "GeoLite2-ASN.mmdb"))
		if err != nil {
			initErr = err
			log.Printf("ERROR opening GeoLite2-ASN.mmdb: %v", err)
		}
	})
}

// enrichEvent adds geo fields to a generic event map. The map is modified
// in-place and returned. The "ip" field must be present.
func enrichEvent(ev map[string]any) map[string]any {
	ipStr, _ := ev["ip"].(string)
	ip := net.ParseIP(ipStr)
	if ip == nil {
		return ev
	}

	if cityDB != nil {
		if rec, err := cityDB.City(ip); err == nil {
			ev["country_code"] = rec.Country.IsoCode
			if name, ok := rec.Country.Names["en"]; ok {
				ev["country_name"] = name
			}
			if name, ok := rec.City.Names["en"]; ok {
				ev["city"] = name
			}
			ev["latitude"] = rec.Location.Latitude
			ev["longitude"] = rec.Location.Longitude
		} else {
			log.Printf("WARN city lookup for %s: %v", ipStr, err)
		}
	}

	if asnDB != nil {
		if rec, err := asnDB.ASN(ip); err == nil {
			ev["asn"] = rec.AutonomousSystemNumber
			ev["asn_org"] = rec.AutonomousSystemOrganization
		} else {
			log.Printf("WARN ASN lookup for %s: %v", ipStr, err)
		}
	}

	return ev
}

// Handle is the OpenFaaS entry point.
// Accepts a JSON object or JSON array of objects, each with an "ip" field.
// Returns the same structure with geo enrichment fields added.
func Handle(w http.ResponseWriter, r *http.Request) {
	initDBs()

	if initErr != nil {
		http.Error(w, "geo database unavailable: "+initErr.Error(), http.StatusInternalServerError)
		return
	}

	defer r.Body.Close()
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// Try array first, then single object, to decide output shape.
	var events []map[string]any
	if err := json.Unmarshal(body, &events); err == nil {
		for i := range events {
			events[i] = enrichEvent(events[i])
		}
		_ = json.NewEncoder(w).Encode(events)
		return
	}

	var single map[string]any
	if err := json.Unmarshal(body, &single); err != nil {
		http.Error(w, "body must be a JSON object or array of objects", http.StatusBadRequest)
		return
	}
	_ = json.NewEncoder(w).Encode(enrichEvent(single))
}
```

The dependency was added the idiomatic way with `go mod` inside the handler folder, which the `golang-middleware` template picks up at build time:

```bash
cd enrich-telemetry
go get github.com/oschwald/geoip2-golang
```

### Local iteration with `local-run`

Before deploying anywhere, the agent built and ran the function locally with `faas-cli local-run --build` and exercised it with `curl` against `http://127.0.0.1:8080`. It tested two shapes the handler supports, a single event:

```bash
curl -s http://127.0.0.1:8080 \
  -H 'Content-Type: application/json' \
  -d '{"user_id":"u-1","event":"page_view","ip":"8.8.8.8"}'
```

and a batch with a deliberately invalid IP mixed in to verify the pass-through behaviour:

```bash
curl -s http://127.0.0.1:8080 \
  -H 'Content-Type: application/json' \
  -d '[{"ip":"8.8.8.8"},{"ip":"not-an-ip"},{"ip":"1.1.1.1"}]'
```

There was a small detour the agent took that is worth mentioning. It tried to run `faas-cli local-run`, as a foreground process and got stuck. This is an issue that we have seen happening a number of times with similar workloads. While the skill includes a rule that tries to prevent this it seems like to get ignored from time to time. After we pointed out it should run local-run as a background process, it switched immediately, waited for the container to come up, and ran the invocations cleanly.

With the local response matching expectations, the agent reported back that the function was working and stopped there, leaving the deploy as an explicit next step.

### Prompt 2: deploy to the cluster

```
Deploy to the live cluster
```

The agent ran `faas-cli up -f stack.yaml --filter enrich-telemetry --tag=digest` to build, push, and deploy with a content-derived tag, then re-ran the same curl against the live gateway URL to confirm everything still worked end-to-end.

Two prompts got us a Go function that bundles two databases into the image, opens them once per cold start, accepts both single events and batches, and preserves the original event fields in its output.

## Installing the skill

Add the skill to your project with `npx`:

```bash
npx skills add openfaas/agent-skills
```

This detects which agents you have configured and installs the skill files into the appropriate directories (`.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, etc.).

For manual installation, clone the repository and copy the skill into your agent's skills directory:

```bash
git clone https://github.com/openfaas/agent-skills.git

# Claude Code
cp -r agent-skills/skills/* .claude/skills/

# OpenCode, Amp, Codex, and other agents following the agentskills.io standard
cp -r agent-skills/skills/* .agents/skills/
```

From that point on, whenever the agent picks up a task that involves OpenFaaS functions, the skill is loaded automatically.

## Wrapping up

Two short prompts, one skill, and a working Node.js function was scaffolded, tested locally, and deployed to a live OpenFaaS cluster. The skill did not write any code itself, it gave the agent the context it needed to make the right decisions at each step: template choice, secret handling, local testing workflow, image tagging, and deploy sequence.

The full source for all three examples in this post is available at [github.com/welteki/train-your-agent-examples](https://github.com/welteki/train-your-agent-examples).

The [`openfaas-function-dev`](https://github.com/openfaas/agent-skills/tree/master/skills/openfaas-function-dev) skill is open source under MIT. We plan to grow it to cover more advanced patterns:

- **Workflow patterns**: cron triggers, async invocations with callbacks, and event-driven function chains
- **IAM and function authentication**: setting up and calling functions with OpenFaaS IAM
- **Function Builder**: building functions remotely via the Function Builder API without a local Docker daemon

If you run into a case where an agent makes a mistake that a skill could prevent, contributions are welcome at [github.com/openfaas/agent-skills](https://github.com/openfaas/agent-skills).
