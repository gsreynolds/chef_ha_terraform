# Frontend ALB

resource "aws_lb" "frontend" {
  name               = "${replace(local.alb_fqdn,".","-")}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.frontend.id}"]
  subnets            = ["${aws_subnet.az_subnets.*.id}"]

  access_logs {
    bucket  = "${aws_s3_bucket.logs.bucket}"
    prefix  = "alb"
    enabled = true
  }

  tags = "${merge(
    var.default_tags,
    map(
      "Name", "${local.deployment_name} Frontend Application Load Balancer"
    )
  )}"
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
      "Name", "${local.deployment_name} Frontend ALB Target Group"
    )
  )}"
}

resource "aws_lb_target_group_attachment" "frontend" {
  count            = "${var.chef_frontend["count"]}"
  target_group_arn = "${aws_lb_target_group.frontend.arn}"
  target_id        = "${element(aws_instance.frontends.*.id, count.index)}"
  port             = 443
}
