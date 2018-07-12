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
}

resource "aws_eip" "backends" {
  vpc        = true
  count      = "${var.chef_backend["count"]}"
  instance   = "${element(aws_instance.backends.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.main"]

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["backend"], count.index + 1, var.domain)}"
    )
  )}"
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
}

resource "aws_eip" "frontends" {
  vpc        = true
  count      = "${var.chef_frontend["count"]}"
  instance   = "${element(aws_instance.frontends.*.id, count.index)}"
  depends_on = ["aws_internet_gateway.main"]

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${format("%s%02d.%s", var.instance_hostname["frontend"], count.index + 1, var.domain)}"
    )
  )}"
}
