# Create secret containing Hetzner Cloud API token
resource "kubernetes_secret" "hcloud_token" {
  metadata {
    name = "hcloud-csi"
    namespace = "kube-system"
  }

  data = {
    token = var.hcloud_token
  }
}

# Create Hetzner cloud csi driver
resource "kubernetes_csi_driver" "csi_driver" {
  count = var.kube_version <= 1.13 ? 0 : 1

  metadata {
    name = "csi.hetzner.cloud"
  }

  spec {
    attach_required        = true
    pod_info_on_mount      = true
    volume_lifecycle_modes = var.kube_version < 1.16 ? null : ["Persistent"]
  }
}

# Create Storage Class
resource "kubernetes_storage_class" "hcloud_volumes" {
  metadata {
    name = "hcloud-volumes"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = true
    }
  }
  storage_provisioner = "csi.hetzner.cloud"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = var.kube_version < 1.16 ? null : true
}

# Create Service Account
resource "kubernetes_service_account" "hcloud_csi" {
  metadata {
    name = "hcloud-csi"
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
            effect = "NoExecute"
            operator = "Exists"
          }
        }

        dynamic "toleration" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            effect = "NoSchedule"
            operator = "Exists"
          }
        }

        dynamic "toleration" {
          for_each = var.kube_version < 1.16 ? [] : [1]

          content {
            key = "CriticalAddonsOnly"
            operator = "Exists"
          }
        }

        automount_service_account_token = true # override Terraform's default false - https://github.com/kubernetes/kubernetes/issues/27973#issuecomment-462185284
        service_account_name = "hcloud-csi"
        host_network = var.kube_version < 1.16 ? true : null

        container {
          name  = "csi-node-driver-registrar"
          image = var.kube_version < 1.16 ? "quay.io/k8scsi/csi-node-driver-registrar:v1.1.0" : "quay.io/k8scsi/csi-node-driver-registrar:v1.3.0"

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
                field_path = "spec.nodeName"
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
          name  = "hcloud-csi-driver"
          image = var.kube_version < 1.16 ? "hetznercloud/hcloud-csi-driver:1.1.5" : "hetznercloud/hcloud-csi-driver:1.4.0"
          image_pull_policy = "Always"

          env {
            name = "CSI_ENDPOINT"
            value = "unix:///csi/csi.sock"
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
            name       = "kubelet-dir"
            mount_path = "/var/lib/kubelet"
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
              failure_threshold     = 5
              http_get {
                path   = "/healthz"
                port   = "healthz"
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
            image             = "quay.io/k8scsi/livenessprobe:v1.1.0"
            image_pull_policy =  "Always"

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