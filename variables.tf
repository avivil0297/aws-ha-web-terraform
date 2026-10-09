variable "public_subnet_cidrs" {
  description = "CIDRs for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 subnets are required - one per AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.0.30.0/24", "10.0.40.0/24"]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly 2 subnets are required - one per AZ."
  }
}


variable "single_nat_gateway" {
  description = "true = one NAT for all AZs (cheaper, not HA). false = NAT per AZ (HA)"
  type        = bool
  default     = false
}
variable "admin_cidr" {
  description = "Your public IP in CIDR form (x.x.x.x/32) - the only source allowed to SSH to the bastion"
  type        = string
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a single IPv4 address in CIDR form, e.g. 203.0.113.10/32."
  }

}

variable "bastion_public_key_path" {
  description = "Path to the bastion SSH public key"
  type        = string
  default     = "~/.ssh/final-lab-bastion.pub"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name shown on the web servers"
  type        = string
  default     = "final-lab"
}

variable "instance_type" {
  description = "EC2 instance type for bastion and web servers"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "instance_type must be t3.micro or t3.small (cost control)."
  }
}
