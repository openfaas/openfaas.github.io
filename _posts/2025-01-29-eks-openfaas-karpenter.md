---
title: "Save costs on AWS EKS with OpenFaaS and Karpenter"
description: "Learn how to save on infrastructure costs for your OpenFaaS functions on AWS EKS with Karpenter cluster autoscaling."
date: 2025-01-29
author_staff_member: han
categories:
  - eks
  - openfaas
  - serverless
  - auto-scaling
dark_background: true
image: "/images/2025-01-eks-openfaas-karpenter/background.png"
hide_header_image: true
---

In this tutorial we will show you an optimised configuration for OpenFaaS Functions for Karpenter on AWS EKS.

We will show how to deploy OpenFaaS on [AWS EKS](https://aws.amazon.com/eks/) and use [Karpenter](https://karpenter.sh/) for cluster autoscaling.

The cluster will be split in static and dynamic capacity. The OpenFaaS core components will be running on static nodes in an [EKS Managed Node Group](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html). Karpenter will dynamically add, remove and resize nodes in the cluster based on workload demands for functions.

**What is Karpenter?**

Karpenter is an open-source Kubernetes cluster autoscaler. It automates the provisioning and deprovisioning of nodes based on the scheduling needs of Pods, allowing efficient scaling and cost optimization.

Compared to other alternatives like [Amazon EC2 Auto Scaling Groups](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html) and the [Kubernetes Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler) (CAS), Karpenter is:

- Easier to deploy and configure and consolidates instance orchestration responsibilities within a single system. 
- More flexible and allows provisioning of diverse nodes based on workload requirements with minimal configuration. Instead of managing many specific custom node groups, Karpenter could let you manage diverse workload capacity with a single, flexible NodePool.
- Faster at provisioning nodes and scheduling Pods reducing the time workloads spend in a pending state.

**What makes Karpenter a good match for OpenFaaS?**

Improved scalability

Karpenter automatically provisions and deprovisions nodes based on real-time workload requirements to ensure there is enough capacity in the cluster. It can increase the size of the cluster when more functions are deployed or when a function has high demand and is scaled up by the OpenFaaS autoscaler.

Cost optimization

- Make use of spot instances - Karpenter can use spot instances to reduce cost for workloads that tolerate interruptions It can easily blend them with on-demand instances to ensure each workload runs on the right type of instance.
- Right sized nodes - Nodes are automatically provisioned with optimal resources to match workload demands and avoid over-provisioning.
- Combining workloads onto fewer nodes. Pods are moved to different nodes and packed together if workload demands change, allowing Karpenter to remove unused nodes.

Operational simplicity

Karpenter simplifies node management. Scaling a Kubernetes cluster often requires pre-configured node groups, scaling rules or manually adding nodes. Karpenter eliminates this by dynamically selecting the right instance types and adding them to the cluster based on a flexible NodePool configuration. Unlike node group-level autoscalers, Karpenter makes scaling decisions based on the entire cluster’s needs.


## Deploy OpenFaaS and Karpenter on AWS EKS.

In the following sections we will run you through the steps to get a basic OpenFaaS deployment with Karpenter running on EKS.

`eksctl` is used to create a new EKS cluster. If you have an existing EKS cluster or are switching from [Kubernetes Cluster Autoscaler](https://karpenter.sh/v0.37/getting-started/migrating-from-cas/) we recommend you to take a look at the [Karpenter Migration guide](https://karpenter.sh/v0.37/getting-started/migrating-from-cas/) for the Initial installation of Karpenter.

### Prerequisites

Tools that need te be installed on your system to follow along with this guide. Most of these are available in [arkade](https://github.com/alexellis/arkade).

1. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. [eksctl](https://eksctl.io/installation/), CLI for AWS EKS - `arkade get eksctl`
3. [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/) - `arkade get kubectl`
4. [Helm](https://helm.sh/docs/intro/install/) - `arkade get helm`


### Create an EKS cluster

> The instructions are based on the [Karpenter gettings started guide](https://karpenter.sh/v0.37/getting-started/getting-started-with-karpenter/). You can check out this guide for a more in depth overview of how to get started with Karpenter.

**Env variables**

Set the Karpenter and Kubernetes versions:

```sh
export KARPENTER_NAMESPACE="kube-system"
export KARPENTER_VERSION="1.1.1"
export K8S_VERSION="1.31"
```

Set the cluster name, region and account id:

```sh
export CLUSTER_NAME="openfaas"
export AWS_PARTITION="aws"
export AWS_DEFAULT_REGION="us-east-1"
export AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export TEMPOUT="$(mktemp)"
```

**Create infrastructure dependencies for Karpenter**

Karpenter requires IAM permissions to provision nodes and SQS for interruption notifications. Use Cloudformation to set up infrastructure needed by the Karpenter. See the [Karpenter CloudFormation reference](https://karpenter.sh/v0.37/reference/cloudformation/) for a complete description of what `cloudformation.yaml` does.

```sh
curl -fsSL https://raw.githubusercontent.com/aws/karpenter-provider-aws/v"${KARPENTER_VERSION}"/website/content/en/preview/getting-started/getting-started-with-karpenter/cloudformation.yaml  > "${TEMPOUT}" \
&& aws cloudformation deploy \
  --stack-name "Karpenter-${CLUSTER_NAME}" \
  --template-file "${TEMPOUT}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides "ClusterName=${CLUSTER_NAME}"
```

**Create the cluster**

We will be creating a cluster with only a single static node in this demo. For production clusters it is recommended to run more than one node in the system node group. The Karpenter Helm chart for example tries to deploy 2 replicas of its controller to different nodes by default, OpenFaaS recommends running 3 replicas of some components. For production it is recommended to run at least 2 nodes or more.

Create a cluster config that can be used with `eksctl`.

With this config `eksctl` will:

- Create a Kubernetes service account and AWS IAM Role, and associate them using [IAM Roles for Service Accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)(IRSA) to let Karpenter launch instances.
- Add the Karpenter node role to the aws-auth configmap to allow nodes to connect.
- Create an [AWS EKS managed node group](https://docs.aws.amazon.com/eks/latest/userguide/managed-node-groups.html) for the kube-system, karpenter and openfaas namespaces.

```yaml
cat > clusterconfig.yaml <<EOF
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_DEFAULT_REGION}
  version: "${K8S_VERSION}"
  tags:
    karpenter.sh/discovery: ${CLUSTER_NAME}

iam:
  withOIDC: true
  podIdentityAssociations:
  - namespace: "${KARPENTER_NAMESPACE}"
    serviceAccountName: karpenter
    roleName: ${CLUSTER_NAME}-karpenter
    permissionPolicyARNs:
    - arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:policy/KarpenterControllerPolicy-${CLUSTER_NAME}

iamIdentityMappings:
- arn: "arn:${AWS_PARTITION}:iam::${AWS_ACCOUNT_ID}:role/KarpenterNodeRole-${CLUSTER_NAME}"
  username: system:node:{{"{{"}}EC2PrivateDNSName{{"}}}}
  groups:
  - system:bootstrappers
  - system:nodes
  ## If you intend to run Windows workloads, the kube-proxy group should be specified.
  # For more information, see https://github.com/aws/karpenter/issues/5099.
  # - eks:kube-proxy-windows

managedNodeGroups:
- instanceType: m5.large
  amiFamily: AmazonLinux2
  name: ${CLUSTER_NAME}-ng
  desiredCapacity: 1
  minSize: 1
  maxSize: 4

addons:
- name: eks-pod-identity-agent
EOF
```

Create a new EKS cluster using the cluster configuration:

```sh
eksctl create cluster -f clusterconfig.yaml
```

Create a role to allow spot instances.

> Unless your AWS account has already onboarded to EC2 Spot, you will need to create the service linked role to avoid the [`ServiceLinkedRoleCreationNotPermitted` error](https://karpenter.sh/v0.37/troubleshooting/#missing-service-linked-role).

```sh
aws iam create-service-linked-role --aws-service-name spot.amazonaws.com || true
# If the role has already been successfully created, you will see:
# An error occurred (InvalidInput) when calling the CreateServiceLinkedRole operation: Service role name AWSServiceRoleForEC2Spot has been taken in this account, please try a different suffix.

```

### Deploy Karpenter

Create a Helm configuration file, `karpenter-values.yaml`, for Karpenter:

```yaml
cat > karpenter-values.yaml <<EOF
# Run a single replica, if your cluster has more static nodes this value
# can be increased.
replicas: 1

settings:
  clusterName: ${CLUSTER_NAME}
  interruptionQueue: ${CLUSTER_NAME}

resources:
  requests:
    cpu: 0.5
    memory: 512Mi
  limits:
    cpu: 1
    memory: 1Gi
EOF
```

> We halved the cpu and memory requests to reduce the number of nodes required for this demo. If you deploy Karpenter in production it is recommended to increase these requests.

Deploy Karpenter with Helm:

```sh
# Logout of helm registry to perform an unauthenticated pull against the public ECR
helm registry logout public.ecr.aws

helm upgrade --install karpenter \
    oci://public.ecr.aws/karpenter/karpenter \
    --version "${KARPENTER_VERSION}" \
    --namespace "${KARPENTER_NAMESPACE}" \
    --create-namespace \
    -f karpenter-values.yaml \
    --wait
```

### Deploy OpenFaaS

Detailed installation instructions including the various chart configuration options are available in the [OpenFaaS docs](https://docs.openfaas.com/deployment/pro/) and [Helm chart](https://github.com/openfaas/faas-netes/tree/master/chart/openfaas).

For the OpenFaaS configuration we start from the recommended configuration with the addition of a node affinity rule. The nodeAffinity restricts Pods of the OpenFaaS core components to static nodes in the AWS EKS managed node group and prevents them from running on dynamic nodes provisioned by Karpenter.

```yaml
cat > openfaas-values.yaml <<EOF
openfaasPro: true
clusterRole: true

operator:
  create: true
  leaderElection:
    enabled: true

gateway:
  # Run a single gateway replica. 3 are recommended for production.
  replicas: 1

  # 10 minute timeout
  upstreamTimeout: 10m
  writeTimeout: 10m2s
  readTimeout: 10m2s

autoscaler:
  enabled: true

dashboard:
  enabled: true

queueWorker:
  # Run a single queue-worker replica. 3 are recommended for production.
  replicas: 1

queueWorkerPro:
  maxInflight: 50

queueMode: jetstream

nats:
  streamReplication: 1

affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: karpenter.sh/nodepool
              operator: DoesNotExist
EOF
```

Create the namespaces for OpenFaaS Pro and functions:

```sh
kubectl apply -f https://raw.githubusercontent.com/openfaas/faas-netes/master/namespaces.yml
```

Create a secret for your OpenFaaS license:

```sh
kubectl create secret generic \
  -n openfaas \
  openfaas-license \
  --from-file license=$HOME/.openfaas/LICENSE
```

Deploy OpenFaaS using the Helm chart:

```sh
helm repo add openfaas https://openfaas.github.io/faas-netes/
helm repo update

helm upgrade openfaas \
  --install openfaas/openfaas \
  --namespace openfaas \
  --values=openfaas-values.yaml
```

#### Verify the installation

Once all the services are up and running, log into the gateway using the OpenFaaS CLI. This will cache your credentials into the `~/.openfaas/config.yml` file.

Fetch your public IP or NodePort via `kubectl get svc -n openfaas gateway-external -o wide` and set it as an environmental variable as below:

```sh
export OPENFAAS_URL=http://127.0.0.1:31112
```

If using a remote cluster, you can port-forward the gateway to your local machine:

```sh
export OPENFAAS_URL=http://127.0.0.1:8080
kubectl port-forward -n openfaas svc/gateway 8080:8080 &
```

Log in with the CLI and check connectivity:

```sh
echo -n $PASSWORD | faas-cli login -g $OPENFAAS_URL -u admin --password-stdin
faas-cli version
```

### Create a Karpenter NodePool

Karpenter only starts creating nodes when there is at least one NodePool configured. A NodePool sets constraints on the nodes that can be created and the pods that can run on those nodes. Karpenter makes scheduling and provisioning decisions based on pod attributes such as labels and affinity. A single Karpenter NodePool is capable of handling many different pod shapes.

We will create a default NodePool and NodeClass that is capable of handling function pods and any other pods deployed to the cluster.

**Create a NodeClass**

Node Classes enable configuration of AWS specific settings like the AMIs for Karpenter to use when provisioning nodes. Each NodePool must reference an EC2NodeClass using `spec.template.spec.nodeClassRef`. 

```yaml
export ARM_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2-arm64/recommended/image_id --query Parameter.Value --output text)"
export AMD_AMI_ID="$(aws ssm get-parameter --name /aws/service/eks/optimized-ami/${K8S_VERSION}/amazon-linux-2/recommended/image_id --query Parameter.Value --output text)"

cat > default-nodeclass.yaml << EOF
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2 # Amazon Linux 2
  role: "KarpenterNodeRole-${CLUSTER_NAME}" # replace with your cluster name
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  securityGroupSelectorTerms:
    - tags:
        karpenter.sh/discovery: "${CLUSTER_NAME}" # replace with your cluster name
  amiSelectorTerms:
    - id: "${ARM_AMI_ID}"
    - id: "${AMD_AMI_ID}"
EOF
```

Review the [Karpenter NodeClass documentation](https://karpenter.sh/docs/concepts/nodeclasses/) for more information.

**Create a NodePool**

```yaml
cat > default-nodepool.yaml <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF
```

- The `spec.template.spec.requirements` block is used to define constraints for the type of nodes that can be created. For the default pool we restrict Karpenter to only consider a set of on-demand general purpose instances suitable for most function workloads.
- The `limits` block limits capacity to 100 CPUs. This means the NodePool will stop adding nodes to the cluster when the sum of all capacity created has reached this limit.
- The `disruption` block configures how Karpenter manages nodes and moves workloads around. In this case with `consolidationPolicy` set to `WhenEmptyOrUnderutilized`, Karpenter will try to reduce cluster cost by removing or replacing nodes if they are underutilized or empty. The `consolidateAfter` specifies the amount of time Karpenter waits after identifying consolidation opportunities before acting on them.

Review the [Karpenter NodePool documentation](https://karpenter.sh/v0.37/concepts/nodepools/) for more information.

Add the NodeClass and NodePool to the cluster:

```sh
kubectl apply -f default-nodeclass.yaml
kubectl apply -f default-nodepool.yaml
```

### Demo: See Karpenter add nodes due to load on a function

Deploy an OpenFaaS function with OpenFaaS [autoscaling labels](https://docs.openfaas.com/architecture/autoscaling/). We are going to invoke the function with Hey and trigger it to get scaled up by the OpenFaaS autoscaler. The higher replica count will not fit within our cluster resources and we should see Karpenter provision an additional node to run the new replicas. After the function scales down again the node will get removed.

```sh
faas-cli store deploy sleep \
  --label com.openfaas.scale.max=5 \
  --label com.openfaas.scale.target=5 \
  --label com.openfaas.scale.type=capacity \
  --label com.openfaas.scale.target-proportion=1.0 \
  --cpu-request=1
```

Note that we set a high cpu request value on the function. This will increase the resources requested and trigger Karpenter to provision a new node when the function is scaled up by the autoscaler.

Run the following command before you start to invoke the function to observe what is happening.

Watch function pods in one terminal:

```sh
kubectl get pods -n openfaas-fn -o wide -w
```

Watch nodes in a second terminal:

```sh
kubectl get nodes -w
```

Watch the logs for the Karpenter controller in a third terminal:

```sh
kubectl logs -f -n "${KARPENTER_NAMESPACE}" -l app.kubernetes.io/name=karpenter -c controller
```

Invoke the function with hey to trigger autoscaling:

```sh
hey -t 10 -z 3m -c 25 \
  http://127.0.0.1:8080/function/sleep
```

After the function is scaled down the node should be reclaimed.

<script src="https://asciinema.org/a/b1WdZIe78qQ3rChgftAw4Yms9.js" id="asciicast-b1WdZIe78qQ3rChgftAw4Yms9" async="true"></script>
> [eks-node-viewer](https://github.com/awslabs/eks-node-viewer) showing a `c6a.large` node gets replaced with a bigger `c6a.2xlarge` instance to satisfy the resource requests when the sleep function is scaled up to 5 replicas. The `c6a.2xlarge` instance is replaced by a cheaper `c6a.large` instance again after the function has scaled back down to 1 replica.

![Dashboard screenshots](/images/2025-01-eks-openfaas-karpenter/cluster-scaling-grafana-dashboard.png)
> OpenFaaS dashboard showing the replicas of the sleep function alongside the Karpenter dashboard where you can see a node gets replaced by a higher capacity node when the function scales up. The node is replaced with a low capacity node again after the function scales down.

### Demo: Advanced scheduling with affinity and OpenFaaS Profiles

Karpenter makes scheduling and provisioning decisions based on attributes such as resource requests, affinity, tolerations, nodeSelector and topology spread. Only the configuration of resource requests is supported through the OpenFaaS function spec. To set any of the other configuration attributes OpenFaaS has the concept of Profiles.

Profiles allow for advanced configuration of function deployments on Kubernetes and allow you to easily apply the configuration to multiple functions. Profiles can be used to configure tolerations, nodeAffinity, etc. See: [the OpenFaaS profiles docs](https://docs.openfaas.com/reference/profiles/) for all configuration options. They are applied to functions by adding the `com.openfaas.profile` annotation with the name of the Profile to the function.

To get Karpenter to schedule functions to the `default` NodePool we need to set NodeAffinity on the function pods for the functions nodePool.

Create a `functions` Profile that has a nodeAffinity rule to constrain function pods to the `default` NodePool:

```yaml
cat > functions-profile.yaml <<EOF
kind: Profile
apiVersion: openfaas.com/v1
metadata:
  name: functions
  namespace: openfaas
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
            - key: karpenter.sh/nodepool
              operator: In
              values:
              - default
EOF
```

```sh
kubectl apply -f functions-profile.yaml
```

Deploy a function from the OpenFaaS store and apply the `functions` profile.

```sh
faas-cli store deploy nodeinfo --annotation "com.openfaas.profile=functions"
```

After deploying the function Karpenter will try to schedule it to a node in the `default` NodePool. If there are no nodes or there is not enough capacity in the NodePool to deploy the function, Karpenter will add an extra node or replace the node with a higher capacity one.

### Demo: Schedule functions to spot instances with a Profile

If one or more of your functions can tolerate being interrupted or cancelled due to a node being reclaimed, then you could consider using spot instances. Spot instances are available [up to a 90% off](https://aws.amazon.com/ec2/spot/pricing/) compared to On-Demand pricing. If you have a mixed workload of functions that can tolerate interruptions and functions that can not we recommend creating a separate nodePool for functions that can use spot nodes.

Create a `spot` NodePool:

```yaml
cat > spot-nodepool.yaml <<EOF
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: spot
  annotations:
    kubernetes.io/description: "NodePool for provisioning spot capacity"
spec:
  template:
    spec:
      taints:
        - key: karpenter.sh/capacity-type
          value: "spot"
          effect: NoSchedule
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot"]
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        group: karpenter.k8s.aws
        kind: EC2NodeClass
        name: default
      expireAfter: 720h # 30 * 24h = 720h
  limits:
    cpu: 100
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 1m
EOF
```

```sh
kubectl apply -f  spot-nodepool.yaml
```

This NodePool is almost identical to the default pool that was created earlier. Except for two changes. The `karpenter.sh/capacity-type` requirement was changed to `spot` and a taint was added. This taint should prevent running any pods that do not explicitly tolerate it on spot instance nodes.

To run functions on spot nodes a toleration needs to be added to the function deployment. This can be done by creating a `spot-functions` Profile.

```yaml
cat > spot-functions-profile.yaml <<EOF
kind: Profile
apiVersion: openfaas.com/v1
metadata:
  name: spot-functions
  namespace: openfaas
spec:
  tolerations:
  - key: "karpenter.sh/capacity-type"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"
EOF
```

```sh
kubectl apply -f spot-functions-profile.yaml
```

This Profile can now be applied to any function that can tolerate interruptions when a spot instance gets reclaimed.

```sh
faas-cli store deploy nodeinfo \
  --annotation "com.openfaas.profile=spot-functions"
```

### Demo: Don't pay for idle - scale both functions and nodes to zero

The OpenFaaS autoscaler can [scale idle functions to zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/). When scaled to zero, functions do not consume CPU or memory. Functions are automatically scaled back up again upon first use.

Scale to zero can save money because fewer nodes are required in a cluster and the available resources are used more efficiently. When combined with Karpenter cost savings could be even higher. When functions are scaled to zero Karpenter removes underutilized nodes from the cluster or replaces a bigger node with a cheaper smaller one if the capacity is not required.

When all functions using a nodePool are scaled to zero this means Karpenter will remove all nodes until there are requests for the function again bringing down the node cost to 0 while functions are idle.

![Scale to zero node removal conceptual diagram](/images/2025-01-eks-openfaas-karpenter/scale-to-zero-node-concept.png)
> Conceptual diagram showing how an underutilized node get removed from the cluster by Karpter when the sleep function running on the node gets scaled down to zero replicas by OpenFaaS.

**Longer cold starts**

The latency between accepting a request for an unavailable function and serving the request is often called a "cold start". The cold start time for OpenFaaS functions can vary based on your cluster and the size of the function image but is usually not more than a few seconds. When using Karpenter you have to take into account the cold start can be significantly longer if a new node has to be provisioned. During our testing we saw that it took around 45-50 seconds for a function to become ready on on-demand nodes and around 70 seconds for nodes running on spot instances.

Your application will need to be able to handle these longer cold start times by either setting a higher timeout for request or supporting retries. Alternatively functions can be invoked [asynchronously](https://docs.openfaas.com/reference/async/) to gracefully handle longer cold starts.

To allow faster function scale up it could be a good idea to keep some baseline capacity in the cluster. This is currently not supported by Karpenter but there is an [issue tracking this feature request](https://github.com/kubernetes-sigs/karpenter/issues/749). As an alternative you could enure there is alwways some spare capacity in the static node group running the core components or create an separate EKS Managed Node Group with some nodes to provide this basline capacity.

### Delete the cluster

If you are just following along this tutorial to try things out don't forget to delete the cluster to avoid unwanted charges to your AWS account. Double check any EC2 instances provisioned by Karpenter got deleted.

```sh
helm uninstall karpenter --namespace "${KARPENTER_NAMESPACE}"
helm uninstall openfaas --namespace openfaas
aws cloudformation delete-stack --stack-name "Karpenter-${CLUSTER_NAME}"
aws ec2 describe-launch-templates --filters "Name=tag:karpenter.k8s.aws/cluster,Values=${CLUSTER_NAME}" |
    jq -r ".LaunchTemplates[].LaunchTemplateName" |
    xargs -I{} aws ec2 delete-launch-template --launch-template-name {}
eksctl delete cluster --name "${CLUSTER_NAME}"
```

## Conclusion

We walked though the steps required to deploy OpenFaaS and Karpenter on an EKS cluster that we provisioned using eksctl.

We showed how OpenFaaS and Karptner can be used together in several demo's:

- We showed how Karpenter can remove underutilized nodes to save cost by [scaling functions to zero](https://docs.openfaas.com/openfaas-pro/scale-to-zero/).
- [Asynchronous invocations](https://docs.openfaas.com/reference/async/) can be used to handle invocations in a more reliable way. They can help to handle delays and retries when functions take longer to become ready because a new node has to be provisioned.
- We used [OpenFaaS Profiles](https://docs.openfaas.com/reference/profiles/) to configure scheduling constraints for functions using affinity and tolerations. In this post we created two NodePools for on-demand and spot instances which should be a good starting point for most OpenFaaS clusters. Of course there is a lot more to explore like scheduling based on node resources like GPU or high availability for functions using [topology spread](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/). See the Karptner documentation for more [advanced scheduling techniques](https://karpenter.sh/docs/concepts/scheduling/).

In a next article we will show you how OpenFaaS and Karpenter can be used to efficiently run functions that need GPU resources by building on the configuration and features discussed in this article, like scale to zero and OpenFaaS Profiles.

[Reach out to us](https://www.openfaas.com/pricing/) if you’d like a demo, or if you have any questions about OpenFaaS on AWS EKS, or OpenFaaS in general.