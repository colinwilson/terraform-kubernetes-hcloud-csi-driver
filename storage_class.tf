# Create Storage Class
resource "kubernetes_storage_class" "hcloud_volumes" {
  metadata {
    name = "hcloud-volumes"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = true
    }
  }
  storage_provisioner    = "csi.hetzner.cloud"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = var.kube_version < 1.16 ? null : true
}