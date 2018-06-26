variable "provider" {
  type        = "map"
  description = "AWS provider settings"

  default = {
    region  = ""
    profile = ""
  }
}

variable "application_name" {
  description = "Application name"
  default     = "Chef HA"
}

variable "default_tags" {
  type        = "map"
  description = "Default resource tags"

  default = {
    X-Production = false
  }
}

variable "vpc" {
  type        = "map"
  description = "VPC CIDR block"

  default = {
    cidr_block = ""
  }
}

variable "az_subnets" {
  type        = "map"
  description = "Availability zone subnets"
  default     = {}
}

variable "ssh_whitelist_cidrs" {
  type        = "list"
  description = "List of CIDRs to allow SSH"
  default     = ["0.0.0.0/0"]
}

variable "domain" {
  description = "Frontend ALB domain name"
  default     = ""
}

variable "frontend_hostname" {
  description = "Frontend ALB hostname name"
  default     = "chef"
}

variable "ami_user" {
  type        = "string"
  description = "Default username"

  default = "ubuntu"
}

variable "instance" {
  type        = "map"
  description = "AWS Instance settings"

  default = {
    backend_flavor  = "m5.large"
    backend_iops    = 0
    backend_public  = true
    backend_size    = 40
    backend_term    = true
    backend_type    = "gp2"
    ebs_optimized   = true
    frontend_flavor = "m5.large"
    frontend_iops   = 0
    frontend_public = true
    frontend_size   = 40
    frontend_term   = true
    frontend_type   = "gp2"
  }
}

variable "instance_hostname" {
  type        = "map"
  description = "Instance hostname prefix"

  default = {
    backend  = "chef-be"
    frontend = "chef-fe"
  }
}

variable "instance_keys" {
  type        = "map"
  description = ""

  default = {
    key_name = ""
    key_file = ""
  }
}

variable "chef_backend" {
  type        = "map"
  description = "Chef backend settings"

  default = {
    count   = 3
    version = "2.0.1"
  }
}

variable "chef_frontend" {
  type        = "map"
  description = "Chef frontend settings"

  default = {
    count   = 3
    version = "12.17.33"
  }
}

variable "r53_ttl" {
  type        = "string"
  description = "DNS record TTLS"

  default = "180"
}
