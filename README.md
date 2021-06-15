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

* The docker image of THALES' Luna Key Broker for DKE as a tar ball
* Access to a DPoD tenant to create a DPoD service. Else you can request your THALES contact to share details to an existing service.
* Free DNS name for your DKE service
  * *lkb-on.azure.gegenleitner.eu* will be used.
  * If you do not want to use an own domain, you can also facilitate Azure's cloudapp domain to assign a FQDN.
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
* AKS cluster with ACR (*dke-cluster* and *dkerepository*)
  * *dkerepository* for ACR might be shown as taken, because this must be a unique name across Azure. If this is the case, just select another name (required changes will be noted in the guide later)
* Windows 10 client (*dke-client*)

#### Install required software on Ubuntu

Follow the steps below or just copy-paste them into an open SSH-session on your Ubuntu Server:

```shell
# Change into your user's home directory
cd ~
# Ensure git is installed
sudo apt-get update && sudo apt-get install -y git unzip
# Checkout this git repository to have all scripts at hand
git clone https://github.com/martingegenleitner/thales-dke-service-setup.git
# Call the installer script to get all required tools onto your management machine
chmod +x ~/thales-dke-service-setup/mgmt-linux/install_tooling.sh
~/thales-dke-service-setup/mgmt-linux/install_tooling.sh
# Create a few directories to organize your tooling
mkdir -p ~/hsm
mkdir -p ~/k8s
```

### 2. Prepare your CloudHSM

#### Create a service client to a new CloudHSM service

Watch the video on how to create a new HSMonDemand service client on DPoD. Additional information can be found at <https://thalesdocs.com/dpod/services/hsmod_services/hsmod_add_service/index.html>.

#### Initialize CloudHSM and its roles

Copy the service client (*setup-lkb.zip*) via scp onto the Ubuntu server into */home/azureuser/hsm* and open a SSH-session to the host into this directory. Then follow the commands from below to setup the service. Additional information can be found at <https://thalesdocs.com/dpod/services/hsmod_services/hsmod_linux_client/index.html>.

```shell
# Change into the hsm directory
cd ~/hsm
# Unpack the setup package
unzip ./setup-lkb.zip
# Unpack the linux client
tar xvf cvclient-min.tar
# Configure environment
source ./setenv
# Start the hsm configuration tool "lunacm"
# If the command executes with no errors, your connection is working correctly.
./bin/64/lunacm
```

The following commands must be called in the context of the lunacm cli tool. In this guide we will use a fixed set of passwords in order to make mapping of them to config files easier. Usually they are called interactively by not suppling passwords as parameters. Then the commands will prompt you for them. **Use your own custom secrets in a production environment!**

```shell
# Initialize the partition. During this process the cloning domain and
# Partition Security Officer (PO/SO) credentials are set (both to the passphrase "qwertzu")
partition init -label lkb-hsm -password qwertzu -domain qwertzu -force
# Login as Security Officer
role login -name po -password qwertzu
# Initialize the Crypto Officer
role init -name co -password yxcvbnm
# Logout and log back in as Crypto Officer
role logout
role login -name co -password yxcvbnm
# Change password of Crypto Officer in order to unlock him
# The password will be changed to "asdfghj"
role changepw -name co -oldpw yxcvbnm -newpw asdfghj -force
```

Finally copy over the file *Chrystoki.conf* to your kubernetes folder as this contains the connection details for your DKE service to access the Cloud HSM.

```shell
# Change into the HSM directory to the working Chrystoki.conf
cd ~/hsm
# Copy the file to the kubernetes directory
cp ./Chrystoki.conf ~/k8s
# Change into the kubernetes directory
cd ~/k8s
# Apply a few path corrections to the file to fit the paths in the docker image later
sed -i '/LibUNIX64/s/.*/LibUNIX64 = \/usr\/safenet\/lunaclient\/libs\/64\/libCryptoki2_64.so;/' ./Chrystoki.conf
sed -i '/PluginModuleDir/s/.*/PluginModuleDir = \/usr\/safenet\/lunaclient\/plugins;/' ./Chrystoki.conf
sed -i '/LibUNIX =/d' ./Chrystoki.conf
sed -i '/LibUNIX64/a LibUNIX = /usr/safenet/lunaclient/libs/64/libCryptoki2.so;' ./Chrystoki.conf
```

#### Create some keys for DKE

With the new Crypto Officer it is possible to generate a few keys on the Cloud HSM. The setup ships with an own Certificate Management Utility (cmu) binary that helps creating asymmetric key pairs on THALES HSMs. Use the command below to generate a key with the label "DKE-Key-001" on the HSM via a SSH session on the Ubuntu server.

If you need more than one key for your DKE enabled labels later, just rename the key label in the last command to something else and run all commands again.

```shell
# Change into the hsm directory
cd ~/hsm
# (Optional) if you opened a new SSH session, configure the environment again
source ./setenv
# Generate a unique/random key identifier
KEY_ID=$(head -c16 </dev/urandom|xxd -p -u)
# Generate a key pair with the Certificate Management Utility
# -modulusBits=2048               DKE currently only supports RSA 2048 keys
# -publicExponent=65537           Kind of default for RSA keys
# -label=DKE-Key-001              Set the label of the key. This will be used later to reference it during creation of sensitivity labels
# -encrypt/decrypt/wrap/unwrap    Set permissions on this key's usage
# -id=$KEY_ID                     Set the key id to identify this key pair after a key rotation
# -mech=pkcs                      RSA key generation mechanism to be used
# -password=asdfghj               Define the Crypto Officer password to authenticate against the HSM service (if not defined, the command will prompt for it)
./bin/64/cmu generatekeypair -modulusBits=2048 -publicExponent=65537 -label=DKE-Key-001 -encrypt=1 -decrypt=1 -wrap=1 -unwrap=1 -id=$KEY_ID -mech=pkcs -password asdfghj
```

Now the HSM is fully functional and ready to be used for DKE!

### 3. Deploy the DKE service on kubernetes

This repository ships with a few .yml templates that help setup a Key-Broker cluster on kubernetes. Follow the instructions below to create a cluster via an SSH session from the Ubuntu server. To be able to upload later THALES' docker image, upload it (you get it from THALES) from your workstation to the Ubuntu server via SCP to the directory */home/azureuser/k8s*.

```shell
####
# Define a few constants before we start setting up the dke service cluster
####
# Please take a look at https://docs.microsoft.com/en-us/azure/active-directory/fundamentals/active-directory-how-to-find-tenant
# on how to find your tenant id
TENANT_ID="YOUR_TENANT_ID"
# Update this variable with the name of your actual ACR resource created in step#1
ACR_NAME="dkerepository"
# Update this variable with the FQDN you chose for your DKE service.
DKE_SERVICE_FQDN="lkb-on.azure.gegenleitner.eu"
# Mail address for letsencrypt. There you will get notified when the cluster certs will expire.
# Please update to your own address
CERT_MASTER="my.mailing@address.org"

# Authenticate the Azure CLI to your subscription where you deployed your AKS resource.
# This will display instructions on how to authenticate your device with your Azure account
az login
# Fetch credentials for your AKS and ACR resources
# This is necessary to later have access via docker for pushing the
# image to the registry and controlling AKS via kubectl and helm
az aks get-credentials --resource-group luna-key-broker-demo --name dke-cluster
az acr login --name $ACR_NAME

####
# Import the docker image from THALES and push it to your ACR resource
####
cd ~/k8s
# (optional)
# If you received the zip-file 610-000693-001_SW_Docker_image_Luna_Key_Broker_for_Microsoft_DKE.zip
# then you have to first unzip it and copy the actual tar ball with the image to the working directory.
unzip 610-000693-001_SW_Docker_image_Luna_Key_Broker_for_Microsoft_DKE.zip
mv 610-000693-001_SW_Docker_image_Luna_Key_Broker_for_Microsoft_DKE/luna-key-broker-for-dke_v1.0.tar .

# Import the docker image to your local docker registry
docker load -i luna-key-broker-for-dke_v1.0.tar
# Tag the docker image and push it to your ACR
docker tag luna-key-broker-for-dke:v1.0 $ACR_NAME.azurecr.io/luna-key-broker-for-dke:v1.0
docker push $ACR_NAME.azurecr.io/luna-key-broker-for-dke:v1.0

####
# Create kubernetes resources on AKS
####
# Copy all resources from this repository into your kubernetes directory
cp 

# Create a namespace for your dke service resources
kubectl create namespace dke
# Add the ingress-nginx repository to your local helm
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
# Use Helm to deploy an NGINX ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx --namespace dke --set controller.replicaCount=2 --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux

# Create Secrets/Configs by uploading 
kubectl create secret generic luna-config-file --from-file=Chrystoki.conf --namespace dke
kubectl create secret generic credentials --from-literal=password='yxcvbnm' --namespace dke
kubectl create secret generic auth-claim --from-file=opa_policies.rego --namespace dke

# Label the dke namespace to disable resource validation
kubectl label namespace dke cert-manager.io/disable-validation=true
# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
# Update your local Helm chart repository cache
helm repo update
# Install the cert-manager Helm chart
helm install cert-manager jetstack/cert-manager --namespace dke --version v0.16.1 --set installCRDs=true --set nodeSelector."kubernetes\.io/os"=linux --set webhook.nodeSelector."kubernetes\.io/os"=linux --set cainjector.nodeSelector."kubernetes\.io/os"=linux

# Create the cluster issuer
kubectl apply -f cluster-issuer.yml

# Deploy the Key-Broker
kubectl apply -f luna-key-broker.yml --namespace dke

# Deploy an ingress route
kubectl apply -f ingress.yml --namespace dke
```

### 4. Register the DKE service in Azure Active Directory

### 5. Configure a Information Protection Label with DKE

### 6. Configure a Windows 10 Client for DKE

## Additional references and resources

* Official DKE documentation page at Microsoft @ <https://docs.microsoft.com/en-us/microsoft-365/compliance/double-key-encryption?view=o365-worldwide>
* DKE FAQ and Troubleshooting guide by Microsoft @ <https://techcommunity.microsoft.com/t5/security-compliance-and-identity/dke-troubleshooting/ba-p/2234252>
