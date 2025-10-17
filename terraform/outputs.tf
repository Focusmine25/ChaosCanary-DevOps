output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "kubeconfig-certificate-authority-data" {
  value = module.eks.cluster_certificate_authority_data
}
