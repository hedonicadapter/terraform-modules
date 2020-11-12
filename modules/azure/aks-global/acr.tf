# Create Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "acr${var.environment}${var.location_short}${var.aks_name}"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# Add AcrPull permission for the AKS Service Principal (Client)
# This makes it possible for the AKS cluster to pull images without additional authentication

# MOVE TO AKS
# resource "azurerm_role_assignment" "aks" {
#   scope                = azurerm_container_registry.acr.id
#   role_definition_name = "AcrPull"
#   principal_id         = local.aksAadApps.aksClientAppPrincipalId #FIXME
# }

# Add data source for the Azure AD Group for AcrPull
data "azuread_group" "acr_pull" {
  name = "aks-${var.subscription_name}-${var.environment}-acrpull"
}

# Add data source for the Azure AD Group for AcrPush
data "azuread_group" "acr_push" {
  name = "aks-${var.subscription_name}-${var.environment}-acrpush"
}

# Assign AcrPull permissions to the Azure AD Group for AcrPull
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = data.azuread_group.acr_pull.id
}

# Assign AcrPush permissions to the Azure AD Group for AcrPull
resource "azurerm_role_assignment" "acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = data.azuread_group.acr_push.id
}
