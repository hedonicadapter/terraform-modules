module "lz_vending" {
  source  = "Azure/lz-vending/azurerm"
  version = "5.1.2"

  location = "westeurope"

  subscription_alias_enabled = true
  subscription_billing_scope = "/providers/Microsoft.Billing/billingAccounts/1234567/enrollmentAccounts/123456"
  subscription_display_name  = "my-subscription-display-name"
  subscription_alias_name    = "my-subscription-alias"
  subscription_workload      = "Production"

  virtual_network_enabled = true
  virtual_networks = {
    one = {
      name                    = "my-vnet"
      address_space           = ["192.168.1.0/24"]
      hub_peering_enabled     = true
      hub_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-hub-network-rg/providers/Microsoft.Network/virtualNetworks/my-hub-network"
      mesh_peering_enabled    = true
      resource_group_name     = "chungus"
    }
    two = {
      name                    = "my-vnet2"
      location                = "northeurope"
      address_space           = ["192.168.2.0/24"]
      hub_peering_enabled     = true
      hub_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/my-hub-network-rg/providers/Microsoft.Network/virtualNetworks/my-hub-network2"
      mesh_peering_enabled    = true
      resource_group_name     = "bungus"
    }
  }

  resource_group_creation_enabled = true
  resource_groups = {
    nwrg = {
      name     = "NetworkWatcherRG"
      location = "westeurope"
    }
    myrg = {
      name     = "MyRg"
      location = "westeurope"
    }
  }

}
