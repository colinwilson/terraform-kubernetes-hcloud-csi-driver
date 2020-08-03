# Create CSI Controller StatefulSet
resource "kubernetes_stateful_set" "hcloud_csi_controller" {
  metadata {
    name = "hcloud-csi-controller"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        app = "hcloud-csi-controller"
      }
    }

    service_name = "hcloud-csi-controller"
    replicas               = 1

    template {
      metadata {
        labels = {
          app = "hcloud-csi-controller"
        }
      }

      spec {
        automount_service_account_token = true # override Terraform's default false - https://github.com/kubernetes/kubernetes/issues/27973#issuecomment-462185284
        service_account_name = "hcloud-csi"

        container {
          name              = "csi-attacher"
          image             = var.kube_version < 1.16 ? "quay.io/k8scsi/csi-attacher:v1.1.1" : "quay.io/k8scsi/csi-attacher:v2.2.0"

          args = [
            "--csi-address=/var/lib/csi/sockets/pluginproxy/csi.sock",
            "--v=5",
          ]

          volume_mount {
            name       = "socket-dir"
            mount_path = "/var/lib/csi/sockets/pluginproxy/"
          }

          security_context {
            privileged = true
            capabilities {
              add = ["SYS_ADMIN"]
            }
            allow_privilege_escalation = true
          }
        }

        dynamic "container" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            name              = "csi-resizer"
            image             = "quay.io/k8scsi/csi-resizer:v0.3.0"

            args = [
              "--csi-address=/var/lib/csi/sockets/pluginproxy/csi.sock",
              "--v=5",
            ]

            volume_mount {
              name       = "socket-dir"
              mount_path = "/var/lib/csi/sockets/pluginproxy/"
            }

            security_context {
              privileged = true
              capabilities {
                add = ["SYS_ADMIN"]
              }
              allow_privilege_escalation = true
            }
          }
        }

        container {
          name              = "csi-provisioner"
          image             = var.kube_version < 1.16 ? "quay.io/k8scsi/csi-provisioner:v1.2.1" : "quay.io/k8scsi/csi-provisioner:v1.6.0"

          args = [
            "--provisioner=csi.hetzner.cloud",
            "--csi-address=/var/lib/csi/sockets/pluginproxy/csi.sock",
            "--feature-gates=Topology=true",
            "--v=5",
          ]

          volume_mount {
            name       = "socket-dir"
            mount_path = "/var/lib/csi/sockets/pluginproxy/"
          }

          security_context {
            privileged = true
            capabilities {
              add = ["SYS_ADMIN"]
            }
            allow_privilege_escalation = true
          }
        }

        container {
          name              = "hcloud-csi-driver"
          image             = var.kube_version < 1.16 ? "hetznercloud/hcloud-csi-driver:1.1.5" : "hetznercloud/hcloud-csi-driver:1.4.0"
          image_pull_policy =  "Always"

          env {
            name = "CSI_ENDPOINT"
            value = "unix:///var/lib/csi/sockets/pluginproxy/csi.sock"
          }

          dynamic "env" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              name = "METRICS_ENDPOINT"
              value = "0.0.0.0:9189"
            }
          }

          env {
            name = "HCLOUD_TOKEN"
            value_from {
              secret_key_ref {
                name = "hcloud-csi"
                key = "token"
              }
            }
          }

          volume_mount {
            name       = "socket-dir"
            mount_path = "/var/lib/csi/sockets/pluginproxy/"
          }

          dynamic "port" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              container_port = 9189
              name = "metrics"
            }
          }

          dynamic "port" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              container_port = 9808
              name = "healthz"
              protocol = "TCP"
            }
          }

          dynamic "liveness_probe" {
            for_each = var.kube_version < 1.16 ? [] : [1]

            content {
              http_get {
                path   = "/healthz"
                port   = "healthz"
              }

              initial_delay_seconds = 10
              timeout_seconds       = 3
              period_seconds        = 2
            }
          }

          security_context {
            privileged = true
            capabilities {
              add = ["SYS_ADMIN"]
            }
            allow_privilege_escalation = true
          }
        }

        dynamic "container" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            name              = "liveness-probe"
            image             = "quay.io/k8scsi/livenessprobe:v1.1.0"
            image_pull_policy =  "Always"

            args = [
              "--csi-address=/var/lib/csi/sockets/pluginproxy/csi.sock",
            ]

            volume_mount {
              name       = "socket-dir"
              mount_path = "/var/lib/csi/sockets/pluginproxy/"
            }
          }
        }

        volume {
          name = "socket-dir"

          empty_dir {}
        }
      }
    }
  }
}