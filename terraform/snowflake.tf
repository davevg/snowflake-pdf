/* Schema */
resource "snowflake_schema" "ml_source_schema" {
  provider = snowflake.sysadmin
  database = snowflake_database.ml_source_db.name
  name     =  upper("${var.project}_schema")
}

/* Database */
resource "snowflake_database" "ml_source_db" {
  provider = snowflake.sysadmin
  name                        =  upper("${var.project}_db")
  data_retention_time_in_days = var.time_travel_in_days
}

resource "snowflake_warehouse" "warehouse" {
  provider = snowflake.sysadmin
  name           = upper("${var.project}_wh")
  warehouse_size = "XSMALL"
  initially_suspended = true
  auto_suspend   = 60
  auto_resume = true
}

resource "snowflake_function" "pdf_parser" {
  provider = snowflake.sysadmin
  name     = upper("${var.project}_udf")
  database = snowflake_database.ml_source_db.name
  schema   = snowflake_schema.ml_source_schema.name
  arguments {
    name = "FILENAME"
    type = "VARCHAR"
  }
  comment             = "Parse PDF Files"
  return_type         = "VARCHAR"
  null_input_behavior = "CALLED ON NULL INPUT"
  return_behavior     = "VOLATILE"
  language            = "python"
  runtime_version     = "3.8"
  handler             = "read_file"
  packages             = ["snowflake-snowpark-python","pypdf2"]
  statement           = file("${path.module}/templates/udf.tpl")
}
