data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "logs" {
  bucket = "${var.log_bucket}"
  acl    = "private"
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = "${aws_s3_bucket.logs.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "${var.log_bucket}-alb-logs",
  "Statement": [
    {
      "Sid": "AllowELBPutObject",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${var.elb_account_id}:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${var.log_bucket}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }
  ]
}
POLICY
}
