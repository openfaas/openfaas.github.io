---
title: "Adding Managed Services to Serverless with Crossplane and OpenFaaS"
description: In this post Dan from Crossplane explains how to easily deploy and consume managed services alongside your serverless functions on Kubernetes using Crossplane and OpenFaaS.
date: 2020-03-30
image: /images/2020-03-30-managed-services-serverless/cover.png
categories:
  - guest
  - serverless
  - kubernetes
  - crossplane
  - data
author_staff_member: alex
dark_background: true
---

I’d like to introduce you to Dan Mangum who is our guest-writer for today’s end-user blog post. Dan will be recapping a [recent live stream](https://youtu.be/XphQgB87U-s) where we showed off two demos using Crossplane with OpenFaaS to deploy and consume managed services alongside serverless functions.

> Author bio: [Dan Mangum](https://twitter.com/hasheddan) is a software engineer at [Upbound](https://upbound.io/) where he works on the open source [Crossplane](https://crossplane.io/) project. He also serves on the Kubernetes release team, and is an active contributor to the Kubernetes project and multiple other open source efforts. He hosts a biweekly live stream show, [The Binding Status](https://www.youtube.com/playlist?list=PL510POnNVaaYFuK-B_SIUrpIonCtLVOzT), focused on extending Kubernetes, building Crossplane, and shaping the future of cloud-native computing.

<img src="/images/2020-03-30-managed-services-serverless/mangum.jpg" width="25%" height="25%" />

Kubernetes is often seen as complex and confusing for new and seasoned users alike. While it provides a wealth of tools and functionality for infrastructure operators, developers frequently struggle to navigate the complexity to just get their application running. OpenFaaS eases that burden by providing the fastest way to get your code running on Kubernetes.

However, while OpenFaaS addresses the problem of getting your code to production, providing data for your functions is a different beast entirely.

# The Traditional Workflow

Typically, the provisioning of managed services such as databases, queues, and caches follows a much different cycle than the deploying of an application. You must either use a cloud provider console, an infrastructure as code tool, or run the service directly on your Kubernetes cluster. Each of these methods have tradeoffs:

- **Cloud Provider Console**: While probably the most developer-friendly route, using a user interface to deploy your managed services is tedious, not easily reproducible, and decoupled from the deployment of your functions on OpenFaaS.
- **Infrastructure as Code / APIs**: Nearly every cloud provider supplies an API and set of SDKs that are used by infrastructure as code tools to make it possible to version control your infrastructure provisioning and configuration. This is a *massive* improvement over manual, ad-hoc provisioning, but typically requires a user executing command from their local machine, or manually editing detailed configuration every time they want a new service deployed. Once again, this process is also decoupled from deploying your functions on OpenFaaS.
- **Running Data Services on Kubernetes Directly**: This path brings you closer to managing both your application code and data services with the same tools and workflow. However, it requires that you shun the high SLAs of experienced cloud providers in favor of administrating complex databases, caches, and queues yourself. This is generally a suitable option for large, experienced organizations, or applications that are not mission critical, but can impose significant burden on companies that are not in the business of running data services.

# The Ideal World

Ideally, we would want to take the benefits of each of the options above while stripping away the negative consequences of pursuing any one of them directly. While I don't believe in silver bullets, Crossplane goes a long way in accomplishing this mission. Let's take a quick look at some of the principles of the project:

- **Integration with the Kubernetes API**: Crossplane runs on Kubernetes and defines its data using [CustomResourceDefinitions](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/). However, this does not mean that you ever have to interact with Kubernetes concepts like Deployments, Pods, and Services. Instead, it means that those features are available to you, but you can choose any other project, such as OpenFaaS, and achieve compatibility right out-of-the-box. Crossplane and OpenFaaS were not built specifically to integrate, but because they both are able to talk the language of Kubernetes, they can be used together seamlessly.
- **Separation of Concern**: Unfortunately, it is a logical fallacy to say that we want full configurability of a system, while also requesting that we don't have to deal with the gritty details. However, it is reasonable to request that different groups of people interact with the system at different levels. Infrastructure operators are likely interested in turning all the knobs that a service exposes and explicitly defining what configurations are and are not allowed in their organizations. Developers, on the other hand, are interested in being supplied with appropriate infrastructure on-demand and are less concerned with the underlying implementation details. In short, developers want as smooth of an experience with managed services as OpenFaaS gives them with their code.
- **Portability of Applications**: As part of the aforementioned separation of concern, Crossplane makes it possible to infrastructure owners to shift the services relied upon by applications without developers needing to know about or adapt to a change. As we will see in the [Comment Vibes](https://github.com/alexellis/comment-vibes) demo, there are guides for using Digital Ocean or GCP for the Postgres database, and the functions are agnostic about which is chosen. Similarly, Crossplane is agnostic about whether a claim for a Postgres database is satisfied by a GCP CloudSQL instance or a Potgres offering on some other platform. 

Now that we have an idea of the value that Crossplane provides when used alongside OpenFaaS, let's run through our two demos for tangible examples.

# Demo 1: S3 Bucket Image Uploader ([source](https://github.com/crossplane/tbs/tree/master/episodes/13/assets))

![Deploy Crossplane with Arkade](/images/2020-03-30-managed-services-serverless/deploy-crossplane.png)

We [started](https://youtu.be/XphQgB87U-s?t=1521) the demo by installing Crossplane with [arkade](https://github.com/alexellis/arkade), the simplest way to get Crossplane up and running in your Kubernetes cluster.

```console
arkade install crossplane
```

We followed up by installing the Crossplane [AWS Provider](https://github.com/crossplane/provider-aws) and supplying credentials for Crossplane to communicate with the AWS API. You can find documentation on how to do this for your cloud provider of choice in the Crossplane [documentation](https://crossplane.io/docs/v0.9/configure.html). After that, we created an AWS `S3BucketClass` resource in our cluster. This is a custom resource type that Crossplane provides to allow an infrastructure administrator to define configuration for an [Amazon S3 bucket](https://aws.amazon.com/s3/) that is available for use by developers. This class exposes the same fields that you would find in the AWS console, or when using any infrastructure as code tool. Our configuration for this demo looks as follows:

```yaml
apiVersion: storage.aws.crossplane.io/v1alpha3
kind: S3BucketClass
metadata:
  name: s3bucket-standard
  labels:
    tbs: episode14
specTemplate:
  writeConnectionSecretsToNamespace: crossplane-system
  versioning: false
  cannedACL: private
  region: us-west-2
  localPermission: ReadWrite
  providerRef:
    name: aws-provider
  reclaimPolicy: Delete
```

Developers can now request object storage with a `Bucket` claim, which is not specific to AWS, but can be satisfied by the `S3Bucket` type as it is a form of object storage. Before we got to that, we went ahead and installed OpenFaaS, once again using arkade:

```console
arkade install openfaas
```

After [logging in and accessing the OpenFaaS UI](https://docs.openfaas.com/deployment/kubernetes/), it was [time to actually provision](https://youtu.be/XphQgB87U-s?t=1911) our `Bucket`. We could see that once the S3 bucket was created on AWS, our `Bucket` object reported `Status: Bound` and its connection information was propagated in the form of a Kubernetes `Secret` to the `openfaas-fn` namespace:

```console
kubectl apply -f bucket.yaml
```

![Deploy Bucket](/images/2020-03-30-managed-services-serverless/deploy-bucket.png)

Now all that was left to do was deploy our OpenFaaS function to allow us to upload images and view the bucket contents. Using the [faas-cli](https://github.com/openfaas/faas-cli), this [was as easy as](https://youtu.be/XphQgB87U-s?t=2359) `faas-cli deploy -f tbs.yml`, and our functions [immediately appeared](https://youtu.be/XphQgB87U-s?t=2371) in the OpenFaaS UI.

![Bucket Functions in OpenFaaS](/images/2020-03-30-managed-services-serverless/bucket-funcs.png)

We then used [curl] to post an image the uploader function:

```console
curl -X POST -F 'file=@test-image.jpg' http://127.0.0.1:8080/function/upload
```

And it [became viewable](https://youtu.be/XphQgB87U-s) at the `http://127.0.0.1:8080/function/ui` endpoint for our bucket image UI function.

![View Bucket Images](/images/2020-03-30-managed-services-serverless/view-bucket-images.png)

Feeling adventurous, we even publicly exposed the function endpoints using [inlets](https://github.com/inlets/inlets). Watch [the remainder of the video](https://youtu.be/XphQgB87U-s?t=2539) to see how we did it!

# Demo 2: Comment Vibes App ([source](https://github.com/alexellis/comment-vibes))

Already having Crossplane and OpenFaaS open and running, why not move on to another interesting application? Alex had put together the [Comment Vibes](https://github.com/alexellis/comment-vibes) app to show how OpenFaaS functions can be used with Github and a Postgres database to display emoji reactions in comments. The application was [originally demoed](https://www.youtube.com/watch?v=r4mEF8rtXWo) by Alex at an online meetup by provisioning a Digital Ocean database using the cloud provider console. However, we wanted to show how we could simplify this workflow using Crossplane.

After setting up the Crossplane [GCP Provider](https://github.com/crossplane/provider-gcp), we created a `CloudSQLInstanceClass` with configuration for a Postgres database on GCP. The contents of the configuration looked like this:

```yaml
apiVersion: database.gcp.crossplane.io/v1beta1
kind: CloudSQLInstanceClass
metadata:
  name: standard
  labels:
    app: comment-vibes
specTemplate:
  writeConnectionSecretsToNamespace: crossplane-system
  forProvider:
    databaseVersion: POSTGRES_11
    region: us-west2
    settings:
      tier: db-custom-1-3840
      dataDiskType: PD_SSD
      dataDiskSizeGb: 10
      ipConfiguration:
        ipv4Enabled: true
        authorizedNetworks:
          - value: "0.0.0.0/0" # whitelist all IPs so we can access from local machine
  providerRef:
    name: gcp-provider
  reclaimPolicy: Delete
```

As you can see, a Postgres database is a bit more complicated than an object storage bucket, but this level of detail is once again confined to the infrastructure operator, while the developer simply creates a `PostgreSQLInstance` claim that can be satisfied by the `CloudSQLInstanceClass`. The contents of the claim are significantly less verbose:

```yaml
apiVersion: database.crossplane.io/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: comment-vibes-db
  namespace: openfaas-fn
spec:
  classSelector:
    matchLabels:
      app: comment-vibes
  writeConnectionSecretToRef:
    name: pgconn
  engineVersion: "11"
```

After creating both the `CloudSQLInstanceClass` and the `PostgreSQLInstance` claim, GCP began to provision the database. This [was reflected](https://youtu.be/XphQgB87U-s?t=3190) in the state of the `CloudSQLInstance` object in our Kubernetes cluster, as it reported back `PENDING_CREATE`:

![GCP Pending Create](/images/2020-03-30-managed-services-serverless/gcp-pending-create.png)

After a short period of time, the Postgres database was fully provisioned and the connection information was propagated to the `openfaas-fn` namespace in the form of a Kubernetes `Secret`. We used the connection information to [setup our database and table schema](https://youtu.be/XphQgB87U-s?t=3628) prior to deploying our functions.

```console
PGPASSWORD=$(echo $PASSWORD) psql -h $HOST -p 5432 -U $USERNAME -c 'CREATE DATABASE defaultdb;'
PGPASSWORD=$(echo $PASSWORD) psql -h $HOST -p 5432 -U $USERNAME defaultdb < schema.sql
```

![Seed Postgres Database](/images/2020-03-30-managed-services-serverless/seed-db.png)

Now our functions were ready to consume the Postgres database, so we deployed them using `faas-cli deploy`. The next step was relying on inlets again to publicly expose our endpoint so that Github could the `import-comments` function as a webhook to send events. Alex set up the webhook and [Github issue](https://github.com/teamserverless/proposals/issues/3) while I exposed the endpoints using the inlets client.

![Inlets Client](/images/2020-03-30-managed-services-serverless/inlets-client.png)

We finished up by sharing the issue link the the live stream audience, then [watched to see](https://youtu.be/XphQgB87U-s?t=3957) which emoji rose to the top.

![View Emojis](/images/2020-03-30-managed-services-serverless/view-emojis.png)

# Watch the Live Stream

If you enjoyed these demos, watch the full live stream to hear Alex and I dive into the implementation details of Crossplane and OpenFaaS. Alex also answers questions such as "What is it like to build software for multiple platforms?" and "How do you organically grow an open source community?".

{% include youtube.html id="XphQgB87U-s" %}

# Wrapping Up

The demos in this post illustrate the benefits of standardizing on the Kubernetes API as Crossplane and OpenFaaS were able to natively share connection information using the common Kubernetes `Secret` format. They also demonstrated the separation of concern and portability that Crossplane strives for, isolating the configuration and provisioning of managed services into two distinct operations.

Bringing together Crossplane and OpenFaaS creates the easiest path for deploying both your code and your managed services on Kubernetes. These two demos show interesting use-cases, but the beautiful thing about both projects is that they are built to be extensible. Whether you are building new OpenFaaS [function triggers](https://docs.openfaas.com/reference/triggers/), adding support for a [new managed service](https://crossplane.io/docs/v0.9/contributing/services_developer_guide.html) on Crossplane, or just bringing the two projects together to get your application up and running, feel free to [reach out](https://twitter.com/hasheddan) to me directly.

Otherwise, bring your thoughts, questions, and feedback to one of our many forums:
- [Crossplane Slack](https://slack.crossplane.io/)
- [OpenFaaS Slack](https://slack.openfaas.io)
- [Open an Issue](https://github.com/crossplane/crossplane/issues/new/choose)
- [Join our Community Meeting](https://docs.google.com/document/d/1q_sp2jLQsDEOX7Yug6TPOv7Fwrys6EwcF5Itxjkno7Y/edit?usp=sharing)
- [Tune in to The Binding Status](https://www.youtube.com/playlist?list=PL510POnNVaaYFuK-B_SIUrpIonCtLVOzT)