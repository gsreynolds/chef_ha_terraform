resource "aws_acm_certificate" "alb" {
  domain_name       = "${local.alb_fqdn}"
  validation_method = "DNS"

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Frontend Certificate"
    )
  )}"
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
