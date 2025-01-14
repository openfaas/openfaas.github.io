---
title: "Introducing New Graphs For The OpenFaaS Dashboard"
description: "Learn how you can use the new graphs for the OpenFaaS dashboard to monitor and debug your functions."
date: 2025-01-15
author_staff_member: han
categories:
  - metrics
  - dashboard
  - ui
  - monitoring
dark_background: true
image: "/images/2025-01-graphs-for-the-openfaas-dashboard/background.png"
hide_header_image: true
---

Troubleshooting and optimizing functions without the right insights is like flying blind. That is why real-time visibility into key metrics such as invocation rate, error frequencies and resource usage are essential. OpenFaaS has extensive support for Prometheus metrics. These metrics are made available through the built-in Prometheus server.

While we maintain a collection of [Grafana dashboards](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/) that can be used by customers to easily visualize these metrics and monitor their OpenFaaS deployment, we wanted to make it even easier for OpenFaaS users to get access to metrics.

With the latest release of the OpenFaaS dashboard we have made selection of graphs available directly in the OpenFaaS dashboard:

- `Invocation Metrics`: Rate, Error, Duration (RED) metrics.
- `Load metrics`: View function replica count and current load.
- `Resource usage`: CPU/RAM usage of functions.

Combined with features like log inspection and the ability to invoke functions from the dashboard this gives you all the tools you need to monitor and debug your functions.

## Key Metrics and Graphs

To provide users with a more integrated experience, the OpenFaaS dashboard now displays function key metrics and visualizations directly. The graphs give you better insights into function behavior and resource utilization, making it easier to debug and optimize your workloads without leaving the dashboard.

**Invocation metrics**

Rate, Error, Duration (RED) metrics.

- `Invocation rate by status code` - Function invocation rate over the last 30s broken down by status code.
- `Latency by status code` - Average function invocation latency over the last 30s broken down by status code.

![Invocation graphs](https://docs.openfaas.com/images/dashboard/invocation-graphs.png)
> Invocation metrics for the sleep function displaying values by status codes.

**Load metrics**

View function replica count and current load.

- `Load` - Load as measured by the autoscaler.
- `Replicas` - Function replica count.

![Load graphs](https://docs.openfaas.com/images/dashboard/load-graphs.png)
> Load metrics recorded while running the variable capacity load test from the [openfaas-autoscaler-tests](https://github.com/openfaas/openfaas-autoscaler-tests)

**Resource usage**

CPU/RAM usage of functions.

- `CPU usage` - CPU usage of the function across all replicas, measured in milli-CPU.
- `Memory usage` - Memory usage of the function across all replicas.

![Resource usage graphs](https://docs.openfaas.com/images/dashboard/resource-graphs.png)
> CPU and RAM resource metrics during a variable load test.

## Wrapping up

With the introduction of graphs in the OpenFaaS dashboard users now have another tool available for function observability. The dashboard makes it easy to quickly make graphs accessible to function users and developers:

- No need to deploy Grafana and manage user access.
- The OpenFaaS dashboard integrates directly with [OpenFaaS IAM](https://docs.openfaas.com/openfaas-pro/iam/overview/).   Users will only be able to view the graphs for functions they have access to as configured by your OpenFaaS roles and policies.

The OpenFaaS dashboard is not intended as a replacement for other monitoring tools but rather as an addition that can be useful for immediate feedback and insights into function metrics and logs.

Find out more about the OpenFaaS dashboard:

- [Meet the next-gen dashboard we built for OpenFaaS in production](https://www.openfaas.com/blog/openfaas-dashboard/)
- [Grafana Dashboards](https://docs.openfaas.com/openfaas-pro/grafana-dashboards/)
- [OpenFaaS dashboard docs](https://docs.openfaas.com/openfaas-pro/dashboard/)

If you'd like to try out the dashboard for your team, or want to talk to us, [get in touch here](https://openfaas.com/pricing).