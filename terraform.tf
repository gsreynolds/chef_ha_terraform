provider "aws" {
  region  = "${var.provider["region"]}"
  profile = "${var.provider["profile"]}"
}

locals {
  deployment_name = "${var.application_name}"
  alb_fqdn        = "${var.frontend_hostname}.${var.domain}"
}
