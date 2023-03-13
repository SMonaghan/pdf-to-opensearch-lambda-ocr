data "aws_iam_policy_document" "ocr_lambda_permissions" {
	statement {
		sid     = "SQSPermissions"
		actions = [
			"sqs:ReceiveMessage",
			"sqs:DeleteMessage",
			"sqs:GetQueueAttributes"
		]
		
		resources = [aws_sqs_queue.bucket_notification_queue.arn]
	}
	
	statement {
		sid     = "S3Permissions"
		actions = [
			"s3:getObject",
			"s3:pubObject"
		]
		
		resources = ["${aws_s3_bucket.bucket.arn}/*"]
	}
	
	statement {
		sid     = "Comprehend"
		actions = [
			"comprehend:DetectEntities",
			"comprehend:DetectKeyPhrases"
		]
		
		resources = ["*"]
	}
}

resource "aws_iam_policy" "ocr_lambda_policy" {
	name_prefix = "execute_state_machine_policy-"
	description = "Allow the execution of the state machine"
	policy      = data.aws_iam_policy_document.ocr_lambda_permissions.json
	
	lifecycle {
		create_before_destroy = true
	}
}

resource "aws_iam_role" "ocr_lambda_role" {
	name_prefix         = "OCRLambdaRole-"
	assume_role_policy  = data.aws_iam_policy_document.lambda_assume_role.json
	managed_policy_arns = [
		aws_iam_policy.ocr_lambda_policy.arn,
		data.aws_iam_policy.lambda_basic_execution_role.arn
	]
}

resource "null_resource" "pip_install" {
	provisioner "local-exec" {
		command = "pip3 install -r ${local.requirements_file} -t ${local.python_deps_dir} --upgrade"
		when		= create
	}
	
	triggers = {
		requirements_txt = file(local.requirements_file)
		lambda_deps_os	 = fileexists("${local.python_deps_dir}/six.py")
		lambda_deps_pdf	 = fileexists("${local.python_deps_dir}/typing_extensions.py")
	}
}

resource "local_file" "index_file" {
	content  = file("${local.ocr_lambda_dir}/index.py")
	filename = "${local.python_deps_dir}/index.py"
}

data "archive_file" "ocr_lambda_archive" {
	type        = "zip"
	output_path = "${local.archive_dir}/ocr-lambda.zip"
	source_dir  = local.python_deps_dir
	depends_on	= [
		null_resource.pip_install,
		local_file.index_file
	]
}

resource "aws_lambda_function" "ocr_lambda" {
	# If the file is not in the current working directory you will need to include a
	# path.module in the filename.
	filename      = data.archive_file.ocr_lambda_archive.output_path
	function_name = "OCRLambdaFunction"
	role          = aws_iam_role.ocr_lambda_role.arn
	handler       = "index.lambda_handler"
	timeout       = 120
	memory_size   = 512

	source_code_hash = data.archive_file.ocr_lambda_archive.output_base64sha256

	runtime = "python3.9"

	environment {
		variables = {
			SECRET_ID         = aws_secretsmanager_secret.os_admin_password.id
			OPENSEARCH_DOMAIN = aws_opensearch_domain.opensearch_cluster.endpoint
		}
	}
}

resource "aws_lambda_event_source_mapping" "ocr_lambda_sqs_event_mapping" {
	event_source_arn = aws_sqs_queue.bucket_notification_queue.arn
	function_name    = aws_lambda_function.ocr_lambda.arn
	enabled          = true
	batch_size       = 1
	
	# maximum_batching_window_in_seconds = 10
}