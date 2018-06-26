provider "aws" {
  region  = "${var.provider["region"]}"
  profile = "${var.provider["profile"]}"
}

locals {
  deployment_name = "${var.application_name}"
  alb_fqdn        = "${var.frontend_hostname}.${var.domain}"

  security_group_ids = ["${aws_security_group.ssh.id}", "${aws_security_group.frontend.id}", "${aws_security_group.backend.id}"]
}

resource "aws_vpc" "main" {
  cidr_block = "${var.vpc["cidr_block"]}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} VPC"
    )
  )}"
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Gateway"
    )
  )}"
}

resource "aws_subnet" "az_subnets" {
  count                   = "${length(keys(var.az_subnets))}"
  vpc_id                  = "${aws_vpc.main.id}"
  availability_zone       = "${element(keys(var.az_subnets), count.index)}"
  cidr_block              = "${element(values(var.az_subnets), count.index)}"
  map_public_ip_on_launch = true

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Subnet - ${element(keys(var.az_subnets), count.index)}"
    )
  )}"
}

resource "aws_route" "default_gateway" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  gateway_id             = "${aws_internet_gateway.main.id}"
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "subnet_routes" {
  count          = "${length(keys(var.az_subnets))}"
  subnet_id      = "${element(aws_subnet.az_subnets.*.id, count.index)}"
  route_table_id = "${aws_vpc.main.main_route_table_id}"
}

data "aws_route53_zone" "zone" {
  name         = "${var.domain}."
  private_zone = false
}

# Security Groups Ingress

## SSH

resource "aws_security_group" "ssh" {
  name        = "${local.deployment_name} SSH SG"
  description = "${local.deployment_name} SSH SG"
  vpc_id      = "${aws_vpc.main.id}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} SSH SG"
    )
  )}"
}

resource "aws_security_group_rule" "restrict_ssh_ingress" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = "${var.ssh_whitelist_cidrs}"
  security_group_id = "${aws_security_group.ssh.id}"
}

resource "aws_security_group_rule" "allow_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  security_group_id = "${aws_security_group.ssh.id}"
}

## Frontend
resource "aws_security_group" "frontend" {
  name        = "${local.deployment_name} Frontend SG"
  description = "${local.deployment_name} Frontend SG"
  vpc_id      = "${aws_vpc.main.id}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Frontend SG"
    )
  )}"
}

resource "aws_security_group_rule" "allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.frontend.id}"
}

## Backend
resource "aws_security_group" "backend" {
  name        = "${local.deployment_name} Backend SG"
  description = "${local.deployment_name} Backend SG"
  vpc_id      = "${aws_vpc.main.id}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Backend SG"
    )
  )}"
}

resource "aws_security_group_rule" "backend_sg_all" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = "${aws_security_group.backend.id}"
  security_group_id        = "${aws_security_group.backend.id}"
}

## etcd
resource "aws_security_group_rule" "backend_2379_tcp" {
  type                     = "ingress"
  from_port                = 2379
  to_port                  = 2379
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.frontend.id}"
  security_group_id        = "${aws_security_group.backend.id}"
}

## postgresql
resource "aws_security_group_rule" "backend_5432_tcp" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.frontend.id}"
  security_group_id        = "${aws_security_group.backend.id}"
}

## leaderl
resource "aws_security_group_rule" "backend_7331_tcp" {
  type                     = "ingress"
  from_port                = 7331
  to_port                  = 7331
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.frontend.id}"
  security_group_id        = "${aws_security_group.backend.id}"
}

## elasticsearch
resource "aws_security_group_rule" "backend_9200_tcp" {
  type                     = "ingress"
  from_port                = 9200
  to_port                  = 9200
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.frontend.id}"
  security_group_id        = "${aws_security_group.backend.id}"
}

# Instances

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "backends" {
  count                       = "${var.chef_backend["count"]}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  ebs_optimized               = "${var.instance["ebs_optimized"]}"
  instance_type               = "${var.instance["backend_flavor"]}"
  associate_public_ip_address = "${var.instance["backend_public"]}"
  subnet_id                   = "${element(aws_subnet.az_subnets.*.id, count.index % length(keys(var.az_subnets)))}"
  vpc_security_group_ids      = ["${aws_security_group.backend.id}", "${aws_security_group.ssh.id}"]
  key_name                    = "${var.instance_keys["key_name"]}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["backend"], count.index + 1, var.domain)}"
    )
  )}"

  root_block_device {
    delete_on_termination = "${var.instance["backend_term"]}"
    volume_size           = "${var.instance["backend_size"]}"
    volume_type           = "${var.instance["backend_type"]}"
    iops                  = "${var.instance["backend_iops"]}"
  }

  connection {
    host        = "${self.public_ip}"
    user        = "${var.ami_user}"
    private_key = "${file("${var.instance_keys["key_file"]}")}"
  }

  # Install
  provisioner "remote-exec" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-backend -d /tmp -v ${var.chef_backend["version"]}",
    ]
  }

  # Configure
  provisioner "remote-exec" {
    inline = [
      "echo 'publish_address \"${self.private_ip}\"'|sudo tee -a /etc/chef-backend/chef-backend.rb",
      "echo 'postgresql.md5_auth_cidr_addresses = [\"samehost\",\"samenet\",\"${var.vpc["cidr_block"]}\"]'|sudo tee -a /etc/chef-backend/chef-backend.rb",
    ]
  }

  # echo next steps
  provisioner "remote-exec" {
    inline = [
      "echo 'Visit: https://docs.chef.io/install_server_ha.html'",
      "echo 'Leader (BE1): sudo chef-backend-ctl create-cluster'",
      "echo 'Leader (BE1): scp /etc/chef-backend/chef-backend-secrets.json ${var.ami_user}@<BE[2,3]_IP>:'",
      "echo 'Follower (BE[2,3]): sudo chef-backend-ctl join-cluster <BE1_IP> --accept-license -s chef-backend-secrets.json -y'",
      "echo 'All BEs: sudo rm chef-backend-secrets.json'",
      "echo 'All BEs: sudo chef-backend-ctl status'",
      "echo 'For FE[1,2,3]: sudo chef-backend-ctl gen-server-config <FE_FQDN> -f chef-server.rb.FE_NAME'",
      "echo 'For FE[1,2,3]: scp chef-server.rb.FE_NAME USER@<IP_FE[1,2,3]>:'",
    ]
  }
}

resource "aws_route53_record" "backends" {
  count   = "${var.chef_backend["count"]}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.backends.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_instance.backends.*.public_ip, count.index)}"]
}

resource "aws_instance" "frontends" {
  count                       = "${var.chef_frontend["count"]}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  ebs_optimized               = "${var.instance["ebs_optimized"]}"
  instance_type               = "${var.instance["frontend_flavor"]}"
  associate_public_ip_address = "${var.instance["frontend_public"]}"
  subnet_id                   = "${element(aws_subnet.az_subnets.*.id, count.index % length(keys(var.az_subnets)))}"
  vpc_security_group_ids      = ["${aws_security_group.frontend.id}", "${aws_security_group.ssh.id}"]
  key_name                    = "${var.instance_keys["key_name"]}"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["frontend"], count.index + 1, var.domain)}"
    )
  )}"

  root_block_device {
    delete_on_termination = "${var.instance["frontend_term"]}"
    volume_size           = "${var.instance["frontend_size"]}"
    volume_type           = "${var.instance["frontend_type"]}"
    iops                  = "${var.instance["frontend_iops"]}"
  }

  connection {
    host        = "${self.public_ip}"
    user        = "${var.ami_user}"
    private_key = "${file("${var.instance_keys["key_file"]}")}"
  }

  provisioner "remote-exec" {
    inline = [
      "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-server -d /tmp -v ${var.chef_frontend["version"]}",
    ]
  }

  # echo next steps
  provisioner "remote-exec" {
    inline = [
      "echo 'Visit: https://docs.chef.io/install_server_ha.html'",
      "echo 'All FEs: sudo cp chef-server.rb /etc/opscode/chef-server.rb'",
      "echo 'FE1: sudo chef-server-ctl reconfigure'",
      "echo 'FE1: scp /etc/opscode/private-chef-secrets.json ${var.ami_user}@<FE[2,3]_IP>:'",
      "echo 'FE1: scp /var/opt/opscode/upgrades/migration-level ${var.ami_user}@<FE[2,3_IP>:'",
      "echo 'FE[2,3]: sudo cp private-chef-secrets.json /etc/opscode/private-chef-secrets.json'",
      "echo 'FE[2,3]: sudo mkdir -p /var/opt/opscode/upgrades/'",
      "echo 'FE[2,3]: sudo cp migration-level /var/opt/opscode/upgrades/migration-level'",
      "echo 'FE[2,3]: sudo touch /var/opt/opscode/bootstrapped'",
      "echo 'FE[2,3]: sudo chef-server-ctl reconfigure'",
    ]
  }
}

resource "aws_route53_record" "frontend" {
  count   = "${var.chef_frontend["count"]}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.frontends.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_instance.frontends.*.public_ip, count.index)}"]
}

# Frontend ALB
resource "aws_acm_certificate" "alb" {
  domain_name       = "${local.alb_fqdn}"
  validation_method = "DNS"
}

resource "aws_route53_record" "cert_validation" {
  name    = "${aws_acm_certificate.alb.domain_validation_options.0.resource_record_name}"
  type    = "${aws_acm_certificate.alb.domain_validation_options.0.resource_record_type}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  records = ["${aws_acm_certificate.alb.domain_validation_options.0.resource_record_value}"]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = "${aws_acm_certificate.alb.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation.fqdn}"]
}

resource "aws_lb" "frontend" {
  name               = "${replace(local.alb_fqdn,".","-")}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.frontend.id}"]
  subnets            = ["${aws_subnet.az_subnets.*.id}"]
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = "${aws_lb.frontend.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = "${aws_acm_certificate.alb.arn}"

  default_action {
    target_group_arn = "${aws_lb_target_group.frontend.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group" "frontend" {
  name     = "chef-ha-frontend-tg"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = "${aws_vpc.main.id}"

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTPS"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 5
    matcher             = "200-209"
  }

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Frontend Target Group"
    )
  )}"
}

resource "aws_lb_target_group_attachment" "frontend" {
  count            = "${var.chef_frontend["count"]}"
  target_group_arn = "${aws_lb_target_group.frontend.arn}"
  target_id        = "${element(aws_instance.frontends.*.id, count.index)}"
  port             = 443
}

resource "aws_route53_record" "alb" {
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${local.alb_fqdn}"
  type    = "CNAME"
  ttl     = "${var.r53_ttl}"
  records = ["${aws_lb.frontend.dns_name}"]
}

resource "aws_route53_health_check" "frontend" {
  count             = "${var.chef_frontend["count"]}"
  fqdn              = "${element(aws_instance.frontends.*.tags.Name, count.index)}"
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} ${element(aws_instance.frontends.*.tags.Name, count.index)} Health Check"
    )
  )}"
}
