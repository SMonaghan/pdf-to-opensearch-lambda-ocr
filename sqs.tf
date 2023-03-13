data "aws_iam_policy_document" "bucket_notification_queue_policy" {
	statement {
		effect = "Allow"

		principals {
			type        = "*"
			identifiers = ["*"]
		}

		actions   = ["sqs:SendMessage"]
		resources = ["arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:s3-event-notification-queue"]

		condition {
			test     = "ArnEquals"
			variable = "aws:SourceArn"
			values   = [aws_s3_bucket.bucket.arn]
		}
		
		condition {
			test     = "StringEquals"
			variable = "aws:SourceAccount"
			values   = [data.aws_caller_identity.current.account_id]
		}
	}
}

resource "aws_sqs_queue" "bucket_notification_queue" {
	name   = "s3-event-notification-queue"
	policy = data.aws_iam_policy_document.bucket_notification_queue_policy.json
	
	visibility_timeout_seconds = 120 * 6
}