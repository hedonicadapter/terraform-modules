location_short          = "we"
name             = "aks1"
subscription_name = "tflab"
aks_name          = "aks"
core_name         = "core"
environment = "dev"

aks_config = {
  kubernetes_version = "1.16.9"
  sku_tier           = "Free"
  default_node_pool = {
    orchestrator_version = "1.16.9"
    vm_size              = "Standard_E2s_v3"
    min_count            = 1
    max_count            = 1
    node_labels          = {}
  },
  additional_node_pools = [
    {
      name                 = "normal"
      orchestrator_version = "1.16.9"
      vm_size              = "Standard_E4s_v3"
      min_count            = 2
      max_count            = 4
      node_taints          = []
      node_labels          = {}
    }
  ]
}

namespaces = [
  {
    name                    = "team1"
    delegate_resource_group = true
    labels = {
      "terraform" = "true"
    }
    flux = {
      enabled      = false
      azdo_org     = ""
      azdo_project = ""
      azdo_repo    = ""
    }
  }
]

azure_devops_organization = "xenitab"

acr_name = ""
helm_operator_client_id = ""
helm_operator_secret = ""
aks_authorized_ips = []
aks_pip_prefix_id = ""

aad_groups = ""
aad_pod_identity = ""
