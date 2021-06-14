# Setup instructions for THALES' Luna Key Broker for DKE

Instructions and small scripts/samples to ease the deployment of THALES' Luna Key Broker for DKE on Microsoft's AKS.

## About Double Key Encryption (DKE)

DKE is the next generation of Microsoft's HYOK concept. By using it you can encrypt your most sensitve files in a way that only your selected entities can read/decrypt them. The reason why organisations implement it is to prevent Microsoft or any other US departments behind from accessing files stored and processed within Microsoft's cloud environment.

Read more about the details of DKE at [the official Microsoft docs](https://docs.microsoft.com/en-us/microsoft-365/compliance/double-key-encryption?view=o365-worldwide).

## Architecture of this setup

### DKE Service

... will be based on the Luna Key Broker for DKE. This solution exposes an HTTP endpoint with the defined REST methods required by DKE clients. It is bundled in a docker image and within this setup we are going to deploy it on a kubernetes cluster. On the k8s cluster we will facilitate NGINX and letsencrypt as ingress setup to handle the incoming HTTPS requests.

The crypto backend will be a DPoD service (Data Protection on Demand), which is a simple Cloud-based HSM from THALES.

As kubernetes platform we will be using Azure Kubernetes Services (AKS).

### Microsoft 365 and Information Protection Service

This guide assumes that you already have a working Microsoft 365 environment with Information Protection enabled and some users having the required licenses to use the feature. There is not really much choice in this setup.

### Microsoft 365 Client

... will be a simple Windows 10 Pro/Enterprise VM (either hosted in any cloud or any onprem hypervisor), which has access to the internet.

In this guide we will setup the VM within Azure.

### Management/admin host

... will be a linux box with the required tooling installed to controll the kubernetes cluster and the Azure resources.

In this guide we will setup the box as an Ubuntu Server VM within Azure.

## Prerequisites

Follow the steps below to create a small demo environment containing...

* A Windows 10 machine as a Microsoft 365 client
* an instance of the THALES solution powering a DKE service hosted on Microsoft's AKS
* a configured Information Protection label for DKE

### THALES components

To be able to setup the THALES solution, you will need to approach a THALES sales representative or engineer in order for them to share the current docker image and an instance of an HSMonDemand service from the THALES Cloud service "DPoD" (Data Protection on Demand).

### Microsoft components

If you do not have a working Microsoft 365 tenant yet, it is possible to sign up at the [Microsoft 365 Developer Program](https://developer.microsoft.com/en-us/microsoft-365/dev-program) to get a free sandbox with the required user licenses. **A setup of such an account will not be covered in this guide!**

### Hosting

To host the DKE service via the Luna Key Broker image you need any docker container runtime. In this guide we will use Microsoft's AKS as kubernetes provider. Although this is not a good idea for production environments since the DKE service should be deployed outside the realms of Microsoft, we use it due to its easy availability for most existing Microsoft customers.

It is required to have the DKE service available for your clients under a FQDN without any prepended paths (<https://fqdn/path-extension/> is not allowed). So we need a dedicated DNS entry for our DKE service. Please make sure to have a free DNS record ready which we can later assign to the IP exposed by the AKS.

**Be aware that this will cause you monthly costs around 200 bucks, if you choose the same cluster size as in this guide!**

## Instructions

### 0. Before you begin

A checklist of what you need and what will be used in this guide:

* Free DNS name for your DKE service
  * *lkb-on.azure.gegenleitner.eu* will be used.
* Azure account capable of deploying azure resources
* Working M365 tenant
* Tool for SSH-ing into your Ubuntu Server (i. e. putty) on your workstation
* Tool for SSH-Copy files to your Ubuntu Server (i. e. WinSCP, scp or pscp) on your workstation
  * WinSCP will be used
* RDP-Client on your workstation to access the Windows 10 test machine
  * Standard *Remote Desktop Connection* from Windows 10 will be used

### 1. Prepare your Azure environment

Watch this small video to setup all required resources:

* New dedicated resource group (*luna-key-broker-demo*)
* Ubuntu Server 20.04 LTS (*management-linux*)
* AKS cluster with ACR (*dke-cluster* and *dke-repository*)
* Windows 10 client (*dke-client*)

### 2. Prepare your CloudHSM and create keys on it

#### Create a service client to a new CloudHSM service

Watch the video on how to create a new HSMonDemand service client on DPoD.

#### Initialize CloudHSM and its roles

#### Create some keys for DKE

### 3. Deploy the DKE service on kubernetes

### 4. Register the DKE service in Azure Active Directory

### 5. Configure a Information Protection Label with DKE

### 6. Configure a Windows 10 Client for DKE

## Additional references and resources

* Official DKE documentation page at Microsoft @ [https://docs.microsoft.com/en-us/microsoft-365/compliance/double-key-encryption?view=o365-worldwide]
* DKE FAQ and Troubleshooting guide by Microsoft @ [https://techcommunity.microsoft.com/t5/security-compliance-and-identity/dke-troubleshooting/ba-p/2234252]
