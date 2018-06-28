data "aws_route53_zone" "zone" {
  name         = "${var.domain}."
  private_zone = false
}

resource "aws_route53_record" "backends" {
  count   = "${var.chef_backend["count"]}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.backends.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_instance.backends.*.public_ip, count.index)}"]
}

resource "aws_route53_record" "frontend" {
  count   = "${var.chef_frontend["count"]}"
  zone_id = "${data.aws_route53_zone.zone.id}"
  name    = "${element(aws_instance.frontends.*.tags.Name, count.index)}"
  type    = "A"
  ttl     = "${var.r53_ttl}"
  records = ["${element(aws_instance.frontends.*.public_ip, count.index)}"]
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
