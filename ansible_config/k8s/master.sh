#!/bin/bash

# Update /etc/hosts
printf "\n172.31.27.73 k8s-master\n172.31.24.156 k8s-node1\n\n" >> /etc/hosts

# Disable swap
# swapoff -a
# sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 1. Update 
sudo apt update && sudo apt upgrade -y

# 2. Disable Swap (required by kubelet)
sudo swapoff -a
sudo sed -i '/ swap / s/^/#/' /etc/fstab
 
# 3. Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 4. Set sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
________________________________________
🐳 Step 2: Install containerd
# 1. Install containerd dependencies
sudo apt install -y curl gnupg2 software-properties-common apt-transport-https ca-certificates

# 2. Add Docker GPG key and repo
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 3. Install containerd
sudo apt update && sudo apt install -y containerd.io

# 4. Generate default config
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null

# 5. Enable systemd cgroup driver
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 6. Restart containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
________________________________________
☸️ Step 3: Install Kubernetes
# 1. Add Kubernetes GPG key and repo
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | \
sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" | \
sudo tee /etc/apt/sources.list.d/kubernetes.list

# 2. Install kubeadm, kubelet, kubectl
sudo apt update
sudo apt install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Initialize Kubernetes master node
kubeadm init
sleep 10

# Set up kubeconfig for the user
mkdir -p $HOME/.kube
if [ -f /etc/kubernetes/admin.conf ]; then
    cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
else
    echo "admin.conf not found!"
    exit 1
fi
sleep 10

# Install Calico CNI
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.3/manifests/calico.yaml

# Wait for pods and nodes
kubectl get pods -n kube-system --watch
kubectl get nodes
