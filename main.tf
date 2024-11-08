# Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "ddeptula-aks-cluster"
  location = "East US"
}

# Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aksCluster"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aksdns"

  default_node_pool {
    name           = "default"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics.id
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr = "10.0.3.0/24"
    dns_service_ip = "10.0.3.10"
  }

}

# Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "ddeptulap3acr"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"
  admin_enabled       = true
}

# Assign AKS Cluster Access to ACR
resource "azurerm_role_assignment" "aks_acr_access" {
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
  role_definition_name = "AcrPull"
  scope                = azurerm_container_registry.acr.id
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "aksLogAnalytics"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
}

# Application Insights (needed for Azure Functions)
resource "azurerm_application_insights" "app_insights" {
  name                = "aksAppInsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"
}

# Virtual Network for AKS and Application Gateway
resource "azurerm_virtual_network" "aks_vnet" {
  name                = "aksVNet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"] # Define the VNet address space
}


resource "azurerm_subnet" "aks_subnet" {
  name                 = "aksSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks_vnet.name
  address_prefixes     = ["10.0.1.0/24"] # AKS Subet
}


# Action Group for Alerts (e.g., Email, Slack, Teams)
resource "azurerm_monitor_action_group" "alert_action_group" {
  name                = "aksAlertActionGroup"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "aksAlerts"

  email_receiver {
    name          = "emailAlert"
    email_address = "ddeptula01@gmail.com"
  }
}

# Storage Account for Function App
resource "azurerm_storage_account" "function_storage" {
  name                     = "aksfuncstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Function App Service Plan
resource "azurerm_app_service_plan" "function_plan" {
  name                = "aksFuncPlan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}

# Function App
resource "azurerm_function_app" "function_app" {
  name                       = "aksAlertFunction"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  app_service_plan_id        = azurerm_app_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  os_type                    = "linux"

  app_settings = {
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
    "FUNCTIONS_WORKER_RUNTIME"       = "dotnet"
  }
}
