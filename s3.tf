resource "aws_s3_bucket" "bucket" {
	bucket_prefix = "topr-responses-"
	
	force_destroy = true
}

resource "aws_s3_bucket_notification" "bucket_notification" {
	bucket = aws_s3_bucket.bucket.id

	queue {
		queue_arn     = aws_sqs_queue.bucket_notification_queue.arn
		events        = ["s3:ObjectCreated:*"]
		filter_suffix = ".pdf"
		filter_prefix = "documents/"
	}
}