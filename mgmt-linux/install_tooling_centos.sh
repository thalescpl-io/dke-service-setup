#!/bin/bash

# Install Azure CLI
# (Taken from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Docker CE
# (Taken from https://docs.docker.com/engine/install/ubuntu/#install-using-the-convenience-script)
 
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Add current user to docker group
# (Taken from https://docs.docker.com/engine/install/linux-postinstall/#manage-docker-as-a-non-root-user)
sudo usermod -aG docker $USER

# Install kubectl
# (Taken from https://kubernetes.io/de/docs/tasks/tools/install-kubectl/#installieren-der-kubectl-anwendung-mithilfe-der-systemeigenen-paketverwaltung)
sudo apt-get update && sudo apt-get install -y apt-transport-https
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
sudo yum install -y kubectl

# Install helm
# (Taken from https://helm.sh/docs/intro/install/)
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
