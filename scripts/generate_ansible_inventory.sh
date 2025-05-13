#!/bin/bash

echo "Creating inventory file for Ansible ...."
cat <<EOF > ../ansible_config/inventory
jenkins    ansible_host=  ansible_user=ubuntu ansible_connection=ssh
sonar      ansible_host=  ansible_user=ubuntu ansible_connection=ssh
nexus      ansible_host=  ansible_user=ubuntu ansible_connection=ssh
k8s-master ansible_host=  ansible_user=ubuntu ansible_connection=ssh
k8s-node1  ansible_host=  ansible_user=ubuntu ansible_connection=ssh
EOF

echo -e "\nPopulating inventory file for Ansible ...."

# Extract public IPs from Terraform outputs
jenkins_public_ip=$(terraform -chdir="../terraform_config/jenkins" output -raw public_ip)
sonar_public_ip=$(terraform -chdir="../terraform_config/sonar" output -raw public_ip)
nexus_public_ip=$(terraform -chdir="../terraform_config/nexus" output -raw public_ip)
master_public_ip=$(terraform -chdir="../terraform_config/master" output -raw public_ip)
node1_public_ip=$(terraform -chdir="../terraform_config/node1" output -raw public_ip)

# Ensure IPs are fetched properly
if [[ -z $jenkins_public_ip || -z $sonar_public_ip || -z $nexus_public_ip || -z $master_public_ip || -z $node1_public_ip ]]; then
  echo "❌ One or more IP addresses could not be retrieved from Terraform outputs. Exiting."
  exit 1
fi

# Update the inventory file with the actual IPs
sed -i '' "s|^jenkins.*ansible_host=.*|jenkins ansible_host=${jenkins_public_ip} ansible_user=ubuntu ansible_connection=ssh|" ../ansible_config/inventory
sed -i '' "s|^sonar.*ansible_host=.*|sonar ansible_host=${sonar_public_ip} ansible_user=ubuntu ansible_connection=ssh|" ../ansible_config/inventory
sed -i '' "s|^nexus.*ansible_host=.*|nexus ansible_host=${nexus_public_ip} ansible_user=ubuntu ansible_connection=ssh|" ../ansible_config/inventory
sed -i '' "s|^k8s-master.*ansible_host=.*|k8s-master ansible_host=${master_public_ip} ansible_user=ubuntu ansible_connection=ssh|" ../ansible_config/inventory
sed -i '' "s|^k8s-node1.*ansible_host=.*|k8s-node1 ansible_host=${node1_public_ip} ansible_user=ubuntu ansible_connection=ssh|" ../ansible_config/inventory

echo -e "✅ Done!\n"
