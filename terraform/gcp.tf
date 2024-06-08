variable "google_project" {
    description = "Google Project Name"
    type        = string
}

resource "google_storage_bucket" "bucket" {
 name          = lower(replace(var.project, "_", "-"))
 location      = "US"
 storage_class = "STANDARD"
 uniform_bucket_level_access = true
}


resource "google_project_iam_custom_role" "bucket-role" {
  role_id     = local.role_name
  title       = local.role_name
  description = "Grant Read Permissions on Buckets and Objects"
  permissions = ["storage.buckets.get", "storage.objects.get", "storage.objects.list"]
}


resource "google_project_iam_member" "bucket-role-binding" {
  role    = google_project_iam_custom_role.bucket-role.name
  project = var.google_project
  member  = "serviceAccount:${snowflake_storage_integration.gcs_integration.storage_gcp_service_account}"
}
   
resource "snowflake_storage_integration" "gcs_integration" {
  provider = snowflake.account_admin
  name    = upper("${var.project}_gcs_integration")
  comment = "GCP storage integration"
  type    = "EXTERNAL_STAGE"
  enabled = true
  storage_allowed_locations = ["gcs://${google_storage_bucket.bucket.name}"]
  storage_provider     = "GCS"
}    

resource "snowflake_stage" "gcs_external_stage" {
  provider = snowflake.account_admin
  name        = upper("${var.project}_GCS_STAGE")
  url         = "gcs://${google_storage_bucket.bucket.name}"
  database    = snowflake_database.ml_source_db.name
  schema      = snowflake_schema.ml_source_schema.name
  storage_integration = snowflake_storage_integration.gcs_integration.name
  directory = "ENABLE = true"  
}

resource "snowflake_table" "gcs_raw_table" {
  database                    = snowflake_database.ml_source_db.name
  schema                      = snowflake_schema.ml_source_schema.name
  name                        = "PARSED_GCS_PDF"
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

resource "snowflake_stream" "gcs_stream" {
  provider = snowflake.account_admin
  name     = upper("${var.project}_GCS_STREAM")
  on_stage = snowflake_stage.gcs_external_stage.name
  database = snowflake_database.ml_source_db.name
  schema   = snowflake_schema.ml_source_schema.name
  comment  = "GCS stream"
}
