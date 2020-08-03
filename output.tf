output "hcloud_csi_driver_name" {
  description = "The Name of the Hetzner Cloud CSI driver"
  value       = kubernetes_csi_driver.csi_driver.metadata[0].name
}