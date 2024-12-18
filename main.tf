locals {
  storage_account_prefix = "boots"
}

resource "random_string" "prefix" {
  length  = 6
  special = false
  upper   = false
  numeric = false
}

resource "random_string" "storage_account_suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
  numeric  = false
}

resource "azurerm_resource_group" "rg" {
  name     = var.name_prefix == null ? "${random_string.prefix.result}${var.resource_group_name}" : "${var.name_prefix}${var.resource_group_name}"
  location = var.location
  tags     = var.tags
}

module "log_analytics_workspace" {
  source                           = "./modules/log_analytics"
  name                             = var.name_prefix == null ? "${random_string.prefix.result}${var.log_analytics_workspace_name}" : "${var.name_prefix}${var.log_analytics_workspace_name}"
  location                         = var.location
  resource_group_name              = azurerm_resource_group.rg.name
  solution_plan_map                = var.solution_plan_map
  tags                             = var.tags
}

module "aiservices" {
  source =  "./modules/aiservices"
  name =  var.name_prefix == null ? "${random_string.prefix.result}${var.openai_name}" : "${var.name_prefix}${var.aiservices_name}"
  location                                 = var.location
  resource_group_name                      = azurerm_resource_group.rg.name
  sku_name                                 = var.aiservices_sku_name
  custom_subdomain_name                    = var.aiservices_custom_subdomain_name == "" || var.aiservices_custom_subdomain_name == null ? var.name_prefix == null ? lower("${random_string.prefix.result}${var.aiservices_name}") : lower("${var.name_prefix}${var.aiservices_name}") : lower(var.aiservices_custom_subdomain_name)
  public_network_access                    = var.aiservices_public_network_access
}

module "search_service" {
  source =  "./modules/search_service"
  name =  var.name_prefix == null ? "${random_string.prefix.result}${var.openai_name}" : "${var.name_prefix}${var.searchservice_name}"
  location                                 = var.location
  resource_group_name                      = azurerm_resource_group.rg.name
  sku_name                                 = var.searchservice_sku_name
}

module "openai" {
  source                                   = "./modules/openai"
  name                                     = var.name_prefix == null ? "${random_string.prefix.result}${var.openai_name}" : "${var.name_prefix}${var.openai_name}${random_string.prefix.result}"
  location                                 = var.location
  resource_group_name                      = azurerm_resource_group.rg.name
  sku_name                                 = var.openai_sku_name
  tags                                     = var.tags
  kind                                     ="OpenAI"
  deployments                              = var.openai_deployments
  custom_subdomain_name                    = var.openai_custom_subdomain_name == "" || var.openai_custom_subdomain_name == null ? var.name_prefix == null ? lower("${random_string.prefix.result}${var.openai_name}") : lower("${var.name_prefix}${var.openai_name}") : lower(var.openai_custom_subdomain_name)
  public_network_access_enabled            = var.openai_public_network_access_enabled
  log_analytics_workspace_id               = module.log_analytics_workspace.id
  log_analytics_retention_days             = var.log_analytics_retention_days
}

module "document_intelligence" {
  source                                   = "./modules/document_intelligence"
  name                                     = var.name_prefix == null ? "${random_string.prefix.result}${var.documentintelligence_name}" : "${var.name_prefix}${var.documentintelligence_name}"
  location                                 = var.location
  resource_group_name                      = azurerm_resource_group.rg.name
  sku_name                                 = "F0"
  tags                                     = var.tags
  custom_subdomain_name                    = var.documentintelligence_custom_subdomain_name == "" || var.documentintelligence_custom_subdomain_name == null ? var.name_prefix == null ? lower("${random_string.prefix.result}${var.documentintelligence_name}") : lower("${var.name_prefix}${var.documentintelligence_name}") : lower(var.documentintelligence_custom_subdomain_name)
  public_network_access_enabled            = var.openai_public_network_access_enabled
  log_analytics_workspace_id               = module.log_analytics_workspace.id
  log_analytics_retention_days             = var.log_analytics_retention_days
}

module "storage_account" {
  source                      = "./modules/storage_account"
  name                        = "${local.storage_account_prefix}${random_string.storage_account_suffix.result}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  account_kind                = var.storage_account_kind
  account_tier                = var.storage_account_tier
  replication_type            = var.storage_account_replication_type
  tags                        = var.tags

}

resource "azurerm_user_assigned_identity" "openai_workload_identity" {
  name                = var.name_prefix == null ? "${random_string.prefix.result}${var.workload_managed_identity_name}" : "${var.name_prefix}${var.workload_managed_identity_name}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  tags                = var.tags

  lifecycle {
    ignore_changes = [
      tags
    ]
  }
}

resource "azurerm_role_assignment" "cognitive_services_user_assignment" {
  scope                = module.openai.id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.openai_workload_identity.principal_id
  skip_service_principal_aad_check = true
}
module "key_vault" {
  source                          = "./modules/key_vault"
  name                            = var.name_prefix == null ? "${random_string.prefix.result}${var.key_vault_name}" : "${var.name_prefix}${var.key_vault_name}${random_string.prefix.result}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.rg.name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = var.key_vault_sku_name
  enabled_for_deployment          = var.key_vault_enabled_for_deployment
  enabled_for_disk_encryption     = var.key_vault_enabled_for_disk_encryption
  enabled_for_template_deployment = var.key_vault_enabled_for_template_deployment
  enable_rbac_authorization       = var.key_vault_enable_rbac_authorization
  purge_protection_enabled        = var.key_vault_purge_protection_enabled
  soft_delete_retention_days      = var.key_vault_soft_delete_retention_days
  bypass                          = var.key_vault_bypass
  default_action                  = var.key_vault_default_action
  log_analytics_workspace_id      = module.log_analytics_workspace.id
  log_analytics_retention_days    = var.log_analytics_retention_days
  tags                            = var.tags
  public_network_access_enabled            = var.kv_public_network_access_enabled
}

########### Virtual Network ##########

module "virtual_network" {
  source                       = "./modules/virtual_network"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = var.location
  vnet_name                    = var.name_prefix == null ? "${random_string.prefix.result}${var.vnet_name}" : "${var.name_prefix}${var.vnet_name}"
  address_space                = var.vnet_address_space
  log_analytics_workspace_id   = module.log_analytics_workspace.id
  log_analytics_retention_days = var.log_analytics_retention_days
  tags                         = var.tags

  subnets = [
    {
      name : var.vm_subnet_name
      address_prefixes : var.vm_subnet_address_prefix
      private_endpoint_network_policies : "Enabled"
      private_link_service_network_policies_enabled : false
      delegation: null
    },
    {
      name : var.di_subnet_name
      address_prefixes : var.di_subnet_address_prefix
      private_endpoint_network_policies : "Enabled"
      private_link_service_network_policies_enabled : false
      delegation: null
    },

    {
      name : var.openai_subnet_name
      address_prefixes : var.openai_subnet_address_prefix
      private_endpoint_network_policies : "Enabled"
      private_link_service_network_policies_enabled : false
      delegation: null
    },

    {
      name : var.aiservice_subnet_name
      address_prefixes : var.aiservice_subnet_address_prefix
      private_endpoint_network_policies : "Enabled"
      private_link_service_network_policies_enabled : false
      delegation: null
    }
  ]
}

############ Private Endpoint ############

module "aiservices_private_endpoint" {

  providers = {
    azurerm.hub_network       = azurerm.hub_network
    azurerm                   = azurerm
  }

  source                         = "./modules/private_endpoint"
  name                           = "${module.aiservices.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.aiservices.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.aiservices.azure.com"
  private_dns_zone_group_ids     = [module.aiservices_private_dns_zone.id]
}
module "aiservices_private_endpoint_to_hub" {
  providers = {
    azurerm                   = azurerm
    azurerm.hub_network       = azurerm.hub_network
  }

  source                         = "./modules/private_endpoint"
  island_landingzone             = true
  name                           = "{$var.name_prefix}-island-hub-2-spoke" == null ? "${random_string.prefix.result}AIServicesPrivateEndpoint" : "${var.name_prefix}AIServicesPrivateEndpoint"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.hub_network_pe.name
  subnet_id                      = data.azurerm_subnet.hub_network_vnet_subnet-pe-island.id
  tags                           = var.tags
  private_connection_resource_id = module.aiservices.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.aiservices.azure.com"
  private_dns_zone_group_ids     = ["/subscriptions/9f970f45-460a-4159-ab7f-6d5ffea59acb/resourceGroups/rg-private-dns-zoneswesteurope/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"]
}
module "openai_private_endpoint" {

  providers = {
    azurerm.hub_network       = azurerm.hub_network
    azurerm                   = azurerm
  }

  source                         = "./modules/private_endpoint"
  name                           = "${module.openai.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.openai.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.openai.azure.com"
  private_dns_zone_group_ids     = [module.openai_private_dns_zone.id]
}
module "openai_private_endpoint_to_hub" {
  providers = {
    azurerm                   = azurerm
    azurerm.hub_network       = azurerm.hub_network
  }

  source                         = "./modules/private_endpoint"
  island_landingzone             = true
  name                           = "{$var.name_prefix}-island-hub-2-spoke" == null ? "${random_string.prefix.result}OpenaiPrivateEndpoint" : "${var.name_prefix}OpenaiPrivateEndpoint"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.hub_network_pe.name
  subnet_id                      = data.azurerm_subnet.hub_network_vnet_subnet-pe-island.id
  tags                           = var.tags
  private_connection_resource_id = module.openai.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.openai.azure.com"
  private_dns_zone_group_ids     = ["/subscriptions/9f970f45-460a-4159-ab7f-6d5ffea59acb/resourceGroups/rg-private-dns-zoneswesteurope/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com"]
}

module "document_intelligence_private_endpoint" {

  providers = {
    azurerm.hub_network       = azurerm.hub_network
    azurerm                   = azurerm
  }

  source                         = "./modules/private_endpoint"
  name                           = "${module.document_intelligence.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.document_intelligence.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.documentintelligence.azure.com"
  private_dns_zone_group_ids     = [module.document_intelligence_private_dns_zone.id]
}

module "document_intelligence_private_endpoint_to_hub" {
  providers = {
    azurerm                   = azurerm
    azurerm.hub_network       = azurerm.hub_network
  }

  source                         = "./modules/private_endpoint"
  island_landingzone             = true
  name                           = "{$var.name_prefix}-island-hub-2-spoke" == null ? "${random_string.prefix.result}DocumentIntelligencePrivateEndpoint" : "${var.name_prefix}DocumentIntelligencePrivateEndpoint"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.hub_network_pe.name
  subnet_id                      = data.azurerm_subnet.hub_network_vnet_subnet-pe-island.id
  tags                           = var.tags
  private_connection_resource_id = module.document_intelligence.id
  is_manual_connection           = false
  subresource_name               = "account"
  private_dns_zone_group_name    = "privatelink.documentintelligence.azure.com"
  private_dns_zone_group_ids     = ["/subscriptions/8183f26d-8d65-42c0-8ac9-9e08e98b04d3/resourceGroups/fti-rg/providers/Microsoft.Network/privateDnsZones/privatelink.documentintelligence.azure.com"]
}
module "key_vault_private_endpoint" {

  providers = {
    azurerm.hub_network       = azurerm.hub_network
    azurerm                   = azurerm
  }

  source                         = "./modules/private_endpoint"
  name                           = "${module.key_vault.name}PrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.key_vault.id
  is_manual_connection           = false
  subresource_name               = "vault"
  private_dns_zone_group_name    = "KeyVaultPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.key_vault_private_dns_zone.id]
}

module "key_vault_private_endpoint_to_hub" {
  providers = {
    azurerm                   = azurerm
    azurerm.hub_network       = azurerm.hub_network
  }

  source                         = "./modules/private_endpoint"
  island_landingzone             = true
  name                           = "{$var.name_prefix}-island-hub-2-spoke" == null ? "${random_string.prefix.result}KeyVaultPrivateEndpoint" : "${var.name_prefix}KeyVaultPrivateEndpoint"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.hub_network_pe.name
  subnet_id                      = data.azurerm_subnet.hub_network_vnet_subnet-pe-island.id
  tags                           = var.tags
  private_connection_resource_id = module.key_vault.id
  is_manual_connection           = false
  subresource_name               = "vault"
  private_dns_zone_group_name    = "KeyVaultPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = ["/subscriptions/466ce7f0-3533-463f-af93-cbee13fdd0fc/resourceGroups/rg_infraprodhub_az1dns01/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net"]
}

module "blob_private_endpoint" {

  providers = {
    azurerm.hub_network       = azurerm.hub_network
    azurerm                   = azurerm
  }

  source                         = "./modules/private_endpoint"
  name                           = var.name_prefix == null ? "${random_string.prefix.result}BlocStoragePrivateEndpoint" : "${var.name_prefix}BlobStoragePrivateEndpoint"
  location                       = var.location
  resource_group_name            = azurerm_resource_group.rg.name
  subnet_id                      = module.virtual_network.subnet_ids[var.vm_subnet_name]
  tags                           = var.tags
  private_connection_resource_id = module.storage_account.id
  is_manual_connection           = false
  subresource_name               = "blob"
  private_dns_zone_group_name    = "BlobPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = [module.blob_private_dns_zone.id]
}

module "blob_private_endpoint_to_hub" {
  providers = {
    azurerm                   = azurerm
    azurerm.hub_network       = azurerm.hub_network
  }

  source                         = "./modules/private_endpoint"
  island_landingzone             = true
  name                           = "{$var.name_prefix}-island-hub-2-spoke" == null ? "${random_string.prefix.result}BlobStoragePrivateEndpoint" : "${var.name_prefix}BlobStoragePrivateEndpoint"
  location                       = var.location
  resource_group_name            = data.azurerm_resource_group.hub_network_pe.name
  subnet_id                      = data.azurerm_subnet.hub_network_vnet_subnet-pe-island.id
  tags                           = var.tags
  private_connection_resource_id = module.storage_account.id
  is_manual_connection           = false
  subresource_name               = "blob"
  private_dns_zone_group_name    = "BlobPrivateDnsZoneGroup"
  private_dns_zone_group_ids     = ["/subscriptions/466ce7f0-3533-463f-af93-cbee13fdd0fc/resourceGroups/rg_infraprodhub_az1dns01/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"]
}

############ Private DNS #############


module "aiservices_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.aiservices.azure.com"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}
module "openai_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.openai.azure.com"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}

module "document_intelligence_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.documentintelligence.azure.com"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}


module "key_vault_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.vaultcore.azure.net"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}

module "blob_private_dns_zone" {
  source                       = "./modules/private_dns_zone"
  name                         = "privatelink.blob.core.windows.net"
  resource_group_name          = azurerm_resource_group.rg.name
  tags                         = var.tags
  virtual_networks_to_link     = {
    (module.virtual_network.name) = {
      subscription_id = data.azurerm_client_config.current.subscription_id
      resource_group_name = azurerm_resource_group.rg.name
    }
  }
}


############## Web App ##############

# module "service_webapp" {
#   source = "./modules/linux_webapp"
#   resource_group_name          = azurerm_resource_group.rg.name
#   location = var.location
#   serviceplan_name = "Azure-SP-${random_string.prefix.result}"
#   webapp_name = "fti-webapp"
# }

# module "service_webapp_admin" {
#   source = "./modules/linux_webapp"
#   resource_group_name          = azurerm_resource_group.rg.name
#   location = var.location
#   serviceplan_name = "Azure-SP-${random_string.prefix.result}"
#   webapp_name = "fti-webapp-admin"
# }

