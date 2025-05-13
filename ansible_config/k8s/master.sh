#!/bin/bash

# Update /etc/hosts
printf "\n172.31.27.73 k8s-master\n172.31.24.156 k8s-node1\n\n" >> /etc/hosts

# Disable swap
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Install containerd
wget https://github.com/containerd/containerd/releases/download/v1.6.16/containerd-1.6.16-linux-amd64.tar.gz
tar -xzvf containerd-1.6.16-linux-amd64.tar.gz -C /usr/local
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
mkdir -p /usr/local/lib/systemd/system
mv containerd.service /usr/local/lib/systemd/system/containerd.service
systemctl daemon-reload
systemctl enable --now containerd

# Install runc
wget https://github.com/opencontainers/runc/releases/download/v1.1.4/runc.amd64
install -m 755 runc.amd64 /usr/local/sbin/runc

# Install CNI plugins
wget https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-amd64-v1.2.0.tgz
mkdir -p /opt/cni/bin
tar -xzvf cni-plugins-linux-amd64-v1.2.0.tgz -C /opt/cni/bin

# Install crictl
VERSION="v1.26.0"  # Check latest version in /releases page
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/$VERSION/crictl-$VERSION-linux-amd64.tar.gz
tar -xzvf crictl-$VERSION-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-$VERSION-linux-amd64.tar.gz

# Create crictl config file
cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 2
debug: false
pull-image-on-create: false
EOF

# Load kernel modules
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

# Set sysctl parameters for Kubernetes networking
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system &> /home/ubuntu/sysctl-output.txt
sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
modprobe br_netfilter
sysctl -p /etc/sysctl.conf

# # # Add Kubernetes APT repository and install kubectl, kubeadm, kubelet

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
apt-cache madison kubeadm | tac
sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1 kubeadm=1.30.0-1.1
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

# sudo apt-get update && sudo apt-get upgrade -y
# # apt-get update -y && apt-get install -y apt-transport-https curl
# sudo apt-get update && sudo apt-get install -y apt-transport-https curl
# # curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -

# # cat <<EOF | tee /etc/apt/sources.list.d/kubernetes.list
# # deb https://apt.kubernetes.io/ kubernetes-xenial main
# # EOF
# cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
# deb https://apt.kubernetes.io/ kubernetes-xenial main
# EOF

# apt update -y
# apt-get install -y kubelet kubeadm kubectl

# # Verify Kubernetes installation
# kubeadm version
# kubectl version --client

# # Mark Kubernetes packages to be held
# apt-mark hold kubelet kubeadm kubectl

# sudo apt-get update && sudo apt-get upgrade -y
# apt-get update && sudo apt-get install -y apt-transport-https curl
# curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
# apt-get install -y apt-transport-https ca-certificates curl gpg
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg - dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# apt-get install gpg
# mkdir -p -m 755 /etc/apt/keyrings
# curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
# echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
# cat <<EOF | sudo tee /etc/apt/sources.list.d/kubernetes.list
# deb https://apt.kubernetes.io/ kubernetes-xenial main
# EOF
# sudo apt-get update
# sudo apt-get install -y kubelet kubeadm kubectl
# apt-mark hold kubelet kubeadm kubectl




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

# Install Weave CNI
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml

# Wait for pods and nodes
kubectl get pods -n kube-system --watch
kubectl get nodes
