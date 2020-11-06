# Create DaemonSet
resource "kubernetes_daemonset" "hcloud_csi_node" {
  metadata {
    name      = "hcloud-csi-node"
    namespace = "kube-system"
    labels = {
      app = "hcloud-csi"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "hcloud-csi"
      }
    }

    template {
      metadata {
        labels = {
          app = "hcloud-csi"
        }
      }

      spec {
        dynamic "toleration" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            effect   = "NoExecute"
            operator = "Exists"
          }
        }

        dynamic "toleration" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            effect   = "NoSchedule"
            operator = "Exists"
          }
        }

        dynamic "toleration" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            key      = "CriticalAddonsOnly"
            operator = "Exists"
          }
        }

        automount_service_account_token = true # override Terraform's default false - https://github.com/kubernetes/kubernetes/issues/27973#issuecomment-462185284
        service_account_name            = "hcloud-csi"
        host_network                    = var.kube_version < 1.16 ? true : null

        container {
          name  = "csi-node-driver-registrar"
          image = var.kube_version < 1.16 ? local.IMAGE_CSI_NODE_DRIVER_REGISTRAR_LEGACY : local.IMAGE_CSI_NODE_DRIVER_REGISTRAR

          args = [
            "--v=5",
            "--csi-address=/csi/csi.sock",
            "--kubelet-registration-path=/var/lib/kubelet/plugins/csi.hetzner.cloud/csi.sock",
          ]

          env {
            name = "KUBE_NODE_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "spec.nodeName"
              }
            }
          }

          volume_mount {
            name       = "plugin-dir"
            mount_path = "/csi"
          }

          volume_mount {
            name       = "registration-dir"
            mount_path = "/registration"
          }

          security_context {
            privileged = true
          }

        }

        container {
          name              = "hcloud-csi-driver"
          image             = var.kube_version < 1.16 ? "hetznercloud/hcloud-csi-driver:1.1.5" : "hetznercloud/hcloud-csi-driver:1.5.1"
          image_pull_policy = "Always"

          env {
            name  = "CSI_ENDPOINT"
            value = "unix:///csi/csi.sock"
          }

          dynamic "env" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              name  = "METRICS_ENDPOINT"
              value = "0.0.0.0:9189"
            }
          }

          env {
            name = "HCLOUD_TOKEN"
            value_from {
              secret_key_ref {
                name = "hcloud-csi"
                key  = "token"
              }
            }
          }
          env {
            name = "KUBE_NODE_NAME"
            value_from {
              field_ref {
                api_version = "v1"
                field_path  = "spec.nodeName"
              }
            }
          }
          volume_mount {
            name              = "kubelet-dir"
            mount_path        = "/var/lib/kubelet"
            mount_propagation = "Bidirectional"
          }

          volume_mount {
            name       = "plugin-dir"
            mount_path = "/csi"
          }

          volume_mount {
            name       = "device-dir"
            mount_path = "/dev"
          }

          security_context {
            privileged = true
          }

          dynamic "port" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              container_port = 9189
              name           = "metrics"
            }
          }

          dynamic "port" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              container_port = 9808
              name           = "healthz"
              protocol       = "TCP"
            }
          }

          dynamic "liveness_probe" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              failure_threshold = 5
              http_get {
                path = "/healthz"
                port = "healthz"
              }

              initial_delay_seconds = 10
              timeout_seconds       = 3
              period_seconds        = 2
            }
          }

        }

        dynamic "container" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            name              = "liveness-probe"
            image             = local.IMAGE_LIVENESSPROBE
            image_pull_policy = "Always"

            args = [
              "--csi-address=/csi/csi.sock",
            ]

            volume_mount {
              name       = "plugin-dir"
              mount_path = "/csi"
            }
          }
        }

        volume {
          name = "kubelet-dir"
          host_path {
            path = "/var/lib/kubelet"
            type = "Directory"
          }
        }

        volume {
          name = "plugin-dir"
          host_path {
            path = "/var/lib/kubelet/plugins/csi.hetzner.cloud/"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "registration-dir"
          host_path {
            path = "/var/lib/kubelet/plugins_registry/"
            type = "Directory"
          }
        }

        volume {
          name = "device-dir"
          host_path {
            path = "/dev"
            type = "Directory"
          }
        }

      }
    }
  }
}