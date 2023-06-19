# IBM MQ Sample Helm Chart
This repository provides a helm chart to deploy an IBM® MQ container built from the [IBM MQ Container GitHub repository](https://github.com/ibm-messaging/mq-container), and has been verified against the [9.3.3 branch](https://github.com/ibm-messaging/mq-container/tree/9.3.3).

## Pre-reqs
Prior to using the Helm chart you will need to install two dependencies:
1. [Helm version 3](https://helm.sh/docs/intro/install/)
2. [Kubectl](https://kubernetes.io/docs/tasks/tools/)

You will also need a kubernetes environment for testing, this could be a private cloud environment or a deployment on a public cloud such as IBM Cloud, AWS, Azure or Google Cloud.

The repoistory includes two directories:
* [ibm-mq](charts/ibm-mq/README.md): the helm chart for IBM MQ
* [samples](samples/README.md): provides a number of samples of deployment


## Issues and contributions

For issues relating specifically to the Helm chart, please use the [GitHub issue tracker](https://github.com/ibm-messaging/mq-helm/issues). If you do submit a Pull Request related to this Helm chart, please indicate in the Pull Request that you accept and agree to be bound by the terms of the [Developer's Certificate of Origin](DCO1.1.txt).

## License

The code and scripts are licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0.html).

This Helm chart defaults to deploy the free to use non-warranted IBM MQ Advanced for Developer containers for development use only, with the option to customize to other container images.

When deploying IBM MQ for production or non-production use into a Kubernetes environment, you can license based on the resource limits specified on the container by using the IBM License Service. The IBM License Service is deployed into the Kubernetes Cluster and tracks usage based on Kubernetes Pod annotations. How this can be defined within the Helm chart is described [here](charts/ibm-mq/README.md#Supplying-licensing-annotations). To understand how to deploy the IBM License Service please review [here](https://github.com/IBM/ibm-licensing-operator/blob/release-1.8/docs/License_Service_main.md).

**This chart includes the capability to deploy IBM MQ Native HA. When used for production and non-production this feature is available to customers with entitlement to IBM Cloud Pak for Integration using IBM MQ Advanced conversion entitlement ratios.**

## Copyright

© Copyright IBM Corporation 2021
