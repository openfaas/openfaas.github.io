---
title: "Finding Raspberry Pis with Raspberry Pis"
description: "Alex shows us how to find Raspberry Pis for sale using a little bit of Golang, a Cron schedule and an existing Raspberry Pi or VM."
date: 2022-08-08
image: /images/2022-searching-raspberry/raspberry-treats.jpg
categories:
- cron
- golang
- tasks
- raspberrypi
author_staff_member: alex
---

Alex shows us how to find Raspberry Pis for sale using a little bit of Golang, a Cron schedule and an existing Raspberry Pi or VM.

## A global shortage strikes again

When I wrote [First Impressions with the Raspberry Pi Zero 2 W](https://blog.alexellis.io/raspberry-pi-zero-2/) in October 2021, there was no shortage of these little devices. Even at launch, supply was plentiful. In the article, you can read why I was so excited about them. Despite having only 512MB of RAM, they had a quad-core 64-bit ARM processor capable of building Go programs in around 20 seconds compared to almost 6 minutes with the previous generation.

What a leap forward. Building a Go program went from 6 minutes (unbearable) to just 20 seconds.

![On the left the original with WiFi and Bluetooth, on the right, the upgraded CPU](https://blog.alexellis.io/content/images/2021/10/rpizeros.jpg)

> On the left the original with WiFi and Bluetooth, on the right, the upgraded CPU

Even in March 2022, the supply of Raspberry Pi was flowing well, and I wrote up how to build a teeny tiny portable cloud server that could run OpenFaaS, fit in your pocket and even run off a battery pack for around a day: [Your pocket-sized cloud with a Raspberry Pi](https://blog.alexellis.io/your-pocket-sized-cloud/)

Combined - I've probably authored several hundred pieces of content on them from blog posts to guides to code samples to container images to eBooks and videos. So I was especially disappointed when I saw the first few people complain of stock shortages. Not for myself, because I have ample supply, but for everyone following and trying to enjoy my tutorials and projects.

That's when I came across "[rpilocator.com](https://rpilocator.com)" by "DPHacks".

It reminded me of a project I wrote in around 2016 when there was a similar shortage of Raspberry Pis. I wrote code to scrape the Shopify APIs of various vendors in the UK, and to aggregate the data in one place: [alexellis/pi_zero_stock](https://github.com/alexellis/pi_zero_stock).

I'd even written a library to display stock count as a number of dots on a tiny screen from Pimoroni: [alexellis/scrollphat-pizero-stock-counter](https://github.com/alexellis/scrollphat-pizero-stock-counter)

![Raspberry Pi Stock](https://pbs.twimg.com/media/CjSbgmkWgAE058e?format=jpg&name=900x900)

Eventually, as you can see from the screenshot, there was so much supply that I clearly didn't need to run the domain anymore.

In this post I'll show you how to build a function with Golang to send alerts to Discord whenever a Raspberry Pi is found in stock. You can deploy OpenFaaS with faasd to a Raspberry Pi you already have, or to a VM such as [a 1-2GB Linode](https://www.linode.com/openfaas?utm_source=openfaas&utm_medium=web&utm_campaign=sponsorship).

And when rpilocator.com is no longer required, perhaps you can use the approach outlined here to write integrations and alerts at work for GitLab, BitBucket, and other internal I.T. systems with important data.

At the end of the post, I'll include links to prior projects and work where we've used OpenFaaS to build integrations between different systems.

## Tutorial

The rpilocator.com website shows us stock levels, and has various filters, so how can we write a function to query it?

In order of efficiency and maintainability:

1) Check for a REST API, and use it, subject to any rate limits parsing the output with [json.Unmarshal](https://pkg.go.dev/encoding/json)
2) Check for an RSS feed, which we can parse with [encoding/xml](https://pkg.go.dev/encoding/xml)
3) Assuming a server-side rendered page, download the HTML using [http.Get](https://pkg.go.dev/net/http) and look for strings
4) Scrape the webpage using a [Puppeteer function written in Node.js](https://www.openfaas.com/blog/puppeteer-scraping/)

Fortunately, whilst there is no REST API, I did find an RSS feed. Looking over its data, it contains alerts with a date and time, but can't be used to query whether there is stock or not.

We can run a function that parses this data, on a regular basis and then sends us a message to Discord or Slack for new events.

We'll need a way to make sure we don't send a message for the same alert twice, or for old ata.

Most OpenFaaS users deploy the project to Kubernetes, but it also works well on its own with a single host. You can set up OpenFaaS on a Raspberry Pi 3 or 4, or Zero W 2 with the [faasd project](https://github.com/openfaas/faasd), or set it up on a cheap cloud instance for ~ 5 EUR/USD per month.

> Did you know? The most complete instructions for faasd are in my eBook: [Serverless for Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else)

## Parsing RSS in Go

We need to parse the RSS feed, so whilst I develop against a new data source and build up a valid model, I will use a local saved copy of the server's response.

Here's a few structs that can be used to model the RSS feed with the fields we need:

```golang
type RSS struct {
	Channel struct {
		Title       string    `xml:"title"`
		Link        string    `xml:"link"`
		Description string    `xml:"description"`
		Item        []RSSItem `xml:"item"`
	} `xml:"channel"`
}

type RSSItem struct {
	Title       string   `xml:"title"`
	Link        string   `xml:"link"`
	Category    []string `xml:"category"`
	Description string   `xml:"description"`
	PubDate     string   `xml:"pubDate"`
	GUID        string   `xml:"guid"`
}

func (r *RSSItem) GetPubDate() (time.Time, error) {
	return time.Parse("Mon, 02 Jan 2006 15:04:05 MST", r.PubDate)
}
```

We can then write a simple control flow like this:

```golang
func main() {

	if err := read("./test.xml"); err != nil {
		panic(err)
	}
}

func read(file string) error {

	var p RSS
	out, err := ioutil.ReadFile("./test.xml")

	if err != nil {
		return err
	}

	if err := xml.Unmarshal(out, &p); err != nil {
		return err
	}

	var found []RSSItem
	for _, item := range p.Channel.Item {
		d, err := item.GetPubDate()
		if err != nil {
			return err
		}
		if time.Since(d) < 24*time.Hour {

			for _, c := range item.Category {
				if c == "UK" {
					found = append(found, item)
				}
			}
		}
	}

	for _, item := range found {
		fmt.Printf("%s - %s\n", item.Title, strings.Join(item.Category, " "))
	}

	return nil
}
```

Then, instead of printing the "found" slice, we would send this via `http.Post` to our Discord server.

After we'd done that, we'd set up [an OpenFaaS cron schedule](https://docs.openfaas.com/reference/cron/), and then some kind of storage so we don't send a message for the same stock alert more than once.

How would a similar program look as a function?

## Setup a Discord webhook

Log into your Discord server and create a new text channel, click Settings and then Integrations, followed by "Copy Webhook URL"

Edit `stock-finder.yml` and add an environment variable for the `discord_url`:

Whilst we're here, let's add a Cron timer to run every 10 minutes too, editing the annotations and topic field.

```yaml
version: 1.0
provider:
  name: openfaas
  gateway: http://127.0.0.1:8080
functions:
  stock-finder:
    lang: golang-middleware
    handler: ./stock-finder
    image: docker.io/alexellis2/stock-finder:0.0.1

    annotations:
      topic: cron-function
      schedule: "*/10 * * * *"

    environment:
      discord_url: https://discord.com/api/webhooks/nleScb5+6WP0Nm/w/986109f965585e33098c1f59adab1e1139886dede0afd971d99658e51e8f510a
```

You can read more about [Cron in OpenFaaS here](https://docs.openfaas.com/reference/cron/)

## Let's write a new function in Go.

Write a function using the golang-middleware template. There are multiple templates for Go for OpenFaaS, but this one is my current favourite because it's so simple and we get full access to the request, along with full control over the response.

You can download the faas-cli with: `arkade get faas-cli`, or with brew.

```bash
faas-cli template store pull golang-middleware

# Change to your Docker Hub or GHCR.io username:
export OPENFAAS_PREFIX=docker.io/alexellis2

faas-cli new --lang golang-middleware stock-finder
```

You should see a `stock-finder/handler.go` file where we write the code for our function, along with `stock-finder.yml` where we set deployment information, like the cron schedule and the version for the container image.

```golang
package function

import (
	"net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {

}
```

Given that the function will be invoked by cron, we can ignore the request. We can probably also ignore the response, since our function will either call Discord with an alert, or do nothing.

We'll build up a message that looks something like this: "Stock UK RPi Zero 2 PiHut.com - 30 minutes ago"

We can't query the exact stock level, or even link directly to the product page, but an alert will give us the context we need and prompt us to open a browser on our phone or workstation. I've also filtered the data to only show stock in the UK. The RSS feed uses the "category" field for the region.

Each of the RSS items has a unique GUID, which I'm using in the code to write out a temporary lock file. This prevents us from getting the same request more than once. As long as the function isn't redeployed, scaled or restarted, then the temporary files will stick around.

Here's my the sample code for my function:

```golang
package function

import (
	"bytes"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/docker/go-units"
)

type RSS struct {
	Channel struct {
		Title       string    `xml:"title"`
		Link        string    `xml:"link"`
		Description string    `xml:"description"`
		Item        []RSSItem `xml:"item"`
	} `xml:"channel"`
}

type RSSItem struct {
	Title       string   `xml:"title"`
	Link        string   `xml:"link"`
	Category    []string `xml:"category"`
	Description string   `xml:"description"`
	PubDate     string   `xml:"pubDate"`
	GUID        string   `xml:"guid"`
}

func (r *RSSItem) GetPubDate() (time.Time, error) {
	return time.Parse("Mon, 02 Jan 2006 15:04:05 MST", r.PubDate)
}

func Handle(w http.ResponseWriter, r *http.Request) {

	rssBytes, err := getBytesFromURL("https://rpilocator.com/feed/")

	if err != nil {
		log.Printf("error loading RSS feed: %s", err)
		http.Error(w, "error loading RSS feed", http.StatusInternalServerError)
		return
	}

	items, err := getStock(rssBytes, "UK", time.Hour*24)

	if err != nil {
		http.Error(w, "error parsing RSS feed", http.StatusInternalServerError)
		return
	}

	discordURL := os.Getenv("discord_url")

	for _, item := range items {
		tmp := os.TempDir()
		path := filepath.Join(tmp, item.GUID)

		if _, err := os.Stat(path); os.IsNotExist(err) {

			// Write a lock file for the GUID to prevent the message from being processed again.
			if err := ioutil.WriteFile(path, []byte{}, os.ModePerm); err != nil {
				log.Printf("Unable to write lock file: %s %s", path, err)
			}

			if err := sendAlert(discordURL, item); err != nil {
				http.Error(w, err.Error(), http.StatusInternalServerError)
				return
			}

			log.Printf("Alert sent to Discord server")
		}
	}
}

type DiscordMsg struct {
	Content string `json:"content"`
}

func sendAlert(discordURL string, item RSSItem) error {
	pubDate, _ := item.GetPubDate()

	// "Stock UK RPi Zero 2 PiHut.com - 30 minutes ago"
	msg := fmt.Sprintf("%s - %s ago", item.Title, units.HumanDuration(time.Since(pubDate)))

	msgBytes, err := json.Marshal(DiscordMsg{Content: msg})
	if err != nil {
		return err
	}

	req, err := http.NewRequest(http.MethodPost, discordURL, bytes.NewBuffer(msgBytes))
	if err != nil {
		return fmt.Errorf("error with Discord URL, check it's a valid format %w", err)
	}

	req.Header.Add("Content-Type", "application/json")

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("error sending alert to Discord %w", err)
	}

	var resBody []byte
	if res.Body != nil {
		defer res.Body.Close()
		resBody, _ = ioutil.ReadAll(res.Body)
	}

	if res.StatusCode != http.StatusNoContent {
		return fmt.Errorf("received non-204 status code from Discord %s, status: %d", resBody, res.StatusCode)
	}

	return nil
}

// getBytesFromURL downloads bytes from a HTTP URL
func getBytesFromURL(url string) ([]byte, error) {

	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}

	var body []byte
	if res.Body != nil {
		defer res.Body.Close()
		body, _ = ioutil.ReadAll(res.Body)
	}

	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d, body: %s", res.StatusCode, string(body))
	}

	return body, nil
}

// getStock parses an RSS feed, then filters by category and
// an age duration field
func getStock(body []byte, category string, age time.Duration) ([]RSSItem, error) {

	var rssItems []RSSItem
	var p RSS

	if err := xml.Unmarshal(body, &p); err != nil {
		return rssItems, err
	}

	var found []RSSItem
	for _, item := range p.Channel.Item {
		d, err := item.GetPubDate()
		if err != nil {
			return rssItems, err
		}

		if time.Since(d) < age {

			for _, c := range item.Category {
				if c == category {
					found = append(found, item)
				}
			}
		}
	}

	return found, nil
}
```

From there, you need to build your function on a PC using the `faas-cli publish --reset-qemu -f stock-finder.yml` command, then you can deploy it with `faas-cli deploy -f stock-finder.yml`.

Make sure you set OPENFAAS_URL and run faas-cli login first

```bash
# You can leave off the platforms that you don't need to deploy to.
faas-cli publish \
  --reset-qemu \
  --platforms linux/amd64,linux/arm64,linux/arm/7 \
  -f stock-finder.yml

# Deploy with the configuration in stock-finder.yml
faas-cli deploy -f stock-finder.yml
```

You'll receive a URL to test your function manually, since it doesn't take an argument, or need to produce a response, hitting its endpoint manually will be just like when it's invoked from Cron.

How can you tell it really worked, if there was no data?

[Head over to the RSS feed](https://rpilocator.com/feed/), and look for the date and country filter for a recent stock alert, then edit your code and run `faas-cli publish/deploy` again before invoking it manually. That'll send you an alert, then you can redeploy your program with your preferred region and alert age setting.

![Results being sent to my Discord server](/images/2022-searching-raspberry/results.png)

If you run into any issues, be sure to check the `faas-cli logs` command, or [check the troubleshooting guide](https://docs.openfaas.com/deployment/troubleshooting/).

You can find out more about the Go templates in OpenFaaS here: [Docs: Create new functions](https://docs.openfaas.com/cli/templates/)

## Wrapping up

In a relatively short period of time, we put together some code in Go which can be deployed to a Raspberry Pi, to find other Raspberry Pis. I hope you'll try it out and grow your family of tiny servers.

If at some point in the future, rpilocator.com is no longer available, you'll still have the lessons learned in this article that you can use to apply at work with systems like Jenkins, GitLab and other internal I.T. systems.

Bear in mind that some systems are rate limited, and you may have to account for that in your testing by using captured or simulated responses.

Further work:

* For the function to be invoked on the 10-minute schedule, you'll need to deploy the cron-connector as described in [Serverless For Everyone Else](https://openfaas.gumroad.com/l/serverless-for-everyone-else)
* You may want to edit the "UK" filter that I added, and optionally, extend the 24 hour window. Why not read the value from [os.Getenv](https://pkg.go.dev/os) or [os.LookupEnv](https://pkg.go.dev/os) and add it to stock-finder.yml so it's easier to configure?
* I'd also encourage you to use a database table or Redis to store which GUIDs have been alerted on or processed already. I cover how to do this in the [Premium Edition of Everyday Golang](https://gumroad.com/l/everyday-golang).
* Why not figure out the vendor from the text in the URL and send along a URL to Discord, so you can get to the product page even quicker?

You may also like my our work with handling events and forwarding them to Discord, or running other custom logic.

* [GitHub Sponsors webhook receiver and Discord forwarder, written in Node.js](https://github.com/alexellis/sponsors-functions)
* [Email your Gumroad customers and get notifications via Discord](https://github.com/alexellis/gumroad-custom-workflow)
* [How I built Good First Issue bot with OpenFaaS Cloud](https://www.openfaas.com/blog/good-first-issue/)
* [Tracking Stripe Payments with Slack and faasd](https://myedes.io/stripe-serverless-webhook-faasd/)
* [How to integrate with GitHub the right way with GitHub Apps](https://www.openfaas.com/blog/integrate-with-github-apps-and-faasd/)
