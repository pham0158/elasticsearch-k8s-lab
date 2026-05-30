variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for K8s nodes"
  type        = string
  default     = "t3.medium"
}

variable "vpc_a_cidr" {
  description = "CIDR for VPC-A (control plane)"
  type        = string
  default     = "10.2.0.0/16"
}

variable "vpc_b_cidr" {
  description = "CIDR for VPC-B (worker)"
  type        = string
  default     = "10.3.0.0/16"
}

variable "pod_network_cidr" {
  description = "Pod network CIDR for Flannel"
  type        = string
  default     = "10.245.0.0/16"
}
