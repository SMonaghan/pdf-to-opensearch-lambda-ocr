resource "aws_opensearch_domain" "opensearch_cluster" {
	# count = 0
	domain_name    = var.domain
	engine_version = "OpenSearch_1.3"
	
	advanced_security_options {
		enabled                        = true
		anonymous_auth_enabled         = false
		internal_user_database_enabled = true
		master_user_options {
			master_user_name     = random_string.os_user.result
			master_user_password = random_password.os_password.result
		}
	}

	cluster_config {
		instance_type          = "t3.medium.search"
		zone_awareness_enabled = false
		instance_count				 = 1
	}
	
	ebs_options {
		ebs_enabled = true
		volume_size = 50
	}

	advanced_options = {
		"rest.action.multi.allow_explicit_index" = "true"
	}

	access_policies = <<CONFIG
{
		"Version": "2012-10-17",
		"Statement": [
				{
						"Action": "es:*",
						"Principal": "*",
						"Effect": "Allow",
						"Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.domain}/*"
				}
		]
}
CONFIG
	
	encrypt_at_rest {
		enabled = true
	}
	
	node_to_node_encryption {
		enabled = true
	}
	
	domain_endpoint_options {
		enforce_https       = true
		tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
	}

	tags = {
		Domain = var.domain
	}
	
	log_publishing_options {
		cloudwatch_log_group_arn = aws_cloudwatch_log_group.os_log_group.arn
		log_type                 = "INDEX_SLOW_LOGS"
	}
	
	lifecycle {
		create_before_destroy = true
	}
}

resource "null_resource" "create_backend_role" {
	provisioner "local-exec" {
		command = "/usr/bin/curl -XPUT 'https://${aws_opensearch_domain.opensearch_cluster.endpoint}/_plugins/_security/api/roles/lambda_access' --data @${path.module}/files/opensearch_lambda_role.json --header 'content-type:application/json' --user \"${random_string.os_user.result}:$PASSWORD\""
		when		= create
		
		environment = {
			PASSWORD = random_password.os_password.result
		}
	}
	
	triggers = {
		cluster_id = aws_opensearch_domain.opensearch_cluster.endpoint
	}
}

resource "null_resource" "update_backend_role" {
	provisioner "local-exec" {
		command = "/usr/bin/curl -XPUT 'https://${aws_opensearch_domain.opensearch_cluster.endpoint}/_plugins/_security/api/rolesmapping/lambda_access' --data '{\"backend_roles\" : [\"${aws_iam_role.ocr_lambda_role.arn}\"]}' --header 'content-type:application/json' --user \"${random_string.os_user.result}:$PASSWORD\""
		when		= create
		
		environment = {
			PASSWORD = random_password.os_password.result
		}
	}
	
	triggers = {
		cluster_id = aws_opensearch_domain.opensearch_cluster.endpoint
	}
	
	depends_on = [null_resource.create_backend_role]
}

resource "aws_cloudwatch_log_group" "os_log_group" {
	name_prefix = "OpenSearchLogs-"
}

resource "aws_cloudwatch_log_resource_policy" "os_log_group_policy" {
	policy_name = "OpenSearchLogPolicy"

	policy_document = <<CONFIG
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"Service": "es.amazonaws.com"
			},
			"Action": [
				"logs:PutLogEvents",
				"logs:PutLogEventsBatch",
				"logs:CreateLogStream"
			],
			"Resource": "arn:${data.aws_partition.current.partition}:logs:*"
		}
	]
}
CONFIG
}