# Required configuration variables
variable "hcloud_token" {
    description = "Hetzner Cloud API Token"
}

# Optional configuration
variable "kube_version" {
    default = 1.18
    type = number
    description = "Kuberenetes Cluster Version e.g. 1.18"
}