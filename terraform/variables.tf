/* Snowflake Variables */
variable "snowflake_schema_name" {
  type    = string
  default = "ml_ingestion_schema"
}

variable "snowflake_database_name" {
  type    = string
  default = "ml_ingestion_db"
}

variable "time_travel_in_days" {
  type        = number
  description = "Number of days for time travel feature"
  default     = 1
}

/* AWS Variables */

variable "aws_region" {
  description = "The AWS region in which the AWS infrastructure is created."
  type        = string
  default     = "us-east-1"
}

variable "data_bucket_arns" {
  type        = list(string)
  default     = []
  description = "List of Bucket ARNs for the s3_reader role to read from."
}

data "aws_caller_identity" "current" {}

variable "common_tags" {
    type        = map(string)
    description = "Common tags to apply to all resources."
    default     = {}
}


variable "project" {
  type        = string
  description = "The name of the project."
}
