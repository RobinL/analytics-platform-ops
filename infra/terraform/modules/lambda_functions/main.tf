# Zip the lambda function before the actual deploy
data "archive_file" "lambda_function_package" {
    type        = "zip"
    source_dir  = "${path.module}/encrypt_s3_object"
    output_path = "${path.module}/encrypt_s3_object.zip"
}

# Lambda function which encrypts S3 objects
resource "aws_lambda_function" "encrypt_s3_object" {
    description = "Encrypt S3 objects using AWS' server side encryption"
    filename = "${path.module}/encrypt_s3_object.zip"
    source_code_hash = "${data.archive_file.lambda_function_package.output_base64sha256}"
    function_name = "${var.env}_encrypt_s3_object"
    role = "${aws_iam_role.encrypt_s3_object_role.arn}"
    handler = "index.handler"
    runtime = "nodejs4.3"
    timeout = 300 # 5 minutes
    depends_on = ["data.archive_file.lambda_function_package"]
}

# Bucket notification to trigger lambda function
resource "aws_s3_bucket_notification" "object_created_in_scratch" {
    bucket = "${var.bucket_id}"
    lambda_function {
        lambda_function_arn = "${aws_lambda_function.encrypt_s3_object.arn}"
        events = ["s3:ObjectCreated:*"]
    }
}

# Role running the lambda function
resource "aws_iam_role" "encrypt_s3_object_role" {
    name = "encrypt_s3_object_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Policies for the 'encrypt_s3_object_role' role
resource "aws_iam_role_policy" "encrypt_s3_object_role_policy" {
    name = "encrypt_s3_object_role_policy"
    role = "${aws_iam_role.encrypt_s3_object_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CanEncryptS3Objects",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": [
        "${var.bucket_arn}/*"
      ]
    },
    {
      "Sid": "CanLog",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:*"
      ]
    }
  ]
}
EOF
}

# Permission to invoke the lambda function
resource "aws_lambda_permission" "allow_encrypt_s3_object_invocation" {
    statement_id = "AllowExecutionFromS3Bucket"
    action = "lambda:InvokeFunction"
    function_name = "${aws_lambda_function.encrypt_s3_object.arn}"
    principal = "s3.amazonaws.com"
    source_arn = "${var.bucket_arn}"
}
