---
title: "Import leads from Google Forms into your CRM with functions"
description: "Sometimes you just need to import data from a Google Form, here's how you can do it with OpenFaaS in a couple of hours."
date: 2023-03-02
image: /images/2023-03-forms-to-pipedrive/deals.png
categories:
- crm
- customeracquisition
- leads
- automation
- golang
- automation
- googleforms
author_staff_member: alex
---

Sometimes you just need to import data from a Google Form, here's how you can do it with OpenFaaS in a couple of hours.

Once it's up and running, you can forget about opening that linked Google Sheet, or copying and pasting emails into your Customer Relationship Management (CRM) tool like [Freshworks](https://freshworks.io) or [Pipedrive](https://pipedrive.com).

You may be using Google Forms for any number of reasons, like booking calls with potential customers, collecting abstracts for a conference, holding a contest or a give-away, or maybe for a survey.

## I did it manually until it was painful

As an entrepreneur and a small business owner, I know how much there is that is expected of us. How much we have to remember, processes we need to run, hats we need to wear. It's a lot. And many times, turning to spreadsheets can help us keep track of things.

A couple of years ago I purchased a Pipedrive subscription for the business and even though I'm not some kind of "sales guy" with on earnings targets, or a quote to meet, I still use it to keep track of leads, opportunities, and customers.

Clearly, as a the founder of a serverless framework, you'd have expected me to have every aspect of the business running through OpenFaaS, right?

But I tended to be more pragmatic than that, leaning on [XKCD's cartoon: Is it worth the time?](https://xkcd.com/1205/).

[![https://imgs.xkcd.com/comics/is_it_worth_the_time.png](https://imgs.xkcd.com/comics/is_it_worth_the_time.png)](https://xkcd.com/1205/)

One thing I learned with sales, is how quickly you need to follow up with people after they ask for a call.

OpenFaaS Community Edition (CE) is free and nobody has to pay for that to use it, even commercially. So I get a lot of people expecting to pay nothing contact me for a meeting, who ask for pricing and have no intention of buying anything. But there are also a bunch of people who have identified OpenFaaS on their short-list of solutions, and believe in the brand, and want to have a serious conversation about how we can help.

You just can't leave those people hanging.

That's one of the reasons that I bought into a CRM, and secondly why I finally automated importing leads from a Google Form.

![Screenshot of Pipedrive, a CRM aimed at start-ups](/images/2023-03-forms-to-pipedrive/deals.png)
> Screenshot of [Pipedrive](https://pipedrive.com), a CRM aimed at start-ups

## How it works

Interested parties fill out a form for a call with the OpenFaaS Ltd team, that Form data is synced by a built-in feature of Google Workspace into a Google Sheet. And that's how have ran things for years.

Now, I can open up the sheet and enter the word "import" in a "status" column, and the function we'll see today will import that customer into Pipedrive.

![Import workflow with OpenFaaS](/images/2023-03-forms-to-pipedrive/forms-flow.png)
> The import process that I used to do manually, is no longer tedious.

I wrote my function in Go, but you can pick any language you like and use our existing templates via `faas-cli template store list`, or write one of your own.

Since I wanted to ship this code in a short period of time, I've not focused on abstractions, or making it into a library, or anything like that. It works, and I can iterate on it as needed. And I've actually got a second copy of the function running, with slightly different business logic, that imports sales leads for [actuated.dev](https://actuated.dev) instead.

Here are the main parts:

* Google's Sheets API library - [https://pkg.go.dev/google.golang.org/api/sheets/v4](https://pkg.go.dev/google.golang.org/api/sheets/v4)
* My own simple SDK for Pipedrive - [https://pkg.go.dev/github.com/alexellis/pipedrive-sdk](https://pkg.go.dev/github.com/alexellis/pipedrive-sdk)
* An OpenFaaS SDK for reading secrets - [https://pkg.go.dev/github.com/openfaas/go-sdk](https://pkg.go.dev/github.com/openfaas/go-sdk)

The function itself is invoked via cron on a schedule, and if someone were to discover the URL and to invoke it, nothing bad would happen.

It's designed to be idempotent, so if you run it twice, it won't import any more data than it needs to. It also has a lock on it to prevent it from running more than one invocation at a time through the environment variable `max_inflight: 1`.

First things first:

* Create a Google Form
* Within the Form click "View in Sheets"
* Open up the spreadsheet and copy out the ID portion of the URL `https://docs.google.com/spreadsheets/d/ID_HERE/edit` - you'll need this to reference the sheet in your function
* Then, find the range of fields you want to import. In my version of the code, I collect a range i.e. columns A:O then convert that into a list of items in HTML, which is what Pipedrive accepts.

![View in sheets](/images/2023-03-forms-to-pipedrive/view-in-sheets.png)

Next, you will need credentials for the Google Sheets API.

* Create a new Service Account from the Google Cloud Console
* Create a JSON credential for the Service Account and download it - this will be mounted as secret into your function
* Then, copy the email address of the Service Account, open your spreadsheet and just like you'd share it with a human user, share it with the Service Account email address

At this point, you can deploy a function and read a range of fields out of the spreadsheet.

How many of those rows to import is entirely up to you. You can qualify out rows that don't have a company email address, or where they are a student, or don't seem like they would become a buyer.

What you do with that data is entirely up to you, but I've imported the data into Pipedrive, and shortly after I'll send them an email from the Pipedrive UI and start a conversation.

## The code sample

This code sample will need a few tweaks to work for you. You may also want to send the data elsewhere than Pipedrive.

You could send it to a private Slack or Discord channel via an incoming webhook for instance.

I've made no real attempts to polish this code, because that would just get in your way. Unless you have my same Google Form, and use Pipedrive in the exact same way, you'll have to change the function anyway. You may even prefer Python or Node.js so check out my note at the end of the article.

```go
package function

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"regexp"

	pipedrivesdk "github.com/alexellis/pipedrive-sdk"
	gosdk "github.com/openfaas/go-sdk"
	option "google.golang.org/api/option"
	sheets "google.golang.org/api/sheets/v4"
)

const (
	CompanyHeader  = "Company's Legal Name"
	EmailHeader    = "Email address"
	FullNameHeader = "Your full name"
	StatusHeader   = "Status"
	queryRange     = "A:O"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	if r.Body != nil {
		defer r.Body.Close()
	}

	sheetID := os.Getenv("sheet_id")
	pipeDriveOrg := os.Getenv("pipedrive_org")

	pipeDriveAPIKey, err := gosdk.ReadSecret("pipedrive-api-key")
	if err != nil {
		log.Printf("Error reading pipedrive-api-key: %s", err)
		http.Error(w, "Unable to read secrets", http.StatusInternalServerError)
		return
	}

	credsData, err := gosdk.ReadSecret("google-sales-sheets-api-key")
	if err != nil {
		log.Printf("Error google-sales-sheets-api-key: %s", err)
		http.Error(w, "Unable to read secrets", http.StatusInternalServerError)
		return
	}

	pipedrive := pipedrivesdk.NewPipeDriveClient(http.DefaultClient, pipeDriveAPIKey, pipeDriveOrg)

	ctx := context.Background()

	sheetsService, err := sheets.NewService(ctx,
		option.WithCredentialsJSON([]byte(credsData)))
	if err != nil {
		log.Printf("Error creating sheets service: %s", err)
		http.Error(w, "Unable to create sheets service", http.StatusInternalServerError)
		return
	}

	getCall := sheetsService.Spreadsheets.Values.Get(sheetID, queryRange)

	res, err := getCall.Do()
	if err != nil {
		log.Printf("Error getting range %s in sheet: %s, %s", queryRange, sheetID, err)
		http.Error(w, "Unable to query sheets range", http.StatusInternalServerError)
		return
	}

	if res == nil {
		log.Println("No data received from spreadsheet service, check range and spreadsheet ID")
		w.WriteHeader(http.StatusNoContent)
		return
	}

	log.Printf("Getting range %s in sheet: %s status: %d", queryRange, sheetID, res.HTTPStatusCode)

	headers := []string{}
	entries := []map[string]string{}
	for rowNum, row := range res.Values {
		entry := map[string]string{}
		if rowNum > 0 {
			entries = append(entries, entry)
		}

		for colNum, col := range row {
			if rowNum == 0 {
				headers = append(headers, col.(string))
			} else {
				entry[headers[colNum]] = col.(string)
			}
		}
	}

	processEntries(headers, entries, pipedrive, sheetsService, sheetID)
}
```

The processEntries function doesn't try to do anything clever, it won't even return a HTTP error code if there's a problem creating an entry in the CRM.

Why? It will get run again later, and there are always logs available to review with `faas-cli logs function-name`.

```go
// processEntries iterates over the entries and imports them into pipedrive,
// where the status is set to "import"
func processEntries(headers []string, entries []map[string]string,
	pipedrive *pipedrivesdk.PipeDriveClient, sheetsService *sheets.Service, sheetID string) {

	matchAZ := regexp.MustCompile(`[A-Z]`)
	for entryIndex, entry := range entries {

		s := Submission{entry: entry}
		if entry[StatusHeader] == "import" {
			log.Printf("Importing record %s\n", entry[EmailHeader])

			columnIndex := -1
			for i, v := range headers {
				if v == StatusHeader {
					columnIndex = i
					break
				}
			}

			if columnIndex == -1 {
				log.Println("could not find status column to update the row")
				return
			}
			columnAlpha := toAlphabetIndex(columnIndex)
			matched := matchAZ.Match([]byte(columnAlpha))
			if !matched {
				log.Println("Can't match A-Z with columnAlpha ", columnAlpha)
				continue
			}

			// zero indexed in the slice, but we have to add back two to the row number
			// one for the header, one for the zero offset, since sheets are 1-offset
			sheetRow := entryIndex + 2

			statusRangeRef := fmt.Sprintf("%s%d", columnAlpha, sheetRow)
			rowStatus := "importing"
			updateCall := sheetsService.Spreadsheets.Values.Update(sheetID, statusRangeRef, &sheets.ValueRange{
				MajorDimension: "ROWS",
				Range:          statusRangeRef,
				Values: [][]interface{}{
					{
						rowStatus,
					},
				},
			})

			updateCall.ValueInputOption("USER_ENTERED")
			res, err := updateCall.Do()
			if err != nil {
				log.Println(err)
				continue
			}

			log.Printf("Updating sheet %s=%s, status: %d\n", statusRangeRef, rowStatus, res.HTTPStatusCode)

			org, err := findOrg(pipedrive, s.GetOrganisation())
			if err != nil {
				log.Println(err)
			}

			if org == -1 {
				org, err = createOrg(pipedrive, s.GetOrganisation())
				if err != nil {
					log.Println(err)
				}
				log.Printf("Created org: %d for: %s\n", org, s.GetOrganisation())
			}

			person, err := getPerson(pipedrive, s.GetEmail())
			if err != nil {
				log.Println(err)
			}
			if person == -1 {
				person, err = createPerson(pipedrive, s.GetName(), s.GetEmail(), org)
				if err != nil {
					log.Println(err)
				}
				log.Printf("Created person: %d for: %s\n", person, s.GetEmail())
			}

			deal, err := pipedrive.CreateDeal(s.GetOrganisation()+" (OpenFaaS Pro)", org, person)

			if err != nil {
				log.Println(err)
			}

			log.Printf("Created deal: %s (%d)\n", deal.Data.Title, deal.Data.ID)

			notes := buildNotes(s, headers)

			noteRes, err := pipedrive.CreateDealNote(notes, deal.Data.ID)
			if err != nil {
				log.Println(err)
			}
			log.Printf("Created note on deal: %s (%d)\n", deal.Data.Title, noteRes.Data.ID)

			rowStatus = "imported"

			updateCall = sheetsService.Spreadsheets.Values.Update(sheetID, statusRangeRef, &sheets.ValueRange{
				MajorDimension: "ROWS",
				Range:          statusRangeRef,
				Values: [][]interface{}{
					{
						rowStatus,
					},
				},
			})

			updateCall.ValueInputOption("USER_ENTERED")
			res, err = updateCall.Do()
			if err != nil {
				log.Println(err)
				continue
			}
			log.Printf("Updating sheet %s=%s, status: %d\n", statusRangeRef, rowStatus, res.HTTPStatusCode)
		}
	}
}

// toAlphabetIndex converts an integer to the corresponding
// letter in the alphabet.
// If the entryIndex is 1, then the result is "A", when the
// entryIndex is 26, then the result is "Z" and so on.
func toAlphabetIndex(entryIndex int) string {
	// 65 is the ASCII value for "A", the offset input starts at 0
	return string(rune(entryIndex + 65))
}
```

The notes in Pipedrive need to be formatted as HTML, so I take all the fields in the form and make them into a pretty HTML list with `<li>` tags.

```go
// buildNotes uses the headers slice to enumerate values, since it has a stable order
func buildNotes(s Submission, headers []string) string {
	noteOuter := "<html><body><h2>Notes imported from Google Form</h2><ul>%s<ul></body></html>"
	noteInner := ""

	for _, h := range headers {
		if v, ok := s.entry[h]; ok {
			noteInner += fmt.Sprintf("<li><b>%s</b>: %s</li>", h, v)
		} else {
			noteInner += fmt.Sprintf("<li><b>%s</b>: %s</li>", h, "-")
		}
	}

	return fmt.Sprintf(noteOuter, noteInner)
}
```

Then we have a few miscellaneous functions to find, create and update Pipedrive entities.

```go
func getPerson(pipeDrive *pipedrivesdk.PipeDriveClient, email string) (int, error) {
	personID := -1

	res, err := pipeDrive.SearchPersonByEmail(email)
	if err != nil {
		return personID, err
	}

	if res.Data.Items != nil && len(res.Data.Items) > 0 {
		if res.Data.Items[0].ResultScore > 0.2 {
			personID = res.Data.Items[0].Item.ID
		}
	}

	return personID, nil
}

func createPerson(pipeDrive *pipedrivesdk.PipeDriveClient, name, email string, org int) (int, error) {
	personID := -1

	createRes, err := pipeDrive.CreatePerson(name, email, org)
	if err != nil {
		return personID, err
	}
	personID = createRes.Data.ID

	return personID, nil
}

func createOrg(pipedrive *pipedrivesdk.PipeDriveClient, orgName string) (int, error) {
	orgID := -1
	createRes, err := pipedrive.CreateOrg(orgName)
	if err != nil {
		return -1, err
	}
	orgID = createRes.Data.ID

	return orgID, nil
}

func findOrg(pipedrive *pipedrivesdk.PipeDriveClient, orgName string) (int, error) {
	orgID := -1

	res, err := pipedrive.SearchOrg(orgName)
	if err != nil {
		return orgID, err
	}

	if res.Data.Items != nil && len(res.Data.Items) > 0 {
		if res.Data.Items[0].ResultScore > 0.2 {
			log.Printf("Found probably match: %v\n", res)
			orgID = res.Data.Items[0].Item.ID
		}
	}

	return orgID, nil
}
```

I created a helper to get the values from the right place in the spreadsheet.

```go
type Submission struct {
	entry map[string]string
}

func (s *Submission) GetUsage() string {
	return s.entry[UsageHeader]
}

func (s *Submission) GetEmail() string {
	return s.entry[EmailHeader]
}

func (s *Submission) GetName() string {
	return s.entry[FullNameHeader]
}

func (s *Submission) GetOrganisation() string {
	return s.entry[CompanyHeader]
}
```

I had to write a function to map from the row index and column index returned from Google's API back to a spreadsheet range. By creating `handler_test.go`, I was able to do that in a very short period of time:

```go
package function

import "testing"

func Test_toAlphabetIndex_ZeroIsA(t *testing.T) {
	got := toAlphabetIndex(0)
	want := "A"
	if got != want {
		t.Errorf("got %q want %q", got, want)
	}
}

func Test_toAlphabetIndex_2IsC(t *testing.T) {
	got := toAlphabetIndex(2)
	want := "C"
	if got != want {
		t.Errorf("got %q want %q", got, want)
	}
}
```

Here's the stack.yaml file:

```yaml
version: 1.0
provider:
  name: openfaas

functions:
  openfaas-form-import:
    lang: golang-middleware
    handler: ./openfaas-form-import
    image: ${REGISTRY}/$OWNER/openfaas-form-import:${TAG}
    annotations:
      topic: cron-function
      schedule: "0 */3 * * *"       # Every 3 hours
    environment:
      max_inflight: 1
      read_timeout: 120s
      write_timeout: 120s
      upstream_timeout: 120s
      sheet_id: SHEET_ID_FROM_URL
      pipedrive_org: PIPEDRIVE_ORG_NAME
    secrets:
    - pipedrive-api-key
    - google-sales-sheets-api-key
```

To create the two secrets, you can use the OpenFaaS CLI:

```bash
faas-cli secret create google-sales-sheets-api-key \
 --from-file $HOME/iam-55je402ca.json

faas-cli secret create pipedrive-api-key \
 --from-file $HOME/pipedrive-api-key.txt 
```

## Deployment / updating

Why not write a main.go file and scp it over to a VM?

You absolutely could, and when I wrote this code, I started writing a main.go, before moving it over to the handler interface.

[OpenFaaS functions are easy to build in GitHub Actions](https://docs.actuated.dev/examples/openfaas-publish/) or GitLab, because they're just container images.

You can then do a secure remote deployment over HTTPS using the OpenFaaS CLI.

```bash
export OPENFAAS_URL=https://openfaas.example.com

faas-cli login --username admin --password $OPENFAAS_PASSWORD
faas-cli deploy
```

Just store `OPENFAAS_PASSWORD` as a secret for the repository.

You can get the logs for your function or view its invocation history with `faas-cli describe` and `faas-cli logs`.

## Wrapping up

There are a bunch of SaaS tools like Zapier, Make (aka Integromat), IFTTT, Pipedream and others, and they can be convenient. Especially if you don't write code for a living, or are short on time. But at the same time, they often need an upgraded plan to function in basic ways. Finally, when you need to do something out of the box, you just can't. Things like different languages, keeping the code in git, testing locally, more bespoke authentication needs, extra cron schedules, event triggers, etc.

Where can you run your new function?

That's where OpenFaaS Community Edition or Pro comes in. You have the ultimate flexibility to write in any language and to trigger by webhook, cron, events. And you can drop your code into a private GitHub / GitLab repo and publish the functions whenever you change them.

* If you run Kubernetes, then the [OpenFaaS Community Edition](https://docs.openfaas.com) uses very few resources and is easy to set up.

    This is a popular option, and we've seen millions of pulls from the Docker Hub, along with 33k+ GitHub stars across the OpenFaaS project repos.

* If you are looking for really low overheads, then you can can't go far wrong with faasd that runs on a single VM
    
    "faasd" was designed to be installed on a cloud host and requires very little maintenance once installed. That's where I am running the two functions I mentioned in this post. Even a 10-15 USD / mo [Linode Nanode](https://www.openfaas.com/images/sponsors/linode.svg) or [DigitalOcean Droplet](https://m.do.co/c/2962aa9e56a1) is enough to run [faasd](http://github.com/openfaas/faasd).

faasd has its own eBook, and if you're more of a JavaScript developer than a Go developer, you'll find lots of practical code examples that you can use to write your own automations and functions: [Serverless for Everyone Else](https://store.openfaas.com/l/serverless-for-everyone-else)

It's a great way to get started with serverless, and to start automating your business.

Let me know if you have any questions or comments.

You may also like:

[Exploring Serverless Use-cases from Companies and the Community](https://www.openfaas.com/blog/exploring-serverless-live/)

<a href="https://www.youtube.com/watch?v=mzuXVuccaqI"><img src="https://camo.githubusercontent.com/544dffaf339a4ff44439db1c14cd953de385640b99231688f8a49db61294a02e/68747470733a2f2f7062732e7477696d672e636f6d2f6d656469612f457378444745505841415968724c4f3f666f726d61743d6a7067266e616d653d6c61726765" width="60%" alt="Exploring Serverless Use-cases from Companies and the Community"></a>