output "opensearch_domain" {
	value = aws_opensearch_domain.opensearch_cluster.endpoint
}

output "kibana_domain" {
	value = aws_opensearch_domain.opensearch_cluster.kibana_endpoint
}