data "aws_region" "current" {}

resource "aws_s3_bucket" "bucket" {
  bucket = replace(var.project, "_", "-")
  lifecycle {
    prevent_destroy = true
  }
}

data "aws_iam_policy_document" "snowflake_access" {
  statement {
    effect = "Allow"
    actions = [
        "s3:PutObject",
        "s3:GetObjectVersion",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion"
    ]
    resources = [
      aws_s3_bucket.bucket.arn,
      "${aws_s3_bucket.bucket.arn}/*",
    ]
  }
  statement {
    effect = "Allow"
    actions = [
        "s3:ListBucket",
        "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.bucket.arn
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = ["*"]
    } 
  }
} 


resource "aws_iam_policy" "policy" {
  name        =  "${var.project}_policy"
  description = "Policy to allow snowflake access to poc bucket"
  policy = data.aws_iam_policy_document.snowflake_access.json
}

resource "aws_iam_role" "snowflake_role" {
  name               = local.role_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Action" : "sts:AssumeRole"
        "Effect" : "Allow"
        "Principal" : {
          "AWS" : snowflake_storage_integration.integration.storage_aws_iam_user_arn
        }
        "Condition" : {
          "StringEquals" : {
            "sts:ExternalId" : snowflake_storage_integration.integration.storage_aws_external_id
          }
        }
      }
    ]
  })
   
}

resource "aws_iam_role_policy_attachment" "snowflake_policy_attachment" {
  role       = aws_iam_role.snowflake_role.name
  policy_arn = aws_iam_policy.policy.arn
}

resource "snowflake_storage_integration" "integration" {
  provider = snowflake.account_admin
  name    = upper("${var.project}_aws_integration")
  comment = "AWS storage integration"
  type    = "EXTERNAL_STAGE"
  enabled = true
  storage_allowed_locations = ["s3://${aws_s3_bucket.bucket.id}"]
  storage_provider     = "S3"
  storage_aws_role_arn = local.role_arn
}

resource "snowflake_stage" "aws_external_stage" {
  provider = snowflake.account_admin
  name        = upper("${var.project}_AWS_STAGE")
  url         = "s3://${aws_s3_bucket.bucket.id}"
  database    = snowflake_database.ml_source_db.name
  schema      = snowflake_schema.ml_source_schema.name
  storage_integration = snowflake_storage_integration.integration.name
  directory = "ENABLE = true"
  
}

resource "snowflake_stage_grant" "aws_external_stage_grant" {
  database_name = snowflake_stage.aws_external_stage.database
  schema_name   = snowflake_stage.aws_external_stage.schema
  roles         = ["SYSADMIN"]
  privilege     = "OWNERSHIP"
  stage_name    = snowflake_stage.aws_external_stage.name
}

/*
resource "snowflake_stream" "aws_stream" {
  provider = snowflake.account_admin
  name     = upper("${var.project}_AWS_STREAM")
  on_stage = snowflake_stage.aws_external_stage.name
  database = snowflake_database.ml_source_db.name
  schema   = snowflake_schema.ml_source_schema.name
  comment  = "AWS stream"
}
*/