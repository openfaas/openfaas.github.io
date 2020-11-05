---
title: "Continuous Deployment of your OpenFaaS Cloud"
description: Learn how you can Continuously Deploy new versions of OpenFaaS Cloud using ofc-bootstrap.
date: 2020-04-22
image: /images/2020-04-22-ofc-bootstrap-pipeline/cloud-background.jpg
categories:
  - kubernetes
  - serverless
  - managed
  - cloud
  - gitops
  - ci
author_staff_member: alistair
dark_background: true
---

We are going to run through the process of keeping multiple installations of OpenFaaS Cloud up to date, configured and 
logically separated. These examples and processes are just as useful if you are managing one installation or many.

There are several excellent blog posts and resources on setting up OpenFaaS Cloud, but so far upgrades are 
on you, and each user has been applying their own techniques to keep up to date.

If you're new to OpenFaaS Cloud, start with one of the tutorials below:

 * [Create your own private cloud with OpenFaaS Cloud](https://www.openfaas.com/blog/ofc-private-cloud/)
 * [Build your own OpenFaaS Cloud with AWS EKS](https://www.openfaas.com/blog/eks-openfaas-cloud-build-guide/)
 * [How I built Good First Issue bot with OpenFaaS Cloud](https://www.openfaas.com/blog/good-first-issue/)
 * [Introducing OpenFaaS Cloud with GitLab](https://www.openfaas.com/blog/openfaas-cloud-gitlab/)

### Upgrades are always hard

Upgrading a system is often harder than an initial installation or bootstrap. How do you migrate data and handle 
breaking changes in the system, or in its dependencies? Where do you store the configuration? How about confidential 
configuration like secrets?

I'll outline a technique used with a customer to manage 10 different environments without any additional changes to
the ofc-bootstrap tooling. Longer term, a helm chart that is in development for OpenFaaS Cloud should make the whole process 
easier and allow for tooling such as [FluxCD](https://github.com/fluxcd) to do some of the heavy lifting.

### Bill of materials

To follow along you will need the following things:

* [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap/blob/master/USER_GUIDE.md#get-ofc-bootstrap) installed (Instructions in link)
* A [Keybase account](https://keybase.io/) (optional, but highly recommended for keeping secrets encrypted)
* A Domain (We use `ofc.example.com`, replace this with your domain) managed by one of the [supported providers](https://github.com/openfaas/ofc-bootstrap/blob/master/USER_GUIDE.md#credentials-and-dependent-systems) (We are using AWS Route35)
* A set of credentials for AWS for ECR and Route53. (One for each)
 * the [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap) github repository checked out.

### Installing OpenFaaS Cloud

The recommended installation method for OpenFaaS Cloud (OFC) is [ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap/issues). 
It's a CLI that automates most of the configuration and installation of the OFC core components.

![ofc-bootstrap](https://github.com/openfaas/ofc-bootstrap/raw/master/docs/ofc-bootstrap.png)

> ofc-bootstrap packages a number of primitives such as an IngressController, a way to obtain certificates from LetsEncrypt, the OpenFaaS Cloud components, OpenFaaS itself and Minio for build log storage. Each component is interchangeable.

A relatively long YAML file is used to configure the installation. The developers have tried to strike a balance between 
sane defaults and having the right knobs and dials in place. Most of the settings will not need to be changed, or 
only need to be changed at the beginning of the setup.

The kind of configuration you'll find is around feature toggles, TLS, DNS, Docker registry configuration, and SCM (GitHub/GitLab) settings.

`ofc-bootstrap` makes installation and management much easier than installing all these comoponents manually.

You can create multiple config files and "override" the config in some files with more specific settings.
This means we can create a base set of config that all of our clusters are going to share and pop this config into one file, then 
re-use this file over and over with our new clusters.

#### Setting our base config

We need to work out what the slow moving "base" config for our installations is going to be. In general, things like 
TLS config, the locations of your secrets files and OAuth settings are not likely to change between installations and 
upgrades, so it's useful to keep one set of these somewhere and build on this base config with specifics for each cluster.

[This gist](https://gist.github.com/Waterdrips/ea1eecb2e41ee19ed6aebc87daa7e63f) is the first part of our `init.yaml` 
config file, we define the secrets a little later on. This file should be placed in the root of your project. 

One extra "trick" I have found useful is defining all of our secrets as "files" rather than directly storing them in the 
config. This allows us to reduce repetition even more, and keep our config files as small as possible. One extra benifit 
is that we can use an encrypted git repository, we used [keybase's encrypted git](https://keybase.io/blog/encrypted-git-for-everyone)
repositories. 

This means defining our secrets like this:
```yaml
  - name: basic-auth
    files:
      - name: "basic-auth-user"
        value_from: "./credentials/basic-auth-user"
      - name: "basic-auth-password"
        value_from: "./credentials/basic-auth-password"
```

This `files` syntax grabs the values from the specified file from a relative path. This means we can lay out our
directory structure like this:

```bash
- project
  - production 
    - cluster0
      - credentials
        - basic-auth-password
        - basic-auth-user
  - dev
    - cluster0
      - credentials
        - basic-auth-password
        - basic-auth-user
```

Each of these `credentials` directories is an encrypted keybase git repository. This allows us to limit the access of 
these secrets to the minimum set of people, while still allowing the rest of your organisation to see your OFC versions,
setup and config.

Add the contents of [this gist](https://gist.github.com/Waterdrips/ee38a4d27d88502f3b3d2902d56958a6) to your `init.yaml`
to use this layout.

When setting up the secrets you can create these `credentials` directories using the following command, from within each
"cluster" directory.
```bash
# move into the first production cluster directory
cd project/production/cluster0

# add the encrypted keybase repository
git submodule add keybase://private/[keybase_username]/prod-cluster0 credentials

# Repeat for each cluster as required.
```

A full copy of this `init.yaml` file [is shown in this gist](https://gist.github.com/Waterdrips/54471b9236f6d8c7ac60a304bb0129d0)
, you can download this and change your specific values where indicated.

#### Setting up secrets

Next up is populating the base secrets, ones that are not specific to your individual cluster's configuration. Things 
like the OpenFaaS Gateway password that need to be set, but should be random.

I have been using the following set of commands, on linux, to populate the base secrets for each cluster we are going to 
install into.

> Note: We are using AWS ECR for storing docker containers, you can also use the Docker Hub, but that is not
>covered in this post.

```bash
</dev/urandom tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | head -c 25 > credentials/basic-auth-password
</dev/urandom tr -dc 'A-Za-z0-9!"#$%&'\''()*+,-./:;<=>?@[\]^_`{|}~' | head -c 25 > credentials/payload-secret
echo "admin" > credentials/basic-auth-user
ofc-bootstrap registry-login --ecr --account-id <AWS_ACCOUNT_ID> --region <AWS_REGION>
```

We are also using a `customers` file rather than a public url. This was released in version [0.9.2](https://github.com/openfaas/ofc-bootstrap/releases/tag/0.9.2)
of `ofc-bootstrap` so make sure you are up to date to support these settings.

```bash
# You can also manually edit this file to add more users/teams. 
# One line per user/team. (case sensitive)
echo "YourGithubUsernameOrTeam" > credentials/customers
```

Each line in this file permits the Github user or team to subscribe to the app and create workloads. Be sure to only add
people you need to give access to in this list. 

Populate `./credentials/route53-secret-access-key` with the route53 secret key only, no whitespace and no prefix

Populate `./credentials/aws-ecr-credentials`with the below format


```sh
[default]
aws_access_key_id = <ECR_ACCESS_KEY>
aws_secret_access_key = <ECR_SECRET_KEY>
```   

#### Setup Github 

We are using the OpenFaaS Cloud Github integration to manage our team's code deployments, this means creating a 
[Github App](https://developer.github.com/apps/). There is a useful helper built into `ofc-bootstrap` that helps speed up 
the process.

```bash
# change into the ofc-bootstrap repository you have checked out
ofc-bootstrap create-github-app --root-domain ofc.example.com --name my-ofc-app
```

Follow the on-screen instructions:

![on-screen-instructions for creating github app](/images/2020-04-04-ofc-bootstrap-pipeline/create-github-app.png)

This will generate a github app. The settings for that app will be printed to the console where you ran the `create-github-app` 
command. We need to save some output into new secrets files:

* Save the `github-webhook-secret` to a file called `./credentials/github-webhook-secret`
* Save the `private-key` into a file called `./credentials/github-private-key.pem`, making sure there is no additional whitespace in the file (all lines should start on first column of the file)
* Make a note of the `github app_id` that is returned, ours was `59246`

While we are on github, go to your app, [this is the apps list page](https://github.com/settings/apps/). Click `edit`

On this page, there is a checkbox indicating that the app is "Active". Make sure this is checked, and then save the changes.

![Active github app button](/images/2020-04-04-ofc-bootstrap-pipeline/active-webhook.png)

---- 

Next up is creating an OAuth app to secure our private endpoints, such as the OpenFaaS Cloud dashboard.

This is covered in [this section of the OpenFaaS Cloud docs](https://docs.openfaas.com/openfaas-cloud/self-hosted/github/#create-a-github-oauth-integration-optional).
In the interest of not repeating ourselves, you should follow those instructions to create a Github OAuth app.

We need two bits of config from the OAuth app:
* Populate `./credentials/of-client-secret` with the client secret from OAuth app
* Make a note of the Oauth `client_id`, ours was `b2a2adc6c56864c9d65d`

---- 

We are almost done with setup I promise! We now just need to populate an `overrides.yaml` file. This file will contain 
all the application specific config for that cluster.

Save this `overrides.yml` file into each of your cluster directories and amend the values for your setup.
```yaml
### Docker registry
registry: <AWS_ACCOUNT_ID>.dkr.ecr.<AWS_ECR_REGION>.amazonaws.com/<CLUSTER_NAME>

ecr_config:
  ### The region to use for ECR
  ecr_region: "<AWS_ECR_REGION>"

### Your root DNS domain name, this can be a sub-domain i.e. staging.o6s.io / prod.o6s.io
# Should be less than 53 chars, due to the limit on CN length on LetsEncrypt Certs
root_domain: "ofc.example.com"

## Populate from GitHub App
github:
  app_id: "59246" # This is the GitHub app id from earlier


tls_config:
  acess_key_id: <AWS_ACCESS_KEY_ID_ROUTE53>


## Populate from OAuth App
oauth:
  client_id: "b2a2adc6c56864c9d65d" # This is the OAuth app client secret from before

## Branch that OpenFaaS Cloud will build and deploy
## You should change this if you want a different branch to be built and deployed instead of master
build_branch: master
```

#### Final preparation

The last thing we need to do to get started is symlink the `scripts` and `templates` directories from the checked out 
copy of the `ofc-bootstrap` repository. This is because the `ofc-bootstrap` binary requires the contents of these files 
when deploying OpenFaaS Cloud. There is now a work-in-progress OpenFaaS Cloud Helm chart that should reduce the dependancy
on these files.

```bash
# For our custer0 in the production environment:
cd production/cluster0

ln -s <path_to_templates_folder> templates
ln -s <path_to_scripts_folder> scripts
```

> Note: If you are planning on running this in a CI pipeline, copy those folders in rather than symlinking
> so the files are available in the CI environment. 

### Deploying OpenFaaS Cloud

We should now have a directory structure like this for each of our clusters. The `credentials` directory stores our secrets
and our `overrides.yaml` holds the cluster specific config.

```
├── credentials
│   ├── aws-ecr-credentials
│   ├── basic-auth-password
│   ├── basic-auth-user
│   ├── config.json
│   ├── customers
│   ├── github-private-key.pem
│   ├── github-webhook-secret
│   ├── of-client-secret
│   ├── payload-secret
│   └── route53-secret-access-key
├── overrides.yaml
├── scripts
│   ├── (contents not shown)
└── templates
    ├── (contents not shown)
```

Our top level structure looks like this.
```bash
- project
  - production 
    - cluster0
  - dev
    - cluster0
```

We are going to deploy `dev/cluster0` to version `0.13.7` , then go through upgrading the system by changing the OpenFaaS 
Cloud version in our base `init.yaml` to 0.13.8 and re-running our command.

Our `init.yaml` base config file should be placed in the `project` directory, and each cluster's `overrides.yaml` in the 
relevant cluster directory, like this:

```bash
- project
  init.yaml
  - production 
    - cluster0
      overrides.yaml
  - dev
    - cluster0
      overrides.yaml
```

Navigate into the `dev/cluster0` directory and connect to your dev/cluster0 Kubernetes cluster in your shell.

To deploy OpenFaaS Cloud using our config use this command. Remember to set the absolute path to your `init.yaml`
```bash
ofc-bootstrap apply -f <path-to-init.yaml> -f overrides.yaml
```

After running this, there will be a load of output which ends with something like this (your speed will vary based on 
network connection speed etc)
```bash
Plan completed in 82.859371 seconds 
```

Our cluster has been initialised. You need to set your DNS records for the following subdomains to the IP or LoadBalancer 
DNS record for your cluster.

* `*.ofc.example.com`
* `auth.system.ofc.example.com`

Once these are set you should be able to navigate to `https://system.ofc.example.com` and authorise with the github OAuth app.
You will then be redirected to the OpenFaaS Cloud Dashboard. It might take a few minutes for the TLS certificates to be 
issued by LEtsEncrypt, so you may have to wait for this to complete.

![ofc dashboard](/images/2020-04-04-ofc-bootstrap-pipeline/ofc-dashboard.png)

#### Re running the ofc-bootstrap tool

When you have completed everything up to now and verified your installation, you are ready to build and deploy your services! 

We are going to run through how to upgrade to OpenFaaS Cloud 0.13.8. 

Go to your `init.yaml` file, find the line `openfaas_cloud_version: 0.13.7`, change the version to `0.13.8`

Re-run the ofc-bootstrap command and wait for it to complete.

```sh
ofc-bootstrap apply -f <path-to-init.yaml> -f overrides.yaml
```

It's as simple as that. This will re-install the core services and bring the OpenFaaS Cloud installation up to the specified
version.

#### Watch out for

* If you change one of those `credentials/*` files, this way of re-running `ofc-bootstrap` will not update that secret.
You will either have to delete the secret (not recommended) and re-run the command or you can manually update the base64 
encoded value in the secret by using `kubectl edit`.

* This solution assumes every installation will be updated to the specified OpenFaaS Cloud version specified in your `init.yaml`.
To combat this you could move this config setting into the `overrides.yaml`. Additionally, using a symlink to `ofc-bootstrap`'s 
checked out git repository for the `templates` and `scripts` folders assumes you are using the same version of `ofc-bootstrap` for every 
cluster too.

* LetsEncrypt has rate limits for new certificates. You may exhaust this limit if you have many clusters. You could reduce the
 impact of this by using multiple domains or by using the `staging` issuer on some clusters.

* When you update to a new version of OpenFaaS Cloud using `ofc-bootstrap` you need to make sure the installed `ofc-bootstrap` 
version matches the version of the repository you have checked out (so those `templates` and `scripts` folders get updated)

#### Running in a CI Pipeline

You may wish to keep your Git repository as the `single source of truth`. This can be done by setting a CI pipeline to run 
on changes to the `master` branch for your config. This means your users can't manually run the ofc-bootstrap tool and everything
has to go through git. 

You will need to work out how your CI pipeline gets access to the secrets in the `credentials` folder for each cluster. 
This will depend on your specific setup, you could use [Hashicorp Vault](https://www.vaultproject.io), a solution with 
[Keybase](https://keybase.io) or [AWS Secrets Manager](https://aws.amazon.com/secrets-manager/).

This solution can be run in your favourite CI pipeline as long as the environment it's run in can connect to the correct 
Kubernetes cluster, has access to those `credentials`, `templates` and `scripts` folders. 

Once you have those dependencies setup in your CI pipeline, you need to just run the same command that we used earlier.

Make sure you are in the correct directory for the cluster you are connected to and run the following in your CI step

```bash
ofc-bootstrap apply -f <path-to-init.yaml> -f overrides.yaml
```

#### Over to you

I've introduced you to one of the ways I was able to implement continuous deployment for a client, however it's not 
the only valid approach and I'd be open to feedback. As part of the customer project, changes were suggested that 
went into the open source tooling to improve the GitHub automation, to remove Tiller and to switch to Helm3, and to 
create base and override files.

If you have other solutions, or would like to help us test the new helm chart, please connect with the community.

* Join us on [on Slack](https://slack.openfaas.io/) and the `#openfaas-cloud` channel to chat more
* [Create your own private cloud with OpenFaaS Cloud](https://www.openfaas.com/blog/ofc-private-cloud/)
* Apply for free access to the managed [Community Cluster](https://github.com/openfaas/community-cluster)
