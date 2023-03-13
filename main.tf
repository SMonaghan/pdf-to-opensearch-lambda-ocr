terraform {
	required_providers {
		aws = {
			source  = "hashicorp/aws"
			version = "~> 4.51.0"
		}
	}
}

locals {
	archive_dir            = "${path.module}/files/archives"
	execute_sfn_lambda_dir = "${path.module}/files/lambda-execute-sfn"
	ocr_lambda_dir				 = "${path.module}/files/lambda-ocr"
	requirements_file			 = "${local.ocr_lambda_dir}/requirements.txt"
	python_deps_dir				 = "${local.archive_dir}/lambda_deps"
}

data "aws_iam_policy_document" "lambda_assume_role" {
	statement {
		effect = "Allow"

		principals {
			type        = "Service"
			identifiers = ["lambda.amazonaws.com"]
		}

		actions = ["sts:AssumeRole"]
	}
}

data "aws_iam_policy" "lambda_basic_execution_role" {
	name = "AWSLambdaBasicExecutionRole"
}

data "aws_vpc" "vpc" {
	id = var.vpc_id
}

data "aws_partition" "current" {}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}