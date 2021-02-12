---
title: "Learn how to share and promote your work as an engineer"
description: "Learn tips and techniques on how to share and promote your work as an engineer"
date: 2021-02-12
image: /images/2021-02-11-sharing/background.jpg
categories:
 - automation
 - socialmedia
 - sharing
 - marketing
author_staff_member: alex
dark_background: true

---

Learn tips and techniques on how to share and promote your work as an engineer.

## Introduction to social sharing

I first started writing blog posts for [blog.alexellis.io](https://blog.alexellis.io) about 5-6 years ago and had no idea how to promote my content. That meant that any traffic that landed on my articles would have been from search engines or a link that I'd shared with a colleague. I didn't even have an account on Twitter. As an engineer, I didn't know much about marketing, but now have a [Twitter following of around 18k people](https://twitter.com/alexellisuk), millions of impressions each month, and hundreds of thousands of hits across a number of blogs and publications.

> Sharing and promotion is a skill, and one that needs to be practised over time. You can learn quite a lot from books, but knowing what to do, and creating results can be two very different things. You need to be prepared to take a chance, to try things and to learn from your mistakes. There's also a few tips and techniques that you can apply today, to improve engagement overnight.

Wherever you are in your social media and technical marketing journey, I hope you'll learn a little about sharing your work on social media, and about link previews. You'll learn what changes you need to make to your HTML, or your GitHub repos and what to expect when you share your work on different channels. I'll share how you can automate social sharing images, and how to avoid the trap of self-promotion.

I'll also give you a couple of book recommendations and let you know my favourite tools and websites along the way, and point you at a couple of examples from the community, who have learned and applied these techniques.

## Why should we care about social sharing?

The phrase "if you build it, they will come" is as old as time. However when it comes to publishing guides, tutorials, or product landing pages on the Internet, there is a huge amount of competition for users.

When sharing a link on a social sharing platform like Slack, Twitter or LinkedIn, a preview will be generated and shown to any users that see the item in their feed.

The original way to do this is through [The Open Graph Protocol](https://ogp.me/)

* `og:title` - The title of your object as it should appear within the graph, e.g., "The Rock".
* `og:type` - The type of your object, e.g., "video.movie". Depending on the type you specify, other properties may also be required.
* `og:image` - An image URL which should represent your object within the graph.
* `og:url` - The canonical URL of your object that will be used as its permanent ID in the graph, e.g., "https://www.imdb.com/title/tt0117500/".

Here's an example from one of my web portals that I sometimes share on social media.

```html
    <meta property="og:title" content="The Treasure Trove - weekly Insiders&#39; Updates from Alex Ellis">
    <meta property="og:image" content="https://faasd.exit.openfaas.pro/function/trove/static/card.jpg">
```

I'll share most effective channels I've found for sharing content and some tips for each.

### Sharing on Twitter

[Twitter](https://twitter.com/) - a social media platform with a feed. You can post, and others can reply to your content or share it with their network.

Pros:
* Easy to begin
* You can build a following over time
* Brands and other connections can help your content reach more users

Cons:
* Requires time to curate a network and build a following
* People often comment without reading content

You should configure your blog with OG tags for a title, description and image, so that you get a high quality preview. There are additional tags that Twitter prefers to use, so if your content could be shared on Twitter it's probably worth adding.

```html
    <meta property="og:title" content="The Treasure Trove - weekly Insiders&#39; Updates from Alex Ellis">
    <meta property="og:image" content="https://faasd.exit.openfaas.pro/function/trove/static/card.jpg">
    <meta property="og:description" content="Follow Alex&#39;s journey into independent Open Source and business week by week and get exclusive offers.">

    <meta property="twitter:title" content="The Treasure Trove - weekly Insiders&#39; Updates from Alex Ellis">
    <meta property="twitter:card" content="summary_large_image">
    <meta property="twitter:description" content="Follow Alex&#39;s journey into independent Open Source and business week by week and get exclusive offers.">
```

Fortunately, you can preview your site easily with the [Twitter card validator](https://cards-dev.twitter.com/validator).

![Preview](/images/2021-02-11-sharing/preview.png)

> A preview of my [Treasure Trove](https://faasd.exit.openfaas.pro/function/trove/)

### Sharing on Hacker News

[Hacker News](https://news.ycombinator.com) - a link sharing site, with comments and rankings.

Pros:
* If your content reaches and stays on the front page, then you can gain notoriety overnight. Sid Sijbrandij, the CEO of GitLab often recounts how posting on Hacker News got GitLab their first few thousand users.
* You can reach a broad audience in a short period of time
* You can gain customers, sales, and a following if you have enough luck, market fit and timing

Cons:
* There are official and peer moderators who may flag your content and remove it
* It's random - you can work very hard on something very cool, and get no traffic from it at all
* Learning what works takes a considerable amount of time, and still involves luck
* You can't post just anything here - people are very picky
* The comments are often unfiltered with ad hominem comments being common
* Someone will undervalue your work with "I could have built this in a weekend"

No special social sharing is required here, but note that you must post the verbatim title of your blog post.

A technique that can help you get the best out of Hacker News is to fire and forget. Or have someone else read the comments for you and act as an intermediary.

What about Reddit? I consider Reddit to be on par with Hacker News. A similar approach is required, and there can be a similar unfiltered tone to messages and comments.

### Sharing on LinkedIn

[LinkedIn](https://linkedin.com) - is a social network for professionals. You create a profile with your education and career history, then network with others.

Pros:
* Comments tend to be more respectful and constructive than on Hacker News or Twitter
* Keep in touch with ex-colleagues
* Find technical resources for online learning and training workshops
* Posting good quality content will get engagement. Short video clips and events or talks work well

Cons:
* Frequent connection requests from people you don't know
* Frequent unsolicited outreach from recruiters for jobs and projects that are a poor match for your skills and expertise

![LinkedIn Preview](/images/2021-02-11-sharing/li-preview.png)

LinkedIn has its own social sharing preview called the [Post Inspector](https://www.linkedin.com/post-inspector/)

### Sharing GitHub repositories

Did you know that you can customise how your GitHub repositories look when you share them on social media?

Compare the following:

![Plain](/images/2021-02-11-sharing/registry-creds.png)

No social image or customisation

![arkade](/images/2021-02-11-sharing/arkade.png)

A social sharing image - the project logo padded with whitespace in a 16:9 format.

![faasd](/images/2021-02-11-sharing/faasd.png)

A social sharing image created to suit the 16:9 format by a designer.

Go to the Settings page for your GitHub repository and navigate to Social preview, then Upload image.

![Upload an image](/images/2021-02-11-sharing/upload.png)

You can then use the Twitter card preview to check how it looks.

### Creating your own images for cards and sharing

When I first started doing this, I used InkScape or Gimp on my Linux computer, later on I tried the Preview app on my Mac, but never had anything that I was happy with. As a developer, visual design is not my forte.

My main recommendation here is [Canva](https://canva.com)

It has good templates for everything from wedding invites, to business cards to YouTube thumbnails.

### Finding Stock photography

I once heard that by including a title image for a blog post, the conversion rate of people clicking on it increases.

There are two main sources I use for free stock images, both are very similar: [pexels](https://pexels.com) and [unsplash.com](https://unsplash.com)

More recently, [Andy Randall at Kinvolk](https://twitter.com/andrew_randall) opened my eyes to paid stock imagery and I don't think I'll go back. I asked him what he thought of a new landing page, and he said something like: "I've seen those guys 1000 times before, was it from Pexels? They have a good range, but most of their photos are cheesy."

The main site I've used is [istockphoto.com/](https://www.istockphoto.com/) by Getty Images. You can expect to pay around 10-30 USD per image, and you should check the terms and conditions when you purchase. If you run a business, you can log this as a marketing spend against your company tax.

### Changing your mind and fine-tuning social previews

Social sharing images often get cached and may never be refreshed, so it's important that you know what to do when you make changes.

Simply go to the social preview page for the platform like LinkedIn or Twitter and enter the URL. Once you see a preview, it will usually replace any cached copies with the new preview.

### The catch 22 of self-promotion

In some communities, it is frowned upon to promote your own work, which when you consider what that means, makes growing a following rather challenging. So don't be surprised if you've spent several months building a piece of informative content, to then see it thrown out by a moderator for "self-promotion"

So what should you do if you face push-back?

Think about the frequency that you post, whether you are also posting other people's content that is of value, or only your own to a channel. Consider whether you have friends or colleagues post for you. If you do share your own work, try sending the first message to the discussion or comments section with a brief introduction to why you're sharing it and what it's about.

### Feedback and engagement

Finally, if at all possible, don't take any of the comments or push-back you get too personally. In a face to face conversation, engineers who may shy away from confrontation or sharing opinions, tend to feel a boldness, and frankness that could be considered out of place.

Try not to look at sharing as transaction, but as you participating within or building a community. In sales, there is an abbreviation "WIIFM" - what's in it for me? Never tire of asking that question. Why should your reader care?

If you're sensing that users are not fully engaging with your content, or your hard work is falling on deaf ears, you may want to take a look at the structure of your post. Have you given something for visual learners? A diagram. Have you given a "Why" for decision makers? Have you given next steps, or a conclusion for people to understand how to apply what you've shared?

I've found the [4MAT model](https://4mat4learning.com.au/what-is-4mat/) developed by Bernice McCarthy to be effective for structuring presentations and articles.

## Wrapping up

I hope that next time you write a blog post, an open source project, or launch a product, you may be able to refer back to this post and make sure that your content looks great wherever you share it.

To learn more about developer marketing and developer experience, feel free to reach out about our [Storytelling services](https://www.openfaas.com/consulting/). You can also [book an hour with me](https://calendly.com/alexellis/) for a review of your landing page or sharing strategy.

If you are happy to learn and experiment on your own, then you may also like: [Traction: How Any Startup Can Achieve Explosive Customer Growth](https://amzn.to/3tQInFQ). I got a lot out of this and it helped me formalise some of the things I'd learned through experience.

Over the past 18 months, I've written up about [my own personal journey of building an independent software business](https://kubernetespodcast.com/episode/116-independent-open-source/) and community. Each week I send out an update on my work, along with links to other articles, tutorials, and a regular feature on topics like this blog post. You can subscribe [via GitHub Sponsors](https://faasd.exit.openfaas.pro/function/trove).

### Generating social sharing images

You can also generate your own social sharing images [through OpenFaaS](https://www.openfaas.com/blog/puppeteer-scraping/). From as little as 5-10 USD / mo you can host a function that can be used to generate social media images with the [faasd project](https://github.com/openfaas/faasd). We have even started to see community members doing just that.

Over the past few weeks I've been helping a young entrepreneur called Peter to understand how to generate images wth this technique. It was exciting to see him go on to launch a small product leveraging what he learnt. Peter was even [featured in TechCrunch](https://techcrunch.com/2021/02/09/clublink-offers-a-better-clubhouse-link-for-sharing-on-social-media/) yesterday.

![faasd generating social media images](/images/2021-02-11-sharing/socialgen.jpg)

I've also been encouraged to see a small, independent business called [Bannerbear](https://www.bannerbear.com) apply a similar technique to the above using AWS Lambda to run their headless Chrome instances.

In my previous tutorial: [Web scraping that just works with OpenFaaS with Puppeteer](https://www.openfaas.com/blog/puppeteer-scraping/), I show that using faasd and Docker can be much simpler and faster than AWS Lambda for headless chrome.
