# Create Metrics Controller Service
resource "kubernetes_service" "hcloud_csi_controller_metrics" {
  count = var.kube_version < 1.16 ? 0 : 1

  metadata {
    name = "hcloud-csi-controller-metrics"
    namespace = "kube-system"
    labels = {
      app = "hcloud-csi"
    }
  }

  spec {
    selector = {
      app = "hcloud-csi-controller"
    }

    port {
      name        = "metrics"
      port        = 9189
      target_port = "metrics"
    }
  }
}

# Create Metrics Node Service
resource "kubernetes_service" "hcloud_csi_node_metrics" {
  count = var.kube_version < 1.16 ? 0 : 1

  metadata {
    name = "hcloud-csi-node-metrics"
    namespace = "kube-system"
    labels = {
      app = "hcloud-csi"
    }
  }

  spec {
    selector = {
      app = "hcloud-csi"
    }

    port {
      name        = "metrics"
      port        = 9189
      target_port = "metrics"
    }
  }
}