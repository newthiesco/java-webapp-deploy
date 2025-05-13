#!/bin/bash

echo "PLAY [Add private IP of k8s instances to init scripts] ************************************************************"

# Extract previously used IPs from master.sh
mip=$(grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' master.sh | head -n 1)
nip=$(grep -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' master.sh | tail -n 1)

# Check if IPs exist in the file and replace them with dummy variables
if grep -qE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' master.sh; then
    echo "Previously used IPs found"
    sed -i '' "s/$mip/kmaster-ip/g" master.sh
    sed -i '' "s/$nip/knode1-ip/g" master.sh
    sed -i '' "s/$mip/kmaster-ip/g" nodes.sh
    sed -i '' "s/$nip/knode1-ip/g" nodes.sh
else
    echo "Dummy variables already present"
fi

echo "Adding IPs of k8s-master and k8s-node1 to the master.sh and nodes.sh scripts"

# Fetch fresh IPs using Terraform
master_private_ip=$(terraform -chdir="../../terraform_config/master" output -raw private_ip)
node1_private_ip=$(terraform -chdir="../../terraform_config/node1" output -raw private_ip)

# Replace dummy placeholders with actual IPs
sed -i '' "s/kmaster-ip/$master_private_ip/g" master.sh
sed -i '' "s/knode1-ip/$node1_private_ip/g" master.sh
sed -i '' "s/kmaster-ip/$master_private_ip/g" nodes.sh
sed -i '' "s/knode1-ip/$node1_private_ip/g" nodes.sh

