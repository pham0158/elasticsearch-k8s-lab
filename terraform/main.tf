terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── VPCs ──────────────────────────────────────────────────

resource "aws_vpc" "vpc_a" {
  cidr_block           = var.vpc_a_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "ES-Lab-VPC-A" }
}

resource "aws_subnet" "subnet_a" {
  vpc_id                  = aws_vpc.vpc_a.id
  cidr_block              = cidrsubnet(var.vpc_a_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "ES-Lab-Subnet-A" }
}

resource "aws_vpc" "vpc_b" {
  cidr_block           = var.vpc_b_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "ES-Lab-VPC-B" }
}

resource "aws_subnet" "subnet_b" {
  vpc_id                  = aws_vpc.vpc_b.id
  cidr_block              = cidrsubnet(var.vpc_b_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
  tags                    = { Name = "ES-Lab-Subnet-B" }
}

# ── Internet Gateways ─────────────────────────────────────

resource "aws_internet_gateway" "igw_a" {
  vpc_id = aws_vpc.vpc_a.id
  tags   = { Name = "ES-Lab-IGW-A" }
}

resource "aws_internet_gateway" "igw_b" {
  vpc_id = aws_vpc.vpc_b.id
  tags   = { Name = "ES-Lab-IGW-B" }
}

# ── VPC Peering ───────────────────────────────────────────

resource "aws_vpc_peering_connection" "peer" {
  vpc_id      = aws_vpc.vpc_a.id
  peer_vpc_id = aws_vpc.vpc_b.id
  auto_accept = true
  tags        = { Name = "ES-Lab-VPC-A-to-VPC-B" }
}

# ── Route Tables ──────────────────────────────────────────
# Pod CIDR 10.245.0.0/16 is split: lower /17 assigned to control plane node,
# upper /17 assigned to worker node by Flannel. Each side routes the other's half.

resource "aws_route_table" "rt_a" {
  vpc_id = aws_vpc.vpc_a.id
  route {
    cidr_block                = aws_vpc.vpc_b.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
  route {
    cidr_block                = "10.245.128.0/17"
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_a.id
  }
  tags = { Name = "ES-Lab-RouteTable-A" }
}

resource "aws_route_table_association" "rta_a" {
  subnet_id      = aws_subnet.subnet_a.id
  route_table_id = aws_route_table.rt_a.id
}

resource "aws_route_table" "rt_b" {
  vpc_id = aws_vpc.vpc_b.id
  route {
    cidr_block                = aws_vpc.vpc_a.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
  route {
    cidr_block                = "10.245.0.0/17"
    vpc_peering_connection_id = aws_vpc_peering_connection.peer.id
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_b.id
  }
  tags = { Name = "ES-Lab-RouteTable-B" }
}

resource "aws_route_table_association" "rta_b" {
  subnet_id      = aws_subnet.subnet_b.id
  route_table_id = aws_route_table.rt_b.id
}

# ── Security Group: Control Plane (VPC-A) ─────────────────

resource "aws_security_group" "sg_control_plane" {
  name        = "es-lab-k8s-control-plane"
  description = "K8s control plane node"
  vpc_id      = aws_vpc.vpc_a.id

  ingress {
    description = "K8s API server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "etcd"
    from_port   = 2379
    to_port     = 2380
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }

  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "kube-scheduler"
    from_port   = 10259
    to_port     = 10259
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }

  ingress {
    description = "kube-controller-manager"
    from_port   = 10257
    to_port     = 10257
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }

  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ES-Lab-SG-ControlPlane" }
}

# ── Security Group: Worker Node (VPC-B) ───────────────────

resource "aws_security_group" "sg_worker" {
  name        = "es-lab-k8s-worker"
  description = "K8s worker node"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    description = "kubelet API"
    from_port   = 10250
    to_port     = 10250
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "NodePort services"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "Flannel VXLAN"
    from_port   = 8472
    to_port     = 8472
    protocol    = "udp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block, aws_vpc.vpc_b.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ES-Lab-SG-Worker" }
}

# ── Security Groups: SSM Endpoints ────────────────────────

resource "aws_security_group" "ssm_endpoints_a" {
  name        = "es-lab-ssm-endpoints-vpc-a"
  description = "Allow HTTPS from VPC-A to SSM endpoints"
  vpc_id      = aws_vpc.vpc_a.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_a.cidr_block]
  }
  tags = { Name = "ES-Lab-SSM-Endpoints-A" }
}

resource "aws_security_group" "ssm_endpoints_b" {
  name        = "es-lab-ssm-endpoints-vpc-b"
  description = "Allow HTTPS from VPC-B to SSM endpoints"
  vpc_id      = aws_vpc.vpc_b.id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.vpc_b.cidr_block]
  }
  tags = { Name = "ES-Lab-SSM-Endpoints-B" }
}

# ── SSM VPC Endpoints: VPC-A ──────────────────────────────

resource "aws_vpc_endpoint" "ssm_a" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_a.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ssm-endpoint-vpc-a" }
}

resource "aws_vpc_endpoint" "ssmmessages_a" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_a.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ssmmessages-endpoint-vpc-a" }
}

resource "aws_vpc_endpoint" "ec2messages_a" {
  vpc_id              = aws_vpc.vpc_a.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_a.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_a.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ec2messages-endpoint-vpc-a" }
}

# ── SSM VPC Endpoints: VPC-B ──────────────────────────────

resource "aws_vpc_endpoint" "ssm_b" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_b.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ssm-endpoint-vpc-b" }
}

resource "aws_vpc_endpoint" "ssmmessages_b" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_b.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ssmmessages-endpoint-vpc-b" }
}

resource "aws_vpc_endpoint" "ec2messages_b" {
  vpc_id              = aws_vpc.vpc_b.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.subnet_b.id]
  security_group_ids  = [aws_security_group.ssm_endpoints_b.id]
  private_dns_enabled = true
  tags                = { Name = "ES-Lab-ec2messages-endpoint-vpc-b" }
}

# ── IAM Role for SSM ──────────────────────────────────────

resource "aws_iam_role" "ssm_role" {
  name = "es-lab-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm_profile" {
  name = "es-lab-ec2-ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# ── AMI ───────────────────────────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }
}

# ── EC2: Control Plane (VPC-A) ────────────────────────────

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_a.id
  vpc_security_group_ids = [aws_security_group.sg_control_plane.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Disable swap (required for K8s)
    swapoff -a
    sed -i '/swap/d' /etc/fstab

    # Load kernel modules
    cat <<MOD > /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MOD
    modprobe overlay
    modprobe br_netfilter

    # Kernel parameters for K8s networking
    cat <<SYS > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    SYS
    sysctl --system

    # Install containerd
    dnf install -y containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl enable --now containerd

    # Add Kubernetes repo
    cat <<REPO > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
    REPO

    # Install K8s components
    dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    systemctl enable kubelet

    # Signal that setup is complete
    echo "K8S_PREREQS_DONE" > /tmp/k8s-prereqs-status
    EOF
  )

  tags = { Name = "ES-Lab-ControlPlane", Role = "control-plane" }
}

# ── EC2: Worker Node (VPC-B) ──────────────────────────────

resource "aws_instance" "worker" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.subnet_b.id
  vpc_security_group_ids = [aws_security_group.sg_worker.id]
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Disable swap
    swapoff -a
    sed -i '/swap/d' /etc/fstab

    # Load kernel modules
    cat <<MOD > /etc/modules-load.d/k8s.conf
    overlay
    br_netfilter
    MOD
    modprobe overlay
    modprobe br_netfilter

    # Kernel parameters
    cat <<SYS > /etc/sysctl.d/k8s.conf
    net.bridge.bridge-nf-call-iptables  = 1
    net.bridge.bridge-nf-call-ip6tables = 1
    net.ipv4.ip_forward                 = 1
    SYS
    sysctl --system

    # Install containerd
    dnf install -y containerd
    mkdir -p /etc/containerd
    containerd config default > /etc/containerd/config.toml
    sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    systemctl enable --now containerd

    # Add Kubernetes repo
    cat <<REPO > /etc/yum.repos.d/kubernetes.repo
    [kubernetes]
    name=Kubernetes
    baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
    enabled=1
    gpgcheck=1
    gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
    REPO

    # Install K8s components
    dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
    systemctl enable kubelet

    # Signal that setup is complete
    echo "K8S_PREREQS_DONE" > /tmp/k8s-prereqs-status
    EOF
  )

  tags = { Name = "ES-Lab-Worker", Role = "worker" }
}
