/**
 * # Flux V2
 *
 * Installs and configures [flux2](https://github.com/fluxcd/flux2) with GitHub.
 *
 * The module is meant to offer a full bootstrap and confiugration of a Kubernetes cluster
 * with Fluxv2. A "root" repository is created for the bootstrap configuration along with a
 * repository per namepsace passed in the variables. The root repository will receive `cluster-admin`
 * permissions in the cluster while each of the namespace repositories will be limited to their
 * repsective namespace. The CRDs, component deployments and bootstrap configuration are both
 * added to the Kubernetes cluster and commited to the root repository. While the namespace
 * configuration is only comitted to the root repository and expected to be reconciled through
 * the bootstrap configuration.
 *
 * ![flux-arch](../../../assets/fluxcd-v2.jpg)
 */

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    flux = {
      source  = "fluxcd/flux"
      version = "0.25.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    github = {
      source  = "integrations/github"
      version = "5.34.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
    git = {
      source  = "xenitab/git"
      version = "0.0.3"
    }
  }
}

locals {
  git_auth_proxy_url = "http://git-auth-proxy.flux-system.svc.cluster.local"
}

resource "kubernetes_namespace" "this" {
  lifecycle {
    ignore_changes = [
      metadata[0].labels,
      metadata[0].annotations,
    ]
  }

  metadata {
    name = "flux-system"
    labels = {
      name = "flux-system"
    }
  }
}

# Git Auth Proxy
resource "helm_release" "git_auth_proxy" {
  chart       = "oci://ghcr.io/xenitab/helm-charts/git-auth-proxy"
  name        = "git-auth-proxy"
  namespace   = kubernetes_namespace.this.metadata[0].name
  version     = "v0.8.2"
  max_history = 3
  values = [templatefile("${path.module}/templates/git-auth-proxy-values.yaml.tpl", {
    github_org      = var.github_org
    app_id          = tonumber(var.github_app_id)
    installation_id = tonumber(var.github_installation_id)
    private_key     = base64encode(var.github_private_key)
    cluster_repo    = var.cluster_repo,
    tenants = [for ns in var.namespaces : {
      repo : ns.flux.repo
      namespace : ns.name
      }
      if ns.flux.enabled
    ],
  })]
}

# Cluster
data "github_repository" "cluster" {
  full_name = "${var.github_org}/${var.cluster_repo}"
}

data "flux_install" "this" {
  target_path = "clusters/${var.cluster_id}"
}

data "flux_sync" "this" {
  url         = "${local.git_auth_proxy_url}/${var.github_org}/${var.cluster_repo}"
  branch      = var.branch
  target_path = "clusters/${var.cluster_id}"
}

data "kubectl_file_documents" "install" {
  content = data.flux_install.this.content
}

data "kubectl_file_documents" "sync" {
  content = data.flux_sync.this.content
}

locals {
  install = [for v in data.kubectl_file_documents.install.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
  sync = [for v in data.kubectl_file_documents.sync.documents : {
    data : yamldecode(v)
    content : v
    }
  ]
}

resource "kubectl_manifest" "install" {
  depends_on = [kubernetes_namespace.this]
  for_each   = { for v in local.install : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }

  apply_only = true
  yaml_body  = each.value
}

resource "kubectl_manifest" "sync" {
  depends_on = [kubernetes_namespace.this]
  for_each   = { for v in local.sync : lower(join("/", compact([v.data.apiVersion, v.data.kind, lookup(v.data.metadata, "namespace", ""), v.data.metadata.name]))) => v.content }

  apply_only = true
  yaml_body  = each.value
}

resource "github_repository_file" "install" {
  repository          = data.github_repository.cluster.name
  file                = data.flux_install.this.path
  content             = data.flux_install.this.content
  branch              = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      commit_message,
    ]
  }
}

resource "github_repository_file" "sync" {
  repository          = data.github_repository.cluster.name
  file                = data.flux_sync.this.path
  content             = data.flux_sync.this.content
  branch              = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      commit_message,
    ]
  }
}

resource "github_repository_file" "kustomize" {
  repository          = data.github_repository.cluster.name
  file                = data.flux_sync.this.kustomize_path
  content             = file("${path.module}/templates/kustomization-override.yaml")
  branch              = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      commit_message,
    ]
  }
}

resource "github_repository_file" "cluster_tenants" {
  repository = data.github_repository.cluster.name
  file       = "clusters/${var.cluster_id}/tenants.yaml"
  content = templatefile("${path.module}/templates/cluster-tenants.yaml", {
    cluster_id = var.cluster_id
  })
  branch              = var.branch
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      commit_message,
    ]
  }
}

# Tenants
resource "github_repository_file" "tenant" {
  for_each = {
    for ns in var.namespaces :
    ns.name => ns
    if ns.flux.enabled
  }

  repository = data.github_repository.cluster.name
  branch     = var.branch
  file       = "tenants/${var.cluster_id}/${each.key}.yaml"
  content = templatefile("${path.module}/templates/tenant.yaml", {
    repo        = "${local.git_auth_proxy_url}/${var.github_org}/${each.value.flux.repo}.git"
    branch      = var.branch,
    name        = each.key,
    environment = var.environment,
    create_crds = false,
    github_org  = var.github_org
    cluster_id  = var.cluster_id
  })
  overwrite_on_create = true

  lifecycle {
    ignore_changes = [
      commit_message,
    ]
  }
}
resource "git_repository_file" "kustomization" {
  path       = "clusters/${var.cluster_id}/flux-alerts.yaml"
  depends_on = [kubernetes_namespace.this]
  content = templatefile("${path.module}/templates/kustomization.yaml.tpl", {
    cluster_id = var.cluster_id,
  })
}

resource "git_repository_file" "flux_alerts" {
  path = "platform/${var.cluster_id}/flux-alerts/flux_alerts.yaml"
  content = templatefile("${path.module}/templates/flux-alerts.yaml.tpl", {
    slack_flux_alert_config = {
      xenit_webhook  = var.slack_flux_alert_config.xenit_webhook
      tenant_webhook = var.slack_flux_alert_config.tenant_webhook
    }
    github_org = var.github_org
    cluster_id = var.cluster_id
  })
}
