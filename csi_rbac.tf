# Create Service Account
resource "kubernetes_service_account" "hcloud_csi" {
  metadata {
    name      = "hcloud-csi"
    namespace = "kube-system"
  }
}

# Create Cluster Role
resource "kubernetes_cluster_role" "hcloud_csi" {
  metadata {
    name = "hcloud-csi"
  }
  # attacher
  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = var.kube_version < 1.16 ? ["get", "list", "watch", "update"] : ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes"]
    verbs      = ["get", "list", "watch"]
  }

  dynamic "rule" {
    for_each = var.kube_version < 1.16 ? [] : [1]

    content {
      api_groups = ["csi.storage.k8s.io"]
      resources  = ["csinodeinfos"]
      verbs      = ["get", "list", "watch"]
    }
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["csinodes"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["volumeattachments"]
    verbs      = var.kube_version < 1.16 ? ["get", "list", "watch", "update"] : ["get", "list", "watch", "update", "patch"]
  }

  # provisioner
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = [""]
    resources  = ["persistentvolumes"]
    verbs      = var.kube_version < 1.16 ? ["get", "list", "watch", "create", "delete"] : ["get", "list", "watch", "create", "delete", "patch"]
  }

  rule {
    api_groups = [""]
    resources  = var.kube_version < 1.16 ? ["persistentvolumeclaims"] : ["persistentvolumeclaims", "persistentvolumeclaims/status"]
    verbs      = var.kube_version < 1.16 ? ["get", "list", "watch", "update"] : ["get", "list", "watch", "update", "patch"]
  }

  rule {
    api_groups = ["storage.k8s.io"]
    resources  = ["storageclasses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["list", "watch", "create", "update", "patch"]
  }

  rule {
    api_groups = ["snapshot.storage.k8s.io"]
    resources  = ["volumesnapshots"]
    verbs      = ["get", "list"]
  }

  rule {
    api_groups = ["snapshot.storage.k8s.io"]
    resources  = ["volumesnapshotcontents"]
    verbs      = ["get", "list"]
  }

  # node
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["get", "list", "watch", "create", "update", "patch"]
  }
}


# Create cluster role binding
resource "kubernetes_cluster_role_binding" "hcloud_csi" {
  metadata {
    name = "hcloud-csi"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "hcloud-csi"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "hcloud-csi"
    namespace = "kube-system"
  }
}