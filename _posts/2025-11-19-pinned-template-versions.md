---
title: "Introducing Template Version Pinning for Functions"
description: "As of version `0.18.0` of the faas-cli, you can now pin templates to a specific version via the stack.yaml file for more reproducible builds and to avoid unexpected changes."
date: 2025-11-19
author_staff_member: alex
categories:
- templates
- kubernetes
- serverless
dark_background: true
# image: "/images/2025-11-pinned-template-versions/background.png"
hide_header_image: true
---

As of version `0.18.0` of the faas-cli, you can now pin templates to a specific version via the stack.yaml file for more reproducible builds and to avoid unexpected changes.

**Why pin a template?**

Pinning a version of a template, just like any other dependency can shield your functions from unexpected changes, and make it easier to test variations before rolling them out more broadly.

A template such as `golang-middleware` may change for any number of reasons, whether that's the underlying Go version, the HTTP server that's hidden from users, or even the base image used for runtime.

You may also be experimenting and change a template called `python3-http` from using an Alpine Linux base to using Debian. All your older functions that may rely on specific apk packages can remain on an older version of the template, until you're ready to upgrade. Newer functions can use a newer version.

You may also need to enable certain logging or debug options, but don't want to impact your existing functions. Creating a new named branch would mean you could switch out one or more functions to use that new version.

**How does it work?**

You can pin a template in three ways:

* `lang: golang-middleware@1.0.0` - a release tag
* `lang: golang-middleware@inproc` - a branch name
* `lang: golang-middleware@sha-af599e` - a specific commit hash prefixed with `sha-` with a short or long SHA format

Finally, if you do not pin a version, then the latest version will be fetched from git whenever it is not available in the local `./template` folder.

**How do I fetch pinned templates?**

The first way, is to create a new template and specify the version in the `new` command:

```bash
faas-cli new --lang golang-middleware@1.0.0 my-function
```

This will create a new function in the current directory, and use the `golang-middleware` template at version `1.0.0`.

For existing functions, you can use the above `@` syntax and update the existing YAML:

```diff
functions:
  my-function:
-   lang: golang-middleware
+   lang: golang-middleware@1.0.0
```

**A note on the default templates repository**

There is a so called *default* templates repository that is used whenever you run `faas-cli template pull` without specifying a repository or language. We don't think this makes much sense going forward, since both the Go and Python templates are now in different repositories.

If you want to explore the available templates, use the store commands instead:

```bash
faas-cli template store list
```

## So should you start pinning template versions now?

As a general rule of thumb, pinning versions of all assets you use from Docker base images, to npm packages, to Go modules, to Python packages, to any other dependency you use in your functions, setting a stable and known version of a template is an industry standard practice.

It's not required, just as a Dockerfile can use a `:latest` tag, templates can be used without any version suffix. Without pinning, you'll always get the latest version of the template including any fixes and updates to the base image, which will keep your CVE scanner happy. But at the same time, if an unexpected change breaks assumptions made by your functions, it could cause unexpected issues down the line.

To find the release of any template in the store, find its Git repository and visit the Releases page, find the latest release or SHA in the HEAD branch, and update your stack.yaml file to use that version.

For instance: `faas-cli template store describe python3-http` will show you the URL for the repository, where you can find the latest Release tag, or if there hasn't been a release for a while, the latest SHA in the default branch (usually `master`).

## Wrapping up

Whilst this may look like a simple change, it affects a large number of code paths, and whilst we have strived to minimise impact, there may be some edge cases that we have missed. If your CI pipeline breaks for any reason, you can pin the release binary of faas-cli to the last version before this feature was introduced: [`0.17.8`](https://github.com/openfaas/faas-cli/releases).

The majority of the work has been carried out via the following [pull request](https://github.com/openfaas/faas-cli/pull/1012) and tested by the full time team.

For those of us that do start pinning our templates, we must also remember to update them over time, to the latest Release as it becomes available, or to the latest SHA available in the default branch.

For questions, comments, and suggestions reach out via your support channel of choice whether that's Slack, the Customer Community on GitHub, or Email.

