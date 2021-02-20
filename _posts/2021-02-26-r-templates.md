---
title: "Functions for data science with R templates for OpenFaaS"
description: "Let's bring R to the cloud! Use the power of R for data science serverless-style."
date: 2021-02-26
image: /images/2021-02-r/background.jpg
categories:
 - kubernetes
 - r
 - plumber
author_staff_member: peter
dark_background: true
---

Let's bring R to the cloud! Use the power of R for data science serverless-style.

## Introduction

[R](https://www.r-project.org/) is one of the most popular languages for data science. R's strength is in _statistical computing_ and _graphics_. Its use is most prominent in disciplines relying on classical statistical approaches, such as environmental sciences, public health, finance, just to mention a few. In this post first I will introduce you to the R templates for OpenFaaS. Then I will build a function that pulls data from a COVID-19 API, fits a time series model to the data, and makes a forecast for the future case counts.

> This post is written for existing OpenFaaS users, if you're new then you should [try deploying OpenFaaS](https://docs.openfaas.com/deployment/) and following a tutorial to get a feel for how everything works. Why not start with this course? [Introduction to Serverless course by the LinuxFoundation](https://www.openfaas.com/blog/introduction-to-serverless-linuxfoundation/)

### The R templates

Use the [`faas-cli`](https://github.com/openfaas/faas-cli) and pull R templates:

```bash
faas-cli template pull https://github.com/analythium/openfaas-rstats-templates
```

Now `faas-cli new --list` should give you a list with the available R/rstats templates to choose from (rstats refers to the Twitter hashtag used for R related posts). The templates differ with respect to the Docker base image, the OpenFaaS watchdog type, and the server framework used.

You can choose between the following base images:

- Debian-based `rocker/r-base` Docker image from the [rocker](https://github.com/rocker-org/rocker/tree/master/r-base) project for bleeding edge,
- Ubuntu-based `rocker/r-ubuntu` Docker image from the [rocker](https://github.com/rocker-org/rocker/tree/master/r-ubuntu) project for long term support (uses [RSPM](https://packagemanager.rstudio.com/client/) binaries for faster R package installs),
- Alpine-based `rhub/r-minimal` Docker image from the [r-hub](https://github.com/r-hub/r-minimal) project for smallest image sizes.

> The use of Docker with R is discussed in the original article introducing the [Rocker](https://journal.r-project.org/archive/2017/RJ-2017-065/RJ-2017-065.pdf) project and also in a recent review of the [Rockerverse](https://journal.r-project.org/archive/2020/RJ-2020-007/RJ-2020-007.pdf).

The template naming follows the pattern `rstats-<base_image>-<server_framework>`. Templates without a server framework (e.g. `rstats-base`) use the classic [watchdog](https://github.com/openfaas/faas/tree/master/watchdog) which passes in the HTTP request via STDIN and reads a HTTP response via STDOUT. The other templates use the he HTTP model of the [of-watchdog](https://github.com/openfaas-incubator/of-watchdog) that provides more control over your HTTP responses and is more performant due to caching and pre-loading data and libraries.

R has an ever increasing number of server frameworks available. There are templates for the following frameworks (R packages): [httpuv](https://CRAN.R-project.org/package=httpuv), [plumber](https://www.rplumber.io/), [fiery](https://CRAN.R-project.org/package=fiery), [beakr](https://CRAN.R-project.org/package=beakr), [ambiorix](https://ambiorix.john-coene.com/). Each of these frameworks have their own pros and cons for building standalone applications. But for serverless purposes, the most important aspect of picking one comes down to support and ease of use.

In this post I focus on the [plumber](https://www.rplumber.io/) R package and the `rstats-base-plumber` template. Plumber is one of the oldest of these frameworks. It has gained popularity, corporate adoption, and there are many [examples](https://github.com/rstudio/plumber/tree/master/inst/plumber) and tutorials out there to get you get started.

### Make a new function

Let's define a few variables then use `faas-cli new` to create a new function called `covid-forecast` based on the `rstats-base-plumber` template:

```bash
export OPENFAAS_PREFIX="" # Populate with your Docker Hub username
export OPENFAAS_URL="http://174.138.114.98:8080" # Populate with your OpenFaaS URL

faas-cli new --lang rstats-base-plumber covid-forecast --prefix=$OPENFAAS_PREFIX
```

Your folder now should contain the following files:

```bash
covid-forecast/handler.R
covid-forecast/DESCRIPTION
covid-forecast.yml
```

The `covid-forecast.yml` is the stack file used to configure functions (read more [here](https://docs.openfaas.com/reference/yaml/)). You can now edit the files in the `covid-forecast` folder.

### Time series forecast

I will use [exponential smoothing](https://en.wikipedia.org/wiki/Exponential_smoothing) as a time series forecasting method. The method needs a _time series_ data, that is a series of numeric values collected at some interval. I use here daily updated COVID-19 case counts. The [data source](https://github.com/CSSEGISandData/COVID-19) is the Center for Systems Science and Engineering (CSSE) at Johns Hopkins University. The flat files provided by the CSSE are further processed to provide a JSON API (read more about the [API](https://blog.analythium.io/data-integration-and-automated-updates-for-web-applications/) and its [endpoints](https://github.com/analythium/covid-19#readme), or explore the data interactively [here](https://hub.analythium.io/covidapp/)).

### Customize the function

The `covid-forecast/handler.R` contains the actual R code implementing the function logic. You'll see an example for that below. The dependencies required by the handler need to be added to the `covid-forecast/DESCRIPTION` file. Read more about how the dependencies specified in the `DESCRIPTION` file are installed [here](https://github.com/analythium/openfaas-rstats-templates#customize-your-function).

> See [worked examples](https://github.com/analythium/openfaas-rstats-examples) for different use cases. Read more about the [structure of the templates](template/README.md) if advanced tuning is required, e.g. by editing the `Dockerfile`, etc.

Add the forecast R package to the `covid-forecast/DESCRIPTION` file:

```yaml
Package: COVID
Version: 0.0.1
Imports:
  forecast
Remotes:
SystemRequirements:
VersionedPackages:
```

Change the `covid-forecast/handler.R` file:

```R
library(forecast)

covid_forecast <- function(region, cases, window, last) {
  ## API endpoint for region in global data set
  u <- paste0("https://hub.analythium.io/covid-19/api/v1/regions/", region)
  x <- jsonlite::fromJSON(u) # will throw error if region is not found
  ## check arguments
  if (missing(cases))
    cases <- "confirmed"
  cases <- match.arg(cases, c("confirmed", "deaths"))
  if (missing(window))
    window <- 14
  window <- round(window)
  if (window < 1)
    stop("window must be > 0")
  ## time series: daily new cases
  y <- pmax(0, diff(x$rawdata[[cases]]))
  ## dates
  z <- as.Date(x$rawdata$date)
  ## trim time series according to last date
  if (!missing(last)) {
    last <- min(max(z), as.Date(last))
    y <- y[z <= last]
    z <- z[z <= last]
  } else {
    last <- z[length(z)]
  }
  ## fit exponential smoothing model
  m <- ets(y)
  ## forecast based on model and window
  f <- forecast(m, h=window)
  ## processing the forecast object
  p <- cbind(Date=seq(last+1, last+window, 1), as.data.frame(f))
  p[p < 0] <- 0
  as.list(p)
}

#* COVID
#* @get /
function(region, cases, window, last) {
  if (!missing(window))
    window <- as.numeric(window)
  covid_forecast(region, cases, window, last)
}
```

The R script loads the forecast package, defines the `covid_forecast` function with three arguments:

- `region`: a region slug value for the API endpoint in global data set (see [available values](https://hub.analythium.io/covid-19/api/v1/regions/)),
- `cases`: one of `"confirmed"` or `"deaths"`,
- `windows`: a positive integer giving the forecast horizon in days.

The function gives the following output in R:

```R
covid_forecast("canada-combined", cases="confirmed", window=4)
# $Date
# [1] "2021-02-19" "2021-02-20" "2021-02-21" "2021-02-22"
# $`Point Forecast`
# [1] 2861.592 2871.802 2879.980 2886.529
# $`Lo 80`
# [1] 1694.809 1695.439 1686.198 1667.680
# $`Hi 80`
# [1] 4028.375 4048.165 4073.761 4105.377
# $`Lo 95`
# [1] 1077.152 1072.711 1054.249 1022.461
# $`Hi 95`
# [1] 4646.033 4670.894 4705.710 4750.596
```

The result of the call is a list with six elements, all elements are vectors of length 4 which is our time window. The `Date` element gives the days of the forecast, the `Point Forecast` is the expected value of the prediction, whereas the lower (`Lo`) and upper (`Hi`) prediction intervals represent the uncertainty around the point forecast. The 80% interval (within the `Lo 80` and `Hi 80` bound) and the 95% interval means that the 80% or 95% of the future observations will fall inside that range, respectively. The following plot combines the historical daily case counts and the 14-day forecast for Canada. The point forecast is the blue line, the 80% and 95% forecast intervals are the shaded areas:

![COVID-19 Canada](covid-canada-2021-02-19.png)

The last part of the script defines the Plumber endpoint `/` for a GET request. One of the nicest features of Plumber is that it allows you to create a web API by [decorating the R source code](https://www.rplumber.io/articles/quickstart.html) with special `#*` comments. These annotations will tell Plumber how to handle the requests, what kind of parsers and formatters to use, etc. The current setup will treat the function arguments as URL parameters. The default content type for the response is JSON, thus we do not need to specify it.

```R
#* COVID
#* @get /
function(region, cases, window) {
  if (missing(cases))
    cases <- "confirmed"
  if (missing(window))
    window <- 14
  covid_forecast(region, cases, as.numeric(window))
}
```

Adding default values as part of the handle function arguments makes some of the URL parameters optional. In this case, we need to treat missing parameters as `missing()`. We also need to remember that URL form encoded parameters will be of character type, thus checking type and making appropriate type conversions is necessary (i.e. `as.numeric()` for the `window` argument passed to `covid_forecast`).

### Build, push, and deploy the function

Now you can use `faas-cli up` to build, push, and deploy the COVID-19 forecast function to the OpenFaaS cluster:

```bash
faas-cli up -f covid-forecast.yml
```

You can test the function's deployed instance with curl:

```bash
curl -X GET -G \
  $OPENFAAS_URL/function/covid-forecast \
  -d region=canada-combined \
  -d cases=confirmed \
  -d window=4
```

Or simply by visiting the URL `$OPENFAAS_URL/function/covid-forecast?region=canada-combined&window=4`. The output should be something like this (depending on the day you make the request):

```bash
{
    "Date":["2021-02-19","2021-02-20","2021-02-21","2021-02-22"],
    "Point Forecast":[2861.5922,2871.8024,2879.9795,2886.5285],
    "Lo 80":[1694.8092,1695.4395,1686.1983,1667.6804],
    "Hi 80":[4028.3753,4048.1652,4073.7608,4105.3767],
    "Lo 95":[1077.1515,1072.7106,1054.2487,1022.4611],
    "Hi 95":[4646.0329,4670.8941,4705.7104,4750.596]
}
```

Only the `region` parameter is mandatory, the the other two defaults to
`cases="confirmed"` and `window=14`.
`OPENFAAS_URL/function/covid-forecast?region=us` will be the same as
`OPENFAAS_URL/function/covid-forecast?region=us&window=14`.

The time series itself that was the basis for the forecast, along with the forecast and the associated uncertainty (prediction intervals) for the US would look like the this:

![COVID-19 US](covid-us-2021-02-19.png)

### Wrapping up

In this post I showed how to use the R templates for OpenFaaS. We built a serverless function that consumes data from an external APIs, fits exponential smoothing model, and makes a forecast. The data API with the forecasting function can be added to web applications to provide timely updates on the fly.

The function presented here could be extended to a microservice that might also provide a summary of past case counts in a [dynamic document](https://rmarkdown.rstudio.com/) building on R's powerful authoring tools.

- [Learn about alternative ways of passing parameters to the COVID-19 function](https://github.com/analythium/openfaas-rstats-examples/tree/main/02-time-series-forecast)
- [See the list of available R templates for OpenFaaS](https://github.com/analythium/openfaas-rstats-templates#readme)
- [Check out other R examples with OpenFaaS](https://github.com/analythium/openfaas-rstats-examples)
