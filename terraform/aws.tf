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

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.bucket.id

  queue {
    id            = "file-upload-event"
    queue_arn     = local.sqs_notifier_arn
    events        = ["s3:ObjectCreated:*"]
  }

}



resource "aws_iam_policy" "policy" {
  name        =  "${var.project}_policy"
  description = "Policy to allow snowflake access to poc bucket"
  policy = data.aws_iam_policy_document.snowflake_access.json
}

/* Temp Role for Snowflake, is replaced by null_resource */
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
  directory = "ENABLE = true AUTO_REFRESH = true"
  // Need to ignore changes for this. once applied it generates a sqs queue which is listed.
  lifecycle {
   ignore_changes = [
    directory
   ]
 }
}

resource "snowflake_stage_grant" "aws_external_stage_grant" {
  database_name = snowflake_stage.aws_external_stage.database
  schema_name   = snowflake_stage.aws_external_stage.schema
  roles         = ["SYSADMIN"]
  privilege     = "OWNERSHIP"
  stage_name    = snowflake_stage.aws_external_stage.name
}

locals {
  arn_regex_pattern = "arn:aws:[a-zA-Z0-9-]+:[a-z0-9-]+:[0-9]{12}:[a-zA-Z0-9-_]+"
  arn_regex_result = regexall(local.arn_regex_pattern, snowflake_stage.aws_external_stage.directory)
  sqs_notifier_arn = length(local.arn_regex_result) > 0 ? local.arn_regex_result[0] : ""

}
output "stage_sqs_notify" {
    value = local.sqs_notifier_arn
}

resource "snowflake_stream" "aws_stream" {
  provider = snowflake.account_admin
  name     = upper("${var.project}_AWS_STREAM")
  on_stage = snowflake_stage.aws_external_stage.name
  database = snowflake_database.ml_source_db.name
  schema   = snowflake_schema.ml_source_schema.name
  comment  = "AWS S3 File Update Stream"
}

resource "snowflake_task" "task" {
  comment = "Task to process new S3 pdf files"
  database  = snowflake_database.ml_source_db.name
  schema    = snowflake_schema.ml_source_schema.name
  warehouse = snowflake_warehouse.warehouse.name
  name          = upper("${var.project}_AWS_TASK")
  schedule      = "USING CRON 0 5 * * * America/New_York"
  sql_statement = "INSERT into PARSED_AWS_PDF select relative_path, file_url, ${snowflake_function.pdf_parser.name}(build_scoped_file_url(@${snowflake_stage.aws_external_stage.name}, relative_path)) as parsed_text from ${snowflake_stream.aws_stream.name}"
  enabled       = true
}


resource "snowflake_table" "aws_raw_table" {
  database                    = snowflake_database.ml_source_db.name
  schema                      = snowflake_schema.ml_source_schema.name
  name                        = "PARSED_AWS_PDF"
  comment                     = "Table containing raw text from the pdf"
  data_retention_time_in_days = 1
  change_tracking             = false
  column {
    name     = "RELATIVE_PATH"
    type     = "VARCHAR(16777216)"
    nullable = true
  }
  column {
    name     = "FILE_URL"
    type     = "VARCHAR(16777216)"
    nullable = true
  }
  column {
    name     = "PARSED_TEXT"
    type     = "VARCHAR(16777216)"
    nullable = true
  }
}