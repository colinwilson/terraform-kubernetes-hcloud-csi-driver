# Create secret containing Hetzner Cloud API token
resource "kubernetes_secret" "hcloud_token" {
  metadata {
    name      = "hcloud-csi"
    namespace = "kube-system"
  }

  data = {
    token = var.hcloud_token
  }
}