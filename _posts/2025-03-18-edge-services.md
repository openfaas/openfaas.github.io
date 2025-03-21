---
title: "How to Manage Stateful Services with OpenFaaS Edge"
description: "Learn how to define and manage stateful services for OpenFaaS Edge via its docker-compose.yaml file."
date: 2025-03-18
author_staff_member: alex
categories:
- edge
- stateful
- services
- faasd
dark_background: true
image: images/2025-03-edge-stateful/background.png
hide_header_image: true
---

OpenFaaS Edge is a distribution of OpenFaaS Standard that runs without Kubernetes, on a single host or VM.

We created OpenFaaS Edge (aka faasd-pro) as an antidote to the constant churn, change, and complexity of Kubernetes. It is designed to be simple to operate, easy to understand, and reliable so that it can be redistributed as part of an appliance or edge device.

In this post, we'll explore some new commands added to the `faasd` binary for managing services, then I'll show you how stateful services with via the `docker-compose.yaml`.

Finally, I'll show you how the arkade tool can be used to upgrade the versions of the container images referenced in the YAML file, and how to ignore certain images if you want to hold them at a specific version.

## Introducing the new service commands

The `faasd` binary for OpenFaaS Edge has a new set of commands that allow you to manage the services defined in the `docker-compose.yaml` file. These commands are available in OpenFaaS Edge, and they are designed to make it easier to manage stateful services.

* `faasd service list` - Lists the status of each service including its age and uptime
* `faasd service logs` - Displays the logs for a given service
* `faasd service restart` - Restarts a given service
* `faasd service top` - Shows the CPU and memory usage of each service

A simpler version of the `service logs` command was added to faasd CE.

### faasd service list

The `faasd service list` command lists all the services defined in the `docker-compose.yaml` file. This command is useful for getting an overview of the services that are running on your OpenFaaS Edge instance.

```bash
$ faasd service list

NAME             IMAGE                                               CREATED          STATUS                 
cron-connector   ghcr.io/openfaasltd/cron-connector:0.2.9            23 seconds ago   running (23 seconds)   
faas-idler       ghcr.io/openfaasltd/faas-idler:0.5.6                23 seconds ago   running (23 seconds)   
gateway          ghcr.io/openfaasltd/gateway:0.4.38                  23 seconds ago   running (23 seconds)   
nats             docker.io/library/nats:2.10.26                      24 seconds ago   running (24 seconds)   
prometheus       docker.io/prom/prometheus:v3.2.1                    23 seconds ago   running (23 seconds)   
queue-worker     ghcr.io/openfaasltd/jetstream-queue-worker:0.3.46   23 seconds ago   running (23 seconds)   
 
```

Note that the IP address will change between restarts.

### faasd service logs

The `faasd service logs` command displays the logs for a given service. This command is useful for debugging and troubleshooting issues with your services.

You can use various flags which you may recognise from `docker logs`, `journalctl` or `kubectl logs`:

```bash
$ faasd service logs gateway

$ faasd service logs gateway -f

$ faasd service logs gateway --lines 1000

$ faasd service logs gateway --since 1h

$ faasd service logs gateway --since-time "2025-03-18T12:00:00Z"
```

### faasd service top

The `faasd service top` shows the RAM and CPU usage of each service, so you can keep an eye on whether your services will continue to fit on the host.

```bash
$ faasd service top

NAME            PID            CPU (Cores)    Memory
prometheus      5870           2m             50 MB
gateway         5976           2m             12 MB
nats            5759           2m             4.3 MB
cron-connector  6082           0m             5.1 MB
queue-worker    6184           0m             6.3 MB
faas-idler      6493           0m             7.3 MB

```

### faasd service restart

The `faasd service restart` command restarts a given service.

Whilst this command does not reload any changes from the docker-compose.yaml file, it will stop and restart the service. This is useful if you hadn't created a volume mount with the right permissions, the image you were using was not yet pushed to the registry, or there was a race condition or crash of your service.

To reload the compose file, run `sudo systemctl restart faasd` instead.

Perhaps you noticed an error with the faas-idler service and need to restart it?

First, we check the logs to see when it started:

```bash
$ faasd service logs faas-idler

OpenFaaS Pro: faas-idler (classic scale-to-zero)	Version: 0.5.6	Commit: a2fa75c6c82297d110e4c1922ead2df77c2b3cce
2025/03/18 12:48:08 read-only mode: false
```

Then we restart it

```
$ faasd service restart faas-idler
```

Next, we can check the running time, and see that it's more recent than the other parts of the stack:

```bash
$ sudo faasd service list
NAME             IMAGE                                               CREATED         STATUS                 
cron-connector   ghcr.io/openfaasltd/cron-connector:0.2.9            2 minutes ago   running (2 minutes)    
faas-idler       ghcr.io/openfaasltd/faas-idler:0.5.6                2 minutes ago   running (43 seconds)   
```

## New features for the docker-compose.yaml file

Disable a service for a period of time, whilst retaining it in the file:

```yaml
  cron-connector:
    deploy:
      replicas: 0
```

Enable automatic restarts for a service such as `nats`:

```yaml
  nats:
    restart: "always"
```

By default, services that exit will not be restarted unless you run `sudo systemctl restart faasd`.

## How the `docker-compose.yaml` file works

Since OpenFaaS Edge runs on a VM, without Kubernetes, we needed a way to define the core services that make up the stack the gateway, NATS, Prometheus and the queue-worker. Docker's Compose specification was a convenient way to do this because it uses a syntax that's easy to understand and familiar to many developers who have worked with Docker at some point in their career.

Every installation comes with a pre-defined file, which contains definitions for the OpenFaaS gateway, queue-worker, cron-connectors, NATS and Prometheus. Typically you'd only change this file if you wanted to update a setting like the maximum timeout for functions or what version of an image you wanted to run.

Here's how NATS can be defined in the stack for faasd CE:

```yaml
services:
  nats:
    image: docker.io/library/nats:2.10.26
    user: "65534"
    restart: "always"
    command:
      - "/nats-server"
      - "-js"
      - "-sd=/nats"
    volumes:
      - type: bind
        source: ./nats
        target: /nats
```

We can also expose the TCP port for NATS on a given adapter, or just access it from the Linux bridge that is created by faasd.

```yaml
ports:
- "127.0.0.1:4222:4222"
```

Service discovery is relatively simple. Each service created by this file can look up other containers by name from a `/etc/hosts` file that is injected dynamically.

So the code in the OpenFaaS gateway can simply open a TCP connection to `nats:4222` and it will be routed to the NATS container.

All services within the compose file are already stateful in that they are run longing, and can write to their filesystem. However, if you want their data to survive restarts, then you can attach volumes to them just like with `docker run -v`.

For Prometheus, we can add a volume to store its Time Series Data Base (TSDB) on the host machine:

```yaml
  prometheus:
    image: docker.io/prom/prometheus:v3.2.1
    user: "65534"
    restart: "always"
    volumes:
      - type: bind
        source: ./prometheus.yml
        target: /etc/prometheus/prometheus.yml
      - type: bind
        source: ./prometheus
        target: /prometheus
    cap_add:
      - CAP_NET_RAW
    ports:
       - "127.0.0.1:9090:9090"
```

We've also bind-mounted the `prometheus.yml` file so that we can change the configuration without having to build a custom image.

### How to update images in the docker-compose.yaml file

The [arkade](https://github.com/alexellis/arkade) tool can be used to check for newer images and upgrade the image tags within the `docker-compose.yaml` file.

```bash
cd /var/lib/faasd

arkade chart upgrade --file ./docker-compose.yaml --write --verbose
```

Example output:

```bash
root@build-1:/var/lib/faasd# arkade chart upgrade --file ./docker-compose.yaml --write --verbose
2025/03/18 12:30:57 Verifying images in: ./docker-compose.yaml
2025/03/18 12:30:57 Found 6 images
2025/03/18 12:30:57 [ghcr.io/openfaasltd/gateway] 0.4.38 => 0.4.39
```

If you want to hold the version for a certain service, such as `postgresql`, then you can create a file alongside the `docker-compose.yaml` which will be read by arkade:

```
/var/lib/faasd/arkade.yaml
/var/lib/faasd/docker-compose.yaml
```

Add the full path to each image you want `arkade chart upgrade` to ignore, for example:

```yaml
ignore:
- services.postgresql.image
```

Then run `sudo systemctl restart faasd` to apply the changes.

## Conclusion

We've added a new set of commands to help you manage and monitor services with OpenFaaS Edge, along with two new features for the compose file (restart policies and disabling services).

We also took a look at a couple of examples of how to define services in the `docker-compose.yaml` file using the NATS and Prometheus services from the OpenFaaS Edge YAML file. You can inspect your local YAML file at `/var/lib/faasd/docker-compose.yaml` to see how the other services are set up.

For additional examples of how to define services in the `docker-compose.yaml` file, please refer to [Serverless For Everyone Else](https://store.openfaas.com/l/serverless-for-everyone-else) which is the handbook for faasd CE and OpenFaaS Edge. You'll find detailed examples of how to write functions using Node.js and how to manage additional services such as Grafana, Postgresql, and InfluxDB.

### Want to try it out?

For personal, non-commercial use, you have two options:

* faasd CE - free for 15 functions
* OpenFaaS Edge - get free access when you [sponsor @openfaas](https://github.com/sponsors/openfaas) via GitHub for 25 USD/mo or higher

For commercial use:

* faasd CE - 1x installation for a 60 day trial or PoC
* OpenFaaS Edge - [purchase a license](https://docs.google.com/forms/d/e/1FAIpQLSe2O9tnlTjc7yqzXLMvqvF2HVqwNW7ePNOxLchacKRf9LZL7Q/viewform?usp=header) and run up to 250 functions with various OpenFaaS Pro features included

[Find out more in the docs](https://docs.openfaas.com/deployment/edge/)
