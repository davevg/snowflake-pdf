locals {
    role_name = "${var.project}_role"
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.role_name}"
}