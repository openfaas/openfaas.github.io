---
title: "A Deep Dive into Golang for OpenFaaS Functions"
description: "Alex takes a deep dive into Golang for OpenFaaS functions and shows off a new feature from Go 1.18 that improves the experience with IDEs."
date: 2022-04-13
image: /images/2022-react-app/pen-design.jpg
categories:
- golang
- go
- faas
- http
- rest
author_staff_member: alex
dark_background: true

---

Alex takes a deep dive into Golang for OpenFaaS functions and shows off a new feature from Go 1.18 that improves the experience with IDEs.

In this article, I'll outline the three templates we have for Go, when you should each one, and some of the recent changes we've made to make local development better with VSCode thanks to a new feature in [Go 1.18](https://go.dev/blog/go1.18).

> If you feel uncomfortable seeing the word "golang" and believe the language is called "go", I'm with you. However we must do these things to help out Google's search engine.

## A journey of 60 months

OpenFaaS has been a journey of 60 months, and if you're new to our community or want a refresher, check out my GopherCon keynote: [Zero to OpenFaas in 60 months](https://www.youtube.com/watch?v=QzwBmHkP-rQ)

I write most of my own functions in either Go or Node.js, so improvements like this are not only important to me, but to the community of customers and open source users that have found value in what we've built together.

The first version of OpenFaaS was called `faas` and didn't have any form of templates. You just built a binary that worked with STDIN and STDOUT, then added our Classic Watchdog into the container. At that point, you could run it locally and use curl to access it over port 8080 or deploy it via the OpenFaaS gateway.

This template was naturally called `go`.

I'll show you what the `go` template looks like and the two more modern versions that you should be using instead. We'll maintain this template for historical reasons.

The Classic Watchdog still has some relevancy for languages and CLIs that do not support a HTTP framework. You can learn more about this story and how OpenFaaS scales functions in: [Dude, where's my coldstart?](/blog/what-serverless-coldstart/)

## The Classic Go template

You can scaffold a new function with this template by running a command like:

```bash
faas-cli new --prefix docker.io/alexellis2 \
    --lang go print-pi
```

Here's how the `print-pi/handler.go` file looks:

```go
package function

import (
        "fmt"
)

// Handle a serverless request
func Handle(req []byte) string {
        return fmt.Sprintf("Hello, Go. You said: %s", string(req))
}
```

Headers are read from environment variables so `Authorization: Bearer X` is accessed via `os.GetEnv("Http_Authorization`). The request is a slice of bytes, which means you can handle binary data, but the response must be a string, which meant you couldn't return binary data.

The classic template is available in the default templates repository [openfaas/templates](https://github.com/openfaas/templates.git).

However, things have changed and evolved over the past 60 months and we've moved on. The template is maintained because we don't want to break your production environment.

## The Golang HTTP template

The newest Go templates are in a new repository [openfaas/golang-http-template](https://github.com/openfaas/golang-http-template) offer two styles, one is similar to the classic template, but uses HTTP instead and gives you full access over the HTTP request and body. The other is a Go middleware which gives just about as much flexibility as you could get from a function.

You can locate these templates by running `faas-cli store list` or `faas-cli template store pull`

```bash
faas-cli template store list | grep go

faas-cli template store pull golang-http

faas-cli new --prefix docker.io/alexellis2 \
    --lang golang-http homepage
```

Should you ever want a specific version of a template, you can check the [releases page](https://github.com/openfaas/golang-http-template/releases) to find a tag, you can add a `#RELEASE` or `#BRANCH` to the end of a Git URL such as : `faas-cli template pull https://github.com/openfaas/golang-http-template#0.7.0`

Here's what the golang-http handler in `./homepage/handler.go` looks like:

```go
package function

import (
        "fmt"
        "net/http"

        handler "github.com/openfaas/templates-sdk/go-http"
)

// Handle a function invocation
func Handle(req handler.Request) (handler.Response, error) {
        var err error

        message := fmt.Sprintf("Body: %s", string(req.Body))

        return handler.Response{
                Body:       []byte(message),
                StatusCode: http.StatusOK,
        }, err
}
```

All the Go templates now support adding a number of static files for use at runtime.

## Add a static HTML file to the function

Let's add an index.html file and serve it to any HTTP requests we get.

```bash
mkdir -p homepage/static/
```

We'll use the [starter template from Bootstrap 4.3](https://getbootstrap.com/docs/4.3/getting-started/introduction/)

Save `homepage/static/index.html`:

```html
<!doctype html>
<html lang="en">
  <head>
    <!-- Required meta tags -->
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">

    <!-- Bootstrap CSS -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@4.3.1/dist/css/bootstrap.min.css" integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T" crossorigin="anonymous">

    <title>Hello, world!</title>
  </head>
  <body>
    <h1>Hello, world!</h1>

    <!-- Optional JavaScript -->
    <!-- jQuery first, then Popper.js, then Bootstrap JS -->
    <script src="https://code.jquery.com/jquery-3.3.1.slim.min.js" integrity="sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/popper.js@1.14.7/dist/umd/popper.min.js" integrity="sha384-UO2eT0CpHqdSJQ6hJty5KVphtPhzWj9WO1clHTMGa3JDZwrnQq4sF86dIHNDz0W1" crossorigin="anonymous"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@4.3.1/dist/js/bootstrap.min.js" integrity="sha384-JjSmVgyd0p3pXB1rRibZUAYoIIy6OrQ6VrjIEaFf/nJGzIxFDsf4x0xIM+B07jRM" crossorigin="anonymous"></script>
  </body>
</html>
```

Now let's make our code serve up the file in response to any request:

```go
package function

import (
	"net/http"
	"os"

	handler "github.com/openfaas/templates-sdk/go-http"
)

// Handle a function invocation
func Handle(req handler.Request) (handler.Response, error) {
	data, err := os.ReadFile("./static/index.html")

	if err != nil {
		return handler.Response{
				StatusCode: http.StatusInternalServerError,
				Body:       []byte(err.Error())},
			err
	}

	return handler.Response{
		StatusCode: http.StatusOK,
		Header: http.Header{
			"Content-Type": []string{"text/html"},
		},
		Body: data,
	}, nil
}
```

After running `faas-cli build -f homepage.yml`, you can either deploy the function to OpenFaaS or just test it out locally on your own machine using Docker.

```bash
docker run -p 8081:8080 --rm -ti docker.io/alexellis2/homepage:latest
```

Then head over to `http://127.0.0.1:8081`

![Testing out the function on my local machine](/images/2022-04-golang-deep-dive/docker-local.png)

> Testing out the function on my local machine without deploying it.

This makes for a rapid way to test changes before publishing an image.

## How do I get this thing to run in OpenFaaS?

For the next example I want to introduce you to the `golang-middleware` template, which is available in the same repository as `golang-http`.

This template provides the absolutely maximum compatibility with SDKs and frameworks written for the Go ecosystem.

Let's take a quick look at it:

```bash
faas-cli template store pull golang-middleware

faas-cli new --prefix docker.io/alexellis2 \
    --lang golang-middleware http-printer
```

Here's what `http-printer/handler.go` looks like:

```go
package function

import (
        "fmt"
        "io"
        "net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {
        var input []byte

        if r.Body != nil {
                defer r.Body.Close()

                body, _ := io.ReadAll(r.Body)

                input = body
        }

        w.WriteHeader(http.StatusOK)
        w.Write([]byte(fmt.Sprintf("Body: %s", string(input))))
}
```

If you squint, you can see that this looks just like a standard HTTP server in Go, however we abstract away all the server management and leave you with a generic handler that traps all HTTP requests.

Let's make it dump out all the HTTP request information:

```go
package function

import (
	"fmt"
	"io"
	"net/http"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	var input []byte

	if r.Body != nil {
		defer r.Body.Close()

		body, _ := io.ReadAll(r.Body)

		input = body
	}

	w.WriteHeader(http.StatusOK)

	fmt.Fprintf(w, "Method: %s\n", r.Method)
	fmt.Fprintf(w, "QueryString: %s\n", r.URL.Query())
	fmt.Fprintf(w, "Path: %s\n", r.URL.Path)

	for k, v := range r.Header {
		fmt.Fprintf(w, "%s=%s\n", k, v)
	}

	fmt.Fprintf(w, "\nBody: %s\n", string(input))
}
```

Once again, we'll build it locally and test it without deploying it properly, so we can move quickly.

```bash
faas-cli build -f http-printer.yml

docker run -p 8081:8080 --rm -ti docker.io/alexellis2/http-printer:latest
```

Try accessing the URL in different ways:

```bash
# curl --data-binary @/etc/os-release http://127.0.0.1:8081

Method: POST
QueryString: map[]
Path: /
User-Agent=[curl/7.68.0]
Accept=[*/*]
Content-Type=[application/x-www-form-urlencoded]
Accept-Encoding=[gzip]

Body: NAME="Ubuntu"
VERSION="20.04.4 LTS (Focal Fossa)"
ID=ubuntu
ID_LIKE=debian
PRETTY_NAME="Ubuntu 20.04.4 LTS"
VERSION_ID="20.04"
HOME_URL="https://www.ubuntu.com/"
SUPPORT_URL="https://help.ubuntu.com/"
BUG_REPORT_URL="https://bugs.launchpad.net/ubuntu/"
PRIVACY_POLICY_URL="https://www.ubuntu.com/legal/terms-and-policies/privacy-policy"
VERSION_CODENAME=focal
UBUNTU_CODENAME=focal

# curl -X DELETE http://127.0.0.1:8081/customer/1

Method: DELETE
QueryString: map[]
Path: /customer/1
User-Agent=[curl/7.68.0]
Accept=[*/*]
Accept-Encoding=[gzip]

Body: 

# curl --basic --user admin http://127.0.0.1:8081 
Enter host password for user 'admin':
Method: GET
QueryString: map[]
Path: /
Accept-Encoding=[gzip]
User-Agent=[curl/7.68.0]
Accept=[*/*]
Authorization=[Basic YWRtaW46YWRtaW4=]

Body: 
```

You can also open up a browser and you'll see the user-agent being sent over.

```
Method: GET
QueryString: map[]
Path: /
Sec-Fetch-User=[?1]
User-Agent=[Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.75 Safari/537.36]
Connection=[keep-alive]
Sec-Ch-Ua=[" Not A;Brand";v="99", "Chromium";v="100", "Google Chrome";v="100"]
Sec-Ch-Ua-Mobile=[?0]
Sec-Fetch-Dest=[document]
Accept-Encoding=[gzip, deflate, br]
Sec-Ch-Ua-Platform=["Linux"]
Sec-Fetch-Mode=[navigate]
Sec-Fetch-Site=[none]
Upgrade-Insecure-Requests=[1]
Accept=[text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9]
Accept-Language=[en-GB,en-US;q=0.9,en;q=0.8]

Body: 
```

So it turns out that there are a whole bunch of different pieces of metadata that you can use to run different parts of your function's handler.

## Adding a sub-package to your function

Naturally, when our code starts to grow, or gain unique responsibilities, we may want to extract it into a separate package and folder. The most common example I can think of is when you want to build a few HTTP handlers and keep them separate from the main package.

```bash
faas-cli template store pull golang-middleware

faas-cli new --prefix docker.io/alexellis2 \
    --lang golang-middleware http-handlers
```

Copy over index.html from our earlier step into the `static` folder:

```bash
mkdir -p http-handlers/static
```

Create `http-handlers/static/index.html`

Create a handlers folder and `homepage.go`:

```bash
mkdir -p http-handlers/handlers
```

Edit: `http-handlers/handlers/homepage.go`

```go
package handlers

import (
	"net/http"
	"os"
)

func MakeHomepageHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		data, err := os.ReadFile("./static/index.html")
		if err != nil {
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}

		w.Write(data)
	}
}
```

Then add a separate handler for an API that returns a JSON entry for a fictional user-profile. The profile will contain common social media links.

Edit: `http-handlers/handlers/api.go`

```go
package handlers

import (
	"encoding/json"
	"net/http"
)

type UserProfile struct {
	Homepage string `json:"homepage"`
	Twitter  string `json:"twitter"`
	GitHub   string `json:"github"`
	Gumroad  string `json:"gumroad"`
}

var user UserProfile

func init() {
	user = UserProfile{
		Homepage: "https://alexelis.io",
		Twitter:  "https://twitter.com/alexelisuk",
		GitHub:   "https://github.com/alexellis/",
		Gumroad:  "https://store.openfaas.com/",
	}
}

func MakeAPIHandler() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		data, err := json.Marshal(user)
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			w.Write([]byte(err.Error()))
			return
		}

		w.Write(data)
	}
}
```

Now we need to reference these two sub-packages from our main handler:

```go
package function

import (
	"fmt"
	"handler/function/handlers"
	"net/http"
	"strings"
)

var routes = map[string]func(http.ResponseWriter, *http.Request){}

func init() {
	routes["/api"] = handlers.MakeAPIHandler()
	routes["/"] = handlers.MakeHomepageHandler()
}

func Handle(w http.ResponseWriter, r *http.Request) {
	if strings.HasPrefix(r.URL.Path, "/api") {
		routes["/api"](w, r)
		return
	} else if strings.HasPrefix(r.URL.Path, "/") {
		routes["/"](w, r)
		return
	}

	w.WriteHeader(http.StatusNotFound)
	fmt.Fprintf(w, "URL found")
}
```

Note that we imported our sub-package by writing: `handler/function/handlers`, where the sub-package is prefixed with `handler/function` - this is required instead of a more canonical path lke `github.com/alexellis/...` due to the way we abstract way the internal HTTP server. Prior to Go 1.18 this would have caused issues for intellisense and VSCode, however it now renders just as expected.

This is due to some work done by [Lucas Roesler to introduce Go Workspaces](https://github.com/openfaas/golang-http-template/pull/70).

If you peak inside the template folder, you'll find a `go.work` file that looks like this:

```
go 1.18

use (
        .
        ./function
)
```

![Thanks to Go workspaces](/images/2022-04-golang-deep-dive/workspaces.png)

> Thanks to Go workspaces VSCode works as it should for our custom paths.

Build the function and try it out:

```bash
faas-cli build -f http-handlers.yml

docker run -p 8081:8080 --rm \
    -ti docker.io/alexellis2/http-handlers:latest
```

Then test it out:

```bash
# curl -s http://127.0.0.1:8081/api | jq
{
  "homepage": "https://alexelis.io",
  "twitter": "https://twitter.com/alexelisuk",
  "github": "https://github.com/alexellis/",
  "gumroad": "https://store.openfaas.com/"
}

# curl -s -i http://127.0.0.1:8081/ | head -n 9
HTTP/1.1 200 OK
Content-Length: 1224
Content-Type: text/html; charset=utf-8
Date: Wed, 13 Apr 2022 10:57:57 GMT
X-Duration-Seconds: 0.000302

<!doctype html>
<html lang="en">
  <head>
```

## Using an external Go module

Using an external Go module is just a case of defining the import and then running `go mod tidy` / `go mod build` in the folder next to the `handler.go` file.

```bash
faas-cli template store pull golang-middleware

faas-cli new --prefix docker.io/alexellis2 \
    --lang golang-middleware generate-jwt
```

Edit `generate-jwt/handler.go`:

```go
package function

import (
	"net/http"
	"time"

	jwt "github.com/golang-jwt/jwt/v4"
)

func Handle(w http.ResponseWriter, r *http.Request) {
	if r.Body != nil {
		defer r.Body.Close()
	}

	t := jwt.New(jwt.GetSigningMethod("HS256"))
	t.Claims = jwt.RegisteredClaims{
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour * 48)),
		Audience:  jwt.ClaimStrings{"http://127.0.0.1:8080/function/generate-jwt"},
	}

	signingKey := []byte("secret")
	res, err := t.SignedString(signingKey)

	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusOK)
	w.Write([]byte(res))
}
```

Do this part just once:

```bash
cd generate-jwt
go mod tidy
go build
cd ../
```

Then:

```bash
faas-cli build -f generate-jwt.yml

curl -s -i http://127.0.0.1:8081/

HTTP/1.1 200 OK
Content-Length: 177
Content-Type: text/plain; charset=utf-8
Date: Wed, 13 Apr 2022 11:34:38 GMT
X-Duration-Seconds: 0.000727

eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOlsiaHR0cDovLzEyNy4wLjAuMTo4MDgwL2Z1bmN0aW9uL2dlbmVyYXRlLWp3dCJdLCJleHAiOjE2NTAwMjI0Nzh9.i0832aql-dTTvtikePlZbA-U71JVAiZ8CppDJelmwmI
```

## Wrapping up and taking things further

The main changes that benefitted us with Go 1.18 was the ability to use Go workspaces to fix the local development workflow. That said, it's also given us a chance to walk through various patterns for using Go with OpenFaaS and I hope you've found that useful.

### Did you learn something?

If you learned something today, then you can go even deeper with Go unit-testing, Prometheus metrics, databases connections and concurrency in [my eBook Everyday Go](https://store.openfaas.com/l/everyday-golang).

In the Premium Edition of the book, I dedicated a whole chapter over to patterns and techniques that I've used and seen customers using with OpenFaaS in production. That includes unit-testing, iterating locally, different settings for staging/production and accessing databases.

<blockquote class="twitter-tweet" data-conversation="none"><p lang="en" dir="ltr">One of the latest editions now covers how to write functions with Go, and you can take any of the samples from the previous chapters and embed them within a &quot;Handle&quot; method to run them on <a href="https://twitter.com/openfaas?ref_src=twsrc%5Etfw">@openfaas</a> / Cloud Run or an EC2 instance. <a href="https://t.co/ACgsC32UwG">pic.twitter.com/ACgsC32UwG</a></p>&mdash; Alex Ellis (@alexellisuk) <a href="https://twitter.com/alexellisuk/status/1487724807865176070?ref_src=twsrc%5Etfw">January 30, 2022</a></blockquote> <script async src="https://platform.twitter.com/widgets.js" charset="utf-8"></script>

You can also follow me on Twitter [@alexellisuk](https://twitter.com/alexellisuk)

