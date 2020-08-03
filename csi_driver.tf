# Create Hetzner cloud csi driver
resource "kubernetes_csi_driver" "csi_driver" {
  #count = var.kube_version <= 1.13 ? 0 : 1

  metadata {
    name = "csi.hetzner.cloud"
  }

  spec {
    attach_required        = true
    pod_info_on_mount      = true
    volume_lifecycle_modes = var.kube_version < 1.16 ? null : ["Persistent"]
  }
}