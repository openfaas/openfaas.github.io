---
title: How to check for price drops with Functions, Cron & LLMs
description: Learn how Alex bought a set of chisels by monitoring the price using HTML scraping and a cron job with OpenFaaS. You can apply the same technique for things you'd like to buy or monitor.
date: 2024-09-04
categories:
- casestudy
- llm
- scraping
- golang
- automation
- cron
- scheduled
dark_background: true
image: /images/2024-09-stockcheck/background.png
author_staff_member: alex
hide_header_image: true
---

Learn how Alex bought a set of premium chisels by monitoring the price using HTML scraping and a cron job with OpenFaaS. You can apply the same technique for things you'd like to buy or monitor, or for automating other tasks.

Let me start by saying that not all code and not all functions need to live forever. I think as developers we tend to associate code with permanence, but very few things are permanent, and most things change over time. So I think it's OK if it serves a temporary purpose for a single task or a short period of time, if it gets a job done.

And what better way to automate a task than with a short block of code deployed as a function, without any boiler plate Dockerfiles, HTTP servers or deployment scripts?

I wanted to purchase a set of premium Lie Nielsen chisels and had been scouring the used market including eBay for a while. Eventually I found a set of 4 which was marked at around 86 GBP per item, a fairly cheeky price for a second hand item, considering they are only 100GBP brand new. I phone the company and said I'd make an offer and they could sell them today, but they declined and said to check back in September when they'd reduce the price if they hadn't sold.

It wasn't enough of a deal for me to pay that price, so I kept an eye on eBay with a search alert and as September neared, I decided to look into their website to decide if I could parse the price and send myself an alert via email, Slack or Discord, if it changed in some way.

![Conceptual architecture](/images/2024-09-stockcheck/conceptual.png)
> We'll also cover using a traditional HTML parser first, then compare it to using a Large Language Model (LLM) for the same task.

At the end of the article, you can see the complete function code, how to design a system prompt to use an LLM instead, and some discussion on real-life uses-cases and other ideas for combining functions, cron jobs and LLMs.

## faasd or OpenFaaS CE with Kubernetes?

For these types of automation functions, I prefer to use faasd over OpenFaaS CE with Kubernetes, but if you have a cluster set up already it'll work just as well.

[faasd](https://docs.openfaas.com/deployment/#faasd-serverless-for-everyone-else) is lightweight, easy to install, can run on as little as 1GB of RAM and is perfect for automation tasks. It runs using containerd so doesn't need Kubernetes or clustering. faasd uses a docker-compose file to define all the core components for OpenFaaS, and can be extended to add stateful containers like Grafana and Postgresql backed by persistent volumes.

faasd is permissively licensed under MIT which means it can also be used for commercial use.

I wrote a detailed guide for writing and deploying automation tasks and workflows to faasd called [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) which is available in PDF and ePUB format with a longer video and a Grafana dashboard included in premium packages.

## Scraping the website

The website didn't appear to have an API, or to load up a separate JSON file, so I started examining the HTML to understand my options.

At the bottom of the HTML I found:

```html
 <script type='text/javascript'> dataLayer.push({ ecommerce: null }); dataLayer.push({ event: 'view_item', ecommerce: { currency: 'GBP', items: [{ item_id: '3500', item_name: 'Lie-Nielsen Bevel Edge Chisels', item_brand: 'Lie-Nielsen Toolworks', item_category: 'Alberts Extras' }] } }); </script> 
            <script type="text/javascript">
            var google_tag_params = {
            ecomm_prodid: "3500",
ecomm_pagetype: "product",
ecomm_totalvalue: 323.00
            };
            </script>         
```

Now I'd have to somehow include a JavaScript engine in my Go function to evaluate this and get the result, or I'd need to try and parse the text with a regular expression.

I kept looking and found the same price embedded in another location:

```html
<script type="application/ld+json"> {
    "@context": "https:\/\/schema.org\/",
    "@type": "Product",
    "name": "Lie-Nielsen Bevel Edge Chisels",
    "url": "https:\/\/www.classichandtools.com\/lie-nielsen-bevel-edge-chisels\/p3500",
    "image": [
        "https:\/\/www.classichandtools.com\/images\/products\/large\/3500_8357.jpg"
    ],
    "description": "<p>4 Lie-Nielsen Bevel Edge Chisels 1\/4&quot;, 3\/8&quot;, 1\/2&quot; &amp; 3\/4&quot;<\/p>\r\n\r\n<p>Only the 1\/4&quot; has been used and probably only to try it out as it is &quot;as new&quot;.<\/p>\r\n\r\n<p>The others still have their protective wax coverings to the chisel edges.<\/p>\r\n\r\n<p>They were originally purchased in 2012 but have probably stayed in there orginal boxes since then (with the exception of the 1\/4&quot;). Hornbeam (not maple) handles.<\/p>\r\n\r\n<p>Instruction leaflets for each.<\/p>\r\n\r\n<p>Lie-Nielsen A2 bevel edge chisels - these will hold their edge longer than high carbon chisels and therefore require less frequent sharpening.<br \/>\r\n<br \/>\r\nThe chisel edges are square, parallel along the length, and very narrow so you can get into tight places.<\/p>\r\n\r\n<p>The backs are ground flat and finished by hand at 400 grit. The bevel is flat ground at 30&deg;, but a higher secondary bevel (about 35&deg;) is advisable, depending on the wood and how the chisel is being used.<\/p>\r\n\r\n<p>Additional honing is recommended.<\/p>\r\n",
    "brand": {
        "@type": "Thing",
        "name": "Lie-Nielsen Toolworks"
    },
    "offers": [
        {
            "@type": "Offer",
            "url": "https:\/\/www.classichandtools.com\/lie-nielsen-bevel-edge-chisels\/p3500",
            "priceCurrency": "GBP",
            "price": "323.00",
            "availability": "InStock",
            "itemOffered": {
                "@type": "IndividualProduct",
                "name": "Lie-Nielsen Bevel Edge Chisels",
                "productID": "7580",
                "sku": "IP-3500",
                "itemCondition": "used",
                "offers": {
                    "@type": "Offer",
                    "availability": "InStock",
                    "price": "323.00",
                    "priceCurrency": "GBP"
                }
            }
        }
    ],
    "sku": "IP-3500"
} </script>
```

Then I saw there was a header that I could parse:

```
<meta property="twitter:image" content="https://www.classichandtools.com/images/products/large/3500_8357.jpg" />
<meta property="twitter:label1" content="PRICE" />
<meta property="twitter:data1" content="323.00" />
<meta property="twitter:label2" content="AVAILABILITY" />
<meta property="twitter:data2" content="in stock" />
<meta property="twitter:site" content="Classic Hand Tools Limited" />
<meta property="twitter:domain" content="classichandtools.com" />
```

But I couldn't address this directly with an XPath selector, I would have needed to have iterated all the "twitter:label" tags to find "PRICE" and then go on to the next sibling to get the price.

Then it jumped out at me, they'd made it so easy:

```html
<meta property="og:url" content="https://www.classichandtools.com/lie-nielsen-bevel-edge-chisels/p3500" />
<meta property="og:site_name" content="Classic Hand Tools Limited" />
<meta property="og:price:amount" content="323.00" />
<meta property="og:price:currency" content="GBP" />
<meta property="og:availability" content="in stock" />
<meta property="og:brand" content="Lie-Nielsen Toolworks" />
<meta property="og:image" content="https://www.classichandtools.com/images/products/large/3500_8357.jpg" />
<meta property="twitter:card" content="product" />
<meta property="twitter:title" content="Lie-Nielsen Bevel Edge Chisels" />
<meta property="twitter:description" content="4 Lie-Nielsen Bevel Edge Chisels 1/4&quot;, 3/8&quot;, 1/2&quot; &amp; 3/4&quot;
```

That was it, I just needed an XPath to get a meta tag with the property "og:price:amount" and I could get the price. Then I thought it'd also be worth checking the availability, so I could get a notification if they went out of stock.

## Picking a language

I'm no stranger to web automation and testing using Selenium or scraping tools like [Scrapy](https://scrapy.org/) (Python) or [cheerio](https://cheerio.js.org/) (Node), and have written [stock checkers in the past for the Raspberry Pi, and then the Zero](https://www.openfaas.com/blog/searching-for-raspberrypi/).

But I wanted to see what the options were in 2024, so I asked ChatGPT's GPT4-o model to give me code examples for Node, Python and Go since these tend to be the most popular languages for AWS Lambda functions, and are my personal favourites for functions too.

It immediately showed me an abstract library for running a jQuery-like expression over the HTML.

My prompt was:

```
What can be used for scraping / parsing HTML in Go? Is it reliable?

How does it compare to cheerio for Node, and the options for Python like scappy?

I just want:

<meta property="og:price:amount" content="340.00" />


<meta property="og:availability" content="in stock" />


From: 

<!DOCTYPE html>
...
```

I wanted to see code samples to see how I felt about the options:

```
Can you write me a code example for the above sample HTML in each language/framework for me to evaluate?
```

This is how it looked with goquery:

```go
package main

import (
    "fmt"
    "github.com/PuerkitoBio/goquery"
    "log"
    "strings"
)

func main() {
    // Sample HTML
    html := `
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <meta property="og:price:amount" content="340.00" />
        <meta property="og:availability" content="in stock" />
    </head>
    </html>`

    // Load the HTML document
    doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
    if err != nil {
        log.Fatal(err)
    }

    // Extract the og:price:amount meta tag content
    price, exists := doc.Find(`meta[property="og:price:amount"]`).Attr("content")
    if exists {
        fmt.Println("Price:", price)
    }

    // Extract the og:availability meta tag content
    availability, exists := doc.Find(`meta[property="og:availability"]`).Attr("content")
    if exists {
        fmt.Println("Availability:", availability)
    }
}
```

I am not a big fan of jumping in and using a library without understanding its license, how it's being developed & maintained, and its code quality. If this could be done trivially with Go's HTML parsing library then, I'd feel more comfortable.

So I said: `Now show me just golang.org/x/net/html on its own`

```go
package main

import (
    "fmt"
    "golang.org/x/net/html"
    "strings"
)

// Function to traverse the HTML nodes and extract meta tag content by property name
func extractMetaContent(node *html.Node, property string) string {
    if node.Type == html.ElementNode && node.Data == "meta" {
        var prop, content string
        for _, attr := range node.Attr {
            if attr.Key == "property" && attr.Val == property {
                prop = attr.Val
            }
            if attr.Key == "content" {
                content = attr.Val
            }
        }
        if prop == property {
            return content
        }
    }

    // Recursively traverse the HTML node tree
    for child := node.FirstChild; child != nil; child = child.NextSibling {
        result := extractMetaContent(child, property)
        if result != "" {
            return result
        }
    }

    return ""
}

func main() {
    // Sample HTML
    htmlData := `
    <!DOCTYPE html>
    <html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en">
    <head>
        <meta property="og:price:amount" content="340.00" />
        <meta property="og:availability" content="in stock" />
    </head>
    </html>`

    // Parse the HTML document
    doc, err := html.Parse(strings.NewReader(htmlData))
    if err != nil {
        fmt.Println("Error parsing HTML:", err)
        return
    }

    // Extract the og:price:amount meta tag content
    price := extractMetaContent(doc, "og:price:amount")
    fmt.Println("Price:", price)

    // Extract the og:availability meta tag content
    availability := extractMetaContent(doc, "og:availability")
    fmt.Println("Availability:", availability)
}
```

It was a much "purer" approach, that was probably closer to what goquery was doing internally, but I didn't like the readability of the code as much.

So I went with goquery and started writing a new function:

```bash
faas-cli template store pull golang-middleware
faas-cli new --lang golang-middleware --prefix docker.io/alexellis2 chiselcheck
```

I used the name `chiselcheck` because like I said in the introduction, I saw this as a single-purpose tool.

## How I wrote the function

I copied the code from the ChatGPT example into the handler, removed the main() block, and made a HTTP call instead of using hard-coded sample text. I then ran a `go get` in the handler folder and ran it locally with:

```bash
cd chiselcheck
go get 
cd ..

faas-cli local-run --watch --tag=digest
```

That let me invoke it with curl and see if worked as expected, it did.

I had three destinations in mind for the alert:

* Discord - you can create endless incoming webhooks for free, and it just takes a click in the UI
* Slack - these are limited on free accounts and you have to log into the administration panel to create them, they still work fine if you're primarily a Slack user
* Email - to make it cost effective it would need AWS SES which I've used before, but the AWS SDK for Go is huge and also requires a lot of boilerplate code to get it to work

So I went for Discord, it's just a very simple HTTP POST with a JSON payload: `{"content": "The price has changed to £340.00"}`.

I created a secret for the webhook URL and then added it to the function's secrets section in stack.yaml:

```bash
faas-cli secret create discord-stock-incoming-webhook-url \
    --from-literal=https://discord.com/api/webhooks/xyz/abcfe
```

Followed by:

```diff
functions:
    chiselcheck:
        lang: golang-middleware
+        secrets:
+        - discord-stock-incoming-webhook-url
```

Next I needed storage, and this was a painful moment. I didn't have somewhere I could write this temporary data, it's where a remotely hosted Postgresql server for 5 USD / mo would have been perfect. I decided to refer to my eBook on OpenFaaS called [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) and got a local Postgresql server running inside faasd within a couple of minutes.

I copied the password from the installation steps and then created a secret for the function to use:

```bash
faas-cli secret create postgres-passwd \
    --from-file=postgres-passwd.txt
```

I added the secret to the stack.yaml file:

```diff
functions:
    chiselcheck:
        lang: golang-middleware
        secrets:
        - discord-stock-incoming-webhook-url
+       - postgresql-password
```

This is where I needed to write some boilerplate code, so I imported the `database/sql` package and started writing the code to connect to the database, create a table if it didn't exist, and then insert a record. After adding the import, I made sure to `cd` into the handler folder and to run `go get` to update the `go.mod` file, otherwise the build would complain about missing packages.

Before I was ready to test the function end to end again, I ran `faas-cli build` to see if there were any compilation errors.

You'll find detailed code samples and patterns in the Premium edition of my other eBook [Everyday Golang](https://openfaas.gumroad.com/l/everyday-golang).

I then added a cron job to the function to run every 30 minutes:

```diff
functions:
  chiselcheck:
+    annotations:
+      topic: cron-function
+      schedule: "*/30 * * * *"
```

There are instructions in [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) on how to set up the cron-connector by editing the docker-compose.yaml file, or you can install the cron-connector for Kubernetes with Helm.

## Looking at the handler's code

* During `init()` the function reads the webhook URL and the Postgresql password from secrets
* It then connects to the database and creates the schema if it doesn't exist already
* The HTTP handler then makes a request to the website and parses the price and availability using goquery
* It then checks the database for the last known price and availability
* If the price or availability has changed, it posts to Discord and updates the database

I haven't spent a long time splitting code out into separate files, and there are areas that could be improved.

Remember the goal of this code, to write something as quickly as possible to get the job done.

```go
package function

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/PuerkitoBio/goquery"

	_ "github.com/lib/pq"
)

var db *sql.DB
var webhookURL string

func init() {

	w, err := os.ReadFile("/var/openfaas/secrets/discord-stock-incoming-webhook-url")
	if err != nil {
		log.Fatalf("Error reading webhook URL file: %v", err)
	}

	webhookURL = strings.TrimSpace(string(w))

	password, err := os.ReadFile("/var/openfaas/secrets/postgres-passwd")
	if err != nil {
		log.Fatalf("Error reading password file: %v", err)
	}

	postgresHost := os.Getenv("postgres_host")
	postgresPort := os.Getenv("postgres_port")
	postgresDB := os.Getenv("postgres_db")
	postgresUser := os.Getenv("postgres_user")

	// The connection-string style can be parsed incorrectly if the password isn't escaped and contains special characters.
	dsn := fmt.Sprintf("user=%s password=%s host=%s port=%s dbname=%s",
		postgresUser,
		strings.TrimSpace(string(password)),
		postgresHost,
		postgresPort,
		postgresDB)

	sslmode := "sslmode=disable"

	dbb, err := sql.Open("postgres", fmt.Sprintf("%s %s", dsn, sslmode))
	if err != nil {
		log.Fatalf("Error opening database: %v", err)
	}

	db = dbb

	if err := initSchema(db); err != nil {
		log.Fatalf("Error initializing schema: %v", err)
	}

}

func initSchema(db *sql.DB) error {
	createTable := `
	CREATE TABLE IF NOT EXISTS stock_check (
		id SERIAL PRIMARY KEY,
		url TEXT,
		price FLOAT,
		availability BOOLEAN,
		created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
	);
	`
	_, err := db.Exec(createTable)
	if err != nil && !strings.Contains(err.Error(), "already exists") {
		return err
	}

	log.Printf("Schema initialized, table: stock_check created.")

	return nil
}

func Handle(w http.ResponseWriter, r *http.Request) {

	if r.URL.Path != "/" {
		http.Error(w, "404 not found.", http.StatusNotFound)
		return
	}

	if r.Body != nil {
		defer r.Body.Close()
	}

	hackPrice := r.URL.Query().Get("price")

	url := "https://www.classichandtools.com/lie-nielsen-bevel-edge-chisels/p3500"
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		http.Error(w, "Error creating request object", http.StatusInternalServerError)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	req = req.WithContext(ctx)
	defer cancel()

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, "Error sending request", http.StatusInternalServerError)
		return
	}

	var bytes []byte
	if res.Body != nil {
		defer res.Body.Close()
		bytes, _ = io.ReadAll(res.Body)
	}

	html := string(bytes)

	// Load the HTML document
	doc, err := goquery.NewDocumentFromReader(strings.NewReader(html))
	if err != nil {
		log.Fatal(err)
	}

	stock := StockCheck{}

	// Extract the og:price:amount meta tag content
	price, exists := doc.Find(`meta[property="og:price:amount"]`).Attr("content")
	if exists {
		// fmt.Println("Price:", price)
		stock.Price, _ = strconv.ParseFloat(price, 64)
	}

	// Extract the og:availability meta tag content
	availability, exists := doc.Find(`meta[property="og:availability"]`).Attr("content")
	if exists {
		// fmt.Println("Availability:", availability)
		stock.Availability = availability == "in stock"
	}

	log.Printf("Stock: %+v", stock)
	if hackPrice != "" {
		stock.Price, _ = strconv.ParseFloat(hackPrice, 64)
		log.Printf("Hacking price to: %v", stock.Price)
	}
	data, err := json.Marshal(stock)
	if err != nil {
		http.Error(w, "Error marshalling data", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Write(data)

	if oldStock, err := getOldData(db, url); err == nil {
		if oldStock == nil {
			if err := insertData(db, url, stock); err != nil {
				log.Printf("Error inserting data: %v", err)
			} else {
				log.Printf("Inserted initial price.")
			}
		} else if oldStock.Price != stock.Price || oldStock.Availability != stock.Availability {
			log.Printf("Price or availability changed, posting to Discord.")

			if err := postDiscord(webhookURL, fmt.Sprintf(`Price: £%.2f, Availability: %v`, stock.Price, stock.Availability)); err != nil {
				log.Printf("Error posting to Discord (%s): %v", webhookURL, err)
			}

			if err := updateData(db, url, stock); err != nil {
				log.Printf("Error inserting data: %v", err)
			}
		}
	}

}

func postDiscord(webhookURL, msg string) error {

	v := struct {
		Content string `json:"content"`
	}{
		Content: msg,
	}

	payload, err := json.Marshal(v)
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, webhookURL, bytes.NewBuffer(payload))
	if err != nil {
		return err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "chiselcheck/1.0")

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}

	if res.Body != nil {
		defer res.Body.Close()
	}

	if res.StatusCode != http.StatusOK && res.StatusCode != http.StatusNoContent &&
		res.StatusCode != http.StatusCreated {
		return fmt.Errorf("unexpected status code: %d", res.StatusCode)
	}

	return nil
}

func getOldData(db *sql.DB, url string) (*StockCheck, error) {
	row := db.QueryRow("SELECT price, availability FROM stock_check WHERE url = $1 ORDER BY created_at DESC LIMIT 1", url)

	stock := &StockCheck{}
	err := row.Scan(&stock.Price, &stock.Availability)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}

	return stock, nil
}

func insertData(db *sql.DB, url string, stock StockCheck) error {
	_, err := db.Exec("INSERT INTO stock_check (url, price, availability) VALUES ($1, $2, $3)", url, stock.Price, stock.Availability)
	if err != nil {
		return err
	}

	return nil
}

func updateData(db *sql.DB, url string, stock StockCheck) error {
	_, err := db.Exec("UPDATE stock_check SET price = $1, availability = $2 WHERE url = $3", stock.Price, stock.Availability, url)
	if err != nil {
		return err
	}

	return nil
}

type StockCheck struct {
	Price        float64 `json:"price"`
	Availability bool    `json:"availability"`
}
```

You may be tempted to write the price to a simpler option like a file, but remember that functions are designed to be ephemeral and to be able to scale to zero, or to scale up to multiple replicas. In those cases, you cannot rely on the filesystem for persistence.

The simplest option would be a remotely hosted cloud database, or even an Object Store like AWS S3. For the lifetime of this function, you could also use a key-value store like Redis.

## So did it work?

It did indeed work. I felt the team at Classic Hand Tools were rather stingy with their discount, but I was probably the first person to find out about the price change so the function achieved its goal.

The next morning I clicked on the Logs tab for the function and selected "24h" in the OpenFaaS Pro dashboard, that showed me what happened leading up to the alert:

![Dropped prices](/images/2024-09-stockcheck/detected.png)

Here's the Discord alert I got when I checked my phone:

![Discord alert](/images/2024-09-stockcheck/discord.png)

Whilst it's overkill for this task because standard HTML scraping and parsing techniques worked perfectly well, I decided to try out running a local [Llama3.1](https://ai.meta.com/blog/meta-llama-3-1/) 8B model on my Nvidia RTX 3090 GPU to see if it was up to the task.

It wasn't until I ran `ollama run llama3.1:8b-instruct-q8_0` and pasted in my prompt that I realised just how long that HTML was was. It was huge, over 681KB of text, this is generally considered a large context window for a Large Language Model.

{% raw %}
```
You are a function that parses HTML and returns the data requested as JSON. "available" is true when "in stock" or "InStock" was found in the HTML, anything else is false. You must give no context, no explanation and no other text than the following JSON, with the values replaced accordingly between the ` characters.

`{"price": 100, "available": true}`

HTML:
```
{% endraw %}

The initial results were really quite disappointing, even though I asked for only JSON to be returned, the model kept explaining the HTML and ignored my request.

It wasn't until I tried using a system prompt as suggested by [Arvid Kahl](https://x.com/arvidkahl) (indie developer, turned LLM enthusiast), that I started to get the results I wanted:

{% raw %}
```
<|begin_of_text|><|start_header_id|>system<|end_header_id|>

You are an expert at parsing unstructured documents. You are able to extract specific segments and data and to present it in JSON machine readable format.

<|eot_id|><|start_header_id|>user<|end_header_id|>

Scan the following HTML:


Provide the result in the following format, but avoid using the example in your output. Do not output any metadata, or explanation in any way.

{
"available": false,
"price": 260.0
}

<|eot_id|><|start_header_id|>assistant<|end_header_id|>
```
{% endraw %}

If a local LLM wasn't up to the task, then we could have also used a cloud-hosted service like the OpenAI API, or one of the many other options that charge per request.

And in the case that the local LLM aced the task, we could also try scaling down to something that can run better on CPU, or that doesn't require so many resources. I tried out [Microsoft's phi3 model](https://azure.microsoft.com/en-us/blog/introducing-phi-3-redefining-whats-possible-with-slms/) which was designed with limited resources in mind. After setting the system prompt, to my surprise performed the task just as well and returned the same JSON for me.

To integrate a local LLM with your function, you can package [Ollama](https://ollama.com/) as a container image using the instructions on our sister site: inlets.dev - [Access local Ollama models from a cloud Kubernetes Cluster](https://inlets.dev/blog/2024/08/09/local-ollama-tunnel-k3s.html). There are a few options here including deploying the LLM as a function, or deploying it as a regular Kubernetes Deployment, either will work, but the Deployment allows for easier Pod spec customisation if you're using a more complex GPU sharing technology like [NVidia Time Slicing](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/latest/gpu-sharing.html#time-slicing-gpus-in-kubernetes).

Both Ollama and Llama.cpp are popular options for running a local model in Kubernetes, and Ollama provides a simple HTTP REST API that can be used from your function's handler. There are a few eaxmples in the above linked article.

In the conclusion, I'll also link to where we've packaged OpenAI Whisper as a function for CPU or GPU accelerated transcription of audio and video files.

## Ok so what about me and my use-case?

So I hear you saying: "Alex I don't do woodwork, and I don't shop at Classic Hand Tools in the UK".

What I wanted to show you was that functions can automate tasks for you in a short period of time, that code doesn't need to be built to last forever. If it's useful for 3 days, 3 months or a year, that's fine, and also means you have a basis that you can adapt for similar work in the future.

The function saved me some money, and gave me a competitive edge over other buyers who would have to keep visiting the website over time.

**Our own real-world automation functions**

In the past we've also created a [Zoom meeting launcher for Discord](https://www.openfaas.com/blog/build-a-serverless-discord-bot/) and a [Google Form to CRM importer](https://www.openfaas.com/blog/import-leads-from-google-forms-to-crm/), both of which are used daily in our team. As I mentioned in the intro, I'd also used OpenFaaS to [help me land Raspberry Pis back when stock was scarce](https://www.openfaas.com/blog/searching-for-raspberrypi/).

**What might you want to monitor?**

* The stock price for Tesla shares, apparently there's a pullback coming in the market. You could monitor a certain stock or share and get right onto your broker or E-Trade account when the price drops. If you use a trading platform for this purpose, you normally have to pay for a premium plan.
* You want to buy a house, but be the first to know if the price drops below a certain threshold. You could be monitoring 3-4 properties you like, they'd all work well for you and you know it's a cold market. So you set a price alert and get a notification, perhaps the website you use doesn't have an API or built-in alerts?
* You're a collector of rare books, and you want to know when a certain book comes up for sale on eBay or AbeBooks.
* There's a pre-release on a new game, and you want to know when it's available for pre-order.
* Check all your registered domains to see if you have old or orphaned sub-domains that need to be deleted

These use-cases are focused on retail and on read-only queries, but you could just as easily run a daily database clean-up job, generate a weekly report of something like [GitHub Actions usage](https://github.com/self-actuated/actions-usage), delete unused resources in your AWS account, or any number of other tasks, if you can write it in code, you can run it on a cron schedule with OpenFaaS.

**Rubbing some LLM magic on it**

In addition to checking for changes in data, if you use something like an LLM, it would be easy to summarise, categorise, or enrich data collected from the web, from product reviews, from database queries, or from local files such as bash history, or remote APIs.

A real-world example of using LLMs to summarise, categorise and alert on data would be Arvid's [Podscan.fm](https://podscan.fm/) product. He first of all uses OpenAI's Whisper model which we covered on the blog previously: [How to transcribe audio with OpenAI Whisper and OpenFaaS](https://www.openfaas.com/blog/transcribe-audio-with-openai-whisper/). The text is then passed into locally deployed Llama3.1 models for summarisation and categorisation, and then alerts are sent to the users for the terms they have defined. One example he gave was of advertisers wanting to see if their brand was mentioned in a podcast, and then to get a summary of the context.

I hope you enjoyed this post, and that it's given you some ideas for your own projects. If you want to learn more about OpenFaaS, faasd, or Kubernetes, then check out my eBooks [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else) and [Everyday Golang](https://openfaas.gumroad.com/l/everyday-golang).
