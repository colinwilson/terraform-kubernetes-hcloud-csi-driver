locals {

  IMAGE_HCLOUD_CSI_DRIVER_LEGACY = "hetznercloud/hcloud-csi-driver:1.1.5"
  IMAGE_HCLOUD_CSI_DRIVER        = "hetznercloud/hcloud-csi-driver:1.5.1"

  IMAGE_CSI_NODE_DRIVER_REGISTRAR_LEGACY = "quay.io/k8scsi/csi-node-driver-registrar:v1.1.0"
  IMAGE_CSI_NODE_DRIVER_REGISTRAR        = "quay.io/k8scsi/csi-node-driver-registrar:v1.3.0"

  IMAGE_CSI_PROVISIONER_LEGACY = "quay.io/k8scsi/csi-provisioner:v1.2.1"
  IMAGE_CSI_PROVISIONER        = "quay.io/k8scsi/csi-provisioner:v1.6.0"

  IMAGE_CSI_ATTACHER_LEGACY = "quay.io/k8scsi/csi-attacher:v1.1.1"
  IMAGE_CSI_ATTACHER        = "quay.io/k8scsi/csi-attacher:v2.2.0"

  IMAGE_LIVENESSPROBE = "quay.io/k8scsi/livenessprobe:v1.1.0"

  IMAGE_CSI_RESIZER = "quay.io/k8scsi/csi-resizer:v0.3.0"


}