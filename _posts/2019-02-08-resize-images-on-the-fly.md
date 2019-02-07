---
title: "How to resize your images on-the-fly with OpenFaaS"
description: In this post Tarun from Iconscout walks us through how his company is leveraging a Serverless approach with Node.js and OpenFaaS to boost image resizing and conversion speeds of up to 4-5x.
date: 2019-02-08
image: /images/resize-on-fly/watching-from-cave.jpg
categories:
  - end-user
  - node
  - tutorial
author_staff_member: alex
dark_background: true
---

I’d like to introduce you to Tarun from Iconscout who is our guest-writer for today’s end-user blog post. Tarun will guide us through how to resize images on the fly with OpenFaaS.

> Author bio: [Tarun Mangukiya](https://twitter.com/tarunmangukiya?lang=en-gb) is co-founder and Product Manager at [Iconscout](https://iconscout.com). He’s working on Frontend, Docker, and Serverless. Iconscout is working to migrate their codebase to serverless over the time. Currently, their all the processing jobs are powered by OpenFaaS.

<img src="/images/resize-on-fly/tarun.jpeg" width="25%" height="25%" />

![](https://iconscout.com/assets/images/iconscout-logo.color.svg)

Since 2016, we at [Iconscout](https://iconscout.com) have been building a platform to solve different types of image resizing and processing problems for our customers. We’re on a mission to bring design assets on hand through the next-generation Design Resource Marketplace and Design Asset Management tools.

Read more: [About Iconscout](https://iconscout.com/about)

Our v1 codebase was developed using PHP and ImageMagick, which served us well at the time. We used VMs to resize images as a batch process and then store them, but in May last year we started to hit the limits of our original approach and found out about OpenFaaS.

See also: [How OpenFaaS Came to Rescue Us](https://medium.com/iconscout/how-openfaas-came-to-rescue-us-ec129518cd46)

Shortly after that [we launched the 2.0 version](https://iconscout.com/features) of our platform where we identified a use case where we needed to give users a feature to download and resize images on-the-fly (by clicking). We also wanted to show thumbnails in different sizes dynamically. In this article, I’ll show you how we’ve implemented resizing the images on the fly with Node.js and deploy it with OpenFaaS. 

So let's get started.

## Pre-requisites for the tutorial

You’ll need:

* [Docker or Docker Desktop](https://www.docker.com/products/docker-desktop)
* OpenFaaS
* faas-cli
* [`npm` and `node`](https://nodejs.org/en/download/)

If you haven’t got OpenFaaS yet, then start here - it only takes a few minutes https://docs.openfaas.com/deployment/ 

## Create a new Node.js function

So, let’s create our function to resize images, we’ll call it image-resize. Instead of the classic Node template, I’ll be using the node10-express template because it offers full control over HTTP headers and higher throughput. That means that we can set the Content-Type when resizing different types of images for our users.

1. Create a new Function

Create a new folder for our work

```bash
$ mkdir -p ~/dev/resizer \
&& cd ~/dev/resizer
```

Now, pull the node10-express template from the OpenFaaS Template Store.

```bash
$ faas-cli template store pull node10-express
```

Create new function from the template

```bash
$ faas-cli new image-resize --lang=node10-express --prefix=USERNAME
```

> Note: Replace USERNAME, with your name on the Docker Hub, or your private registry address.

This will create a new folder named image-resize having handler.js and package.json in it.

```bash
image-resize/handler.js
image-resize/package.json
image-resize.yml
```

The newly generated function is a hello-world style example which we can edit in a moment.

Let’s deploy it and try it out.

```bash
$ faas-cli up -f image-resize.yml
```

We’ll check the deployed function. Then we will continue to write our image resizing functionality.

![Testing the function](/images/resize-on-fly/hello-world.png)

The default sample function serving traffic in the OpenFaaS Portal.

2. Write the resizing logic using sharp

We are going to use the sharp package to resize the images. This is where we would have normally used ImageMagick or GraphicsMagick. This is what the sharp website says about the library:

> The typical use case for this high speed Node.js module is to convert large images in common formats to smaller, web-friendly JPEG, PNG and WebP images of varying dimensions.
> Resizing an image is typically 4x-5x faster than using the quickest ImageMagick and GraphicsMagick settings.

So at Iconscout, having a 4x-5x speed increase was a great move forward for us where we process 10s of thousands of images per day and that’s growing every week.

Now let’s install the sharp package using `npm`.

```bash
$ cd Iconscout~/dev/resizer/image-resize
npm install --save sharp
```
We’ll also need the request package to fetch the specified image from its URL.

```bash
$ cd Iconscout~/dev/resizer/image-resize
$ npm install --save request
```

> Note: When testing this blog post we found that removing the `package-lock.json` which was generated above allowed the code to run as desired in our function. This is an optional step, but recommended.

```bash
$ cd Iconscout~/dev/resizer/image-resize
$ rm package-lock.json
```

Compared to other options I've used in the past, resizing images with sharp is really simple. Here is a link to the documentation: http://sharp.dimens.io/en/stable/api-resize/

For example, to resize input.png to 200px x 200px, you only need the following code:

```js
sharp('input.png')
  .png()
  .resize(200, 200, {
    fit: 'contain'
  })
  .toFile('output.png')
```

Let’s wrap this resizing code to our function.

You can find the full code in this [GitHub repo](https://github.com/tarunmangukiya/openfaas-functions/blob/master/image-resize/handler.js).

The way our function will work, is that the user will supply all the parameters on a query-string, and that means we can even embed resized images pointing directly at the function.

An example URL might be: `http://127.0.0.1:8080/function/image-resize?height=300&width=300&url=https://upload.wikimedia.org/wikipedia/commons/3/36/Hopetoun_falls.jpg`

So we will be fetching the image from the URL and then resizing it to the provided dimensions.

These are all the parameters I’ve added:

* *url:* Public URL of image
* *width:* Number
* *height:* Number
* *download:* Download image rather than showing in browser
* *fit:* Fit the image in the given width & height

See all the other options available in the [sharp api-resize documentation](http://sharp.dimens.io/en/stable/api-resize/).

Update your function with the code from my repo, then deploy the function with the faas-cli.

```bash
$ cd ~/dev/resizer/
$ faas-cli up -f image-resize.yml
```

## Test it out

Now we're ready to do an end-to-end test.

I’ve found a picture of a waterfall on Wikipedia and I want to resize it to 300px x 300px.

https://upload.wikimedia.org/wikipedia/commons/3/36/Hopetoun_falls.jpg

You could also find your own favourite images to try out.

![The resized waterfall image](/images/resize-on-fly/waterfall.png)

Try it out live with your own OpenFaaS where `$OPENFAAS_URL` is the IP address and port of your gateway. On Swarm this is usually `http://127.0.0.1:8080`

`$OPENFAAS_URL/function/image-resize?height=300&width=300&url=https://upload.wikimedia.org/wikipedia/commons/3/36/Hopetoun_falls.jpg`

And of course, here’s my repo, so go give it a star and share it with more people on GitHub. If you have any suggestions or feedback, then feel free to create an issue or PR.

I'll now turn it over to Alex.

Tarun, from Iconscout

## Wrapping up

This is the first in our series of end-user blog posts. I want to thank [Iconscout](https://iconscout.com) for using OpenFaaS and telling us more about the problems they are solving with functions. 

If you are an OpenFaaS end-user, then please feel free to submit a request to have your logo listed on [our homepage](https://docs.openfaas.com/)

Learn more:

* If you’d like to read more about the Iconscout use-case you can read up in this post from Tarun: [How OpenFaaS came to rescue us!](https://medium.com/iconscout/how-openfaas-came-to-rescue-us-ec129518cd46)
* Learn how to solve real problems with serverless functions at your own pace with the [OpenFaaS workshop](https://github.com/openfaas/workshop)
* Star and fork the new [node10-express template on GitHub](https://github.com/openfaas-incuabot/node10-express-template)

