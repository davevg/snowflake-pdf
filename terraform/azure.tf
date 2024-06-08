data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "snowflake_rg" {
  name     =  replace("${var.project}_rg","_","")
  location = "eastus"
}
 
resource "azurerm_storage_account" "snowflake_sa" {
  name                     = replace("${var.project}_sa","_","")
  resource_group_name      = azurerm_resource_group.snowflake_rg.name
  location                 = azurerm_resource_group.snowflake_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  lifecycle {
    ignore_changes = [
      tags["pmtest"]
    ]
  }
}
 
resource "azurerm_storage_container" "snowflake_container" {
  name                  = replace("${var.project}_container","_","")
  storage_account_name  = azurerm_storage_account.snowflake_sa.name
  container_access_type = "private"
}

resource "snowflake_storage_integration" "az_integration" {
  provider = snowflake.account_admin
  name    = upper("${var.project}_azure_integration")
  comment = "Azure storage integration"
  type    = "EXTERNAL_STAGE"
  enabled = true
  storage_allowed_locations = [format("%s%s", replace(azurerm_storage_account.snowflake_sa.primary_blob_endpoint, "https", "azure"),azurerm_storage_container.snowflake_container.name )]
  storage_provider     = "AZURE"
  azure_tenant_id = data.azurerm_client_config.current.tenant_id
}

resource "snowflake_stage" "azure_external_stage" {
  provider = snowflake.account_admin
  name        = upper("${var.project}_AZURE_STAGE")
  url         = format("%s%s", replace(azurerm_storage_account.snowflake_sa.primary_blob_endpoint, "https", "azure"),azurerm_storage_container.snowflake_container.name )
  database    = snowflake_database.ml_source_db.name
  schema      = snowflake_schema.ml_source_schema.name
  storage_integration = snowflake_storage_integration.az_integration.name
  directory = "ENABLE = true"  
}

resource "snowflake_table" "azure_raw_table" {
  database                    = snowflake_database.ml_source_db.name
  schema                      = snowflake_schema.ml_source_schema.name
  name                        = "PARSED_AZURE_PDF"
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

resource "snowflake_stream" "azure_stream" {
  provider = snowflake.account_admin
  name     = upper("${var.project}_AZURE_STREAM")
  on_stage = snowflake_stage.azure_external_stage.name
  database = snowflake_database.ml_source_db.name
  schema   = snowflake_schema.ml_source_schema.name
  comment  = "Azure stream"
}
