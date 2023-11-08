resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ./lambdas/launch/requirements.txt -t ./lambdas/launch/"
  }

  triggers = {
    dependencies_versions = filemd5("./lambdas/launch/requirements.txt")
    source_versions       = filemd5("./lambdas/launch/function.py")
  }
}

resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset("./lambdas/launch", "function.py"),
      fileset("./lambdas/launch", "requirements.txt")
    ) :
    filename => filemd5("./lambdas/launch/${filename}")
  }
}

data "archive_file" "lambda_source" {
  depends_on = [null_resource.install_dependencies]
  excludes = [
    "__pycache__",
    "venv",
  ]

  source_dir  = "./lambdas/launch"
  output_path = "${random_uuid.lambda_src_hash.result}.zip"
  type        = "zip"
}

resource "aws_iam_role" "minecraft_launch_lambda_role" {
  name = "minecraft_launch_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "minecraft_lambda_policy" {
  name        = "minecraft_lambda_policy"
  description = "Policy for Lambda to manage EC2 and Route53"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:SetDesiredCapacity",
          "ec2:DescribeInstances",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "route53:GetHostedZone",
          "route53:ChangeResourceRecordSets",
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "minecraft_lambda_policy_attachment" {
  role       = aws_iam_role.minecraft_launch_lambda_role.name
  policy_arn = aws_iam_policy.minecraft_lambda_policy.arn
}


resource "aws_lambda_function" "launch_minecraft_lambda" {
  function_name    = "launch-minecraft-server"
  role             = aws_iam_role.minecraft_launch_lambda_role.arn
  filename         = data.archive_file.lambda_source.output_path
  source_code_hash = data.archive_file.lambda_source.output_base64sha256

  handler = "function.handler"
  runtime = "python3.10"

  environment {
    variables = {
      LOG_LEVEL = "INFO"
    }
  }
}

## Make it callable
resource "aws_api_gateway_rest_api" "minecraft_api" {
  name        = "Minecraft Launch API"
  description = "API for starting the Minecraft server"
}

resource "aws_api_gateway_resource" "minecraft_gateway_resource" {
  rest_api_id = aws_api_gateway_rest_api.minecraft_api.id
  parent_id   = aws_api_gateway_rest_api.minecraft_api.root_resource_id
  path_part   = "minecraft"
}

resource "aws_api_gateway_method" "minecraft_gateway_method" {
  rest_api_id   = aws_api_gateway_rest_api.minecraft_api.id
  resource_id   = aws_api_gateway_resource.minecraft_gateway_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "minecraft_gateway_integration" {
  rest_api_id             = aws_api_gateway_rest_api.minecraft_api.id
  resource_id             = aws_api_gateway_resource.minecraft_gateway_resource.id
  http_method             = aws_api_gateway_method.minecraft_gateway_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.launch_minecraft_lambda.invoke_arn
}

resource "aws_lambda_permission" "api_gw_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.launch_minecraft_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # The source_arn is constructed from the API Gateway deployment's execution ARN, which means
  # you need to have the deployment in place before you can grant the permission. This is handled by
  # using the depends_on attribute in this case.
  source_arn = "${aws_api_gateway_rest_api.minecraft_api.execution_arn}/*/*/*"
}

resource "aws_api_gateway_deployment" "minecraft_deployment" {
  depends_on = [
    aws_api_gateway_integration.minecraft_gateway_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.minecraft_api.id
  stage_name  = "v1"
}

# Output the invoke URL of the API Gateway
output "invoke_url" {
  value = aws_api_gateway_deployment.minecraft_deployment.invoke_url
}
