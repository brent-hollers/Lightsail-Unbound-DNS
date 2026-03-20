terraform {
  required_providers{
    aws = {
        source = "hashicorp/aws" 
    }
  }
    
    }

provider "aws"{
  region = "us-east-1"

}
data "aws_ami" "Ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-arm64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = [ "099720109477" ]
}

resource "aws_instance" "dns_server" {
  availability_zone = "us-east-1b"
  instance_type     = "t4g.micro"
  ami               = data.aws_ami.Ubuntu.id
  security_groups   = [aws_security_group.dns_sg.name]
  iam_instance_profile = aws_iam_instance_profile.dns_instance_profile.name
  user_data         = templatefile("${path.module}/scripts/userdata.sh", {datadog_api_key = var.datadog_api_key})
  key_name = "ssh_dns_instance"
  lifecycle {
    prevent_destroy = false
  }
  tags = local.common_tags
}

resource "aws_security_group" "dns_sg" {
  name        = "dns-server-sg"
  description = "Allow DNS traffic"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["10.21.0.0/16"]
  }

    ingress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["10.21.0.0/16"]
  }

    ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.21.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "dns_role" {
  name = "dns-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "dns_policy" {
  name        = "dns-server-policy"
  description = "Policy for DNS server to allow SSM access"
  policy      = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CloudWatch",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:DescribeAlarmHistory",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:GetMetricData",
                "cloudwatch:ListMetrics",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:PutAnomalyDetector",
                "cloudwatch:DeleteAnomalyDetector",
                "cloudwatch:DescribeAnomalyDetectors"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "CloudWatchLogs",
            "Effect": "Allow",
            "Action": [
                "logs:FilterLogEvents",
                "logs:GetLogEvents",
                "logs:DescribeLogStreams",
                "logs:DescribeLogGroups",
		"logs:CreateLogGroup",
		"logs:CreateLogStream",
		"logs:PutLogEvents"
            ],
            "Resource": [
                "*"
            ]
        },

        {
            "Sid": "EC2",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:DescribeVolumes",
                "ec2:DescribeVolumeStatus",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeNatGateways"
            ],
            "Resource": [
                "*"
            ]
        },

        {
            "Sid": "SSM",
            "Effect": "Allow",
            "Action": [
                "ssm:DescribeInstanceInformation",
                "ssm:GetCommandInvocation",
                "ssm:ListCommands",
                "ssm:SendCommand"
            ],
            "Resource": [
                "*"
            ]
        }
        ]
      })
  } 

resource "aws_iam_role_policy_attachment" "dns_policy_attachment" {
  role       = aws_iam_role.dns_role.name
  policy_arn = aws_iam_policy.dns_policy.arn
}

resource "aws_iam_role_policy_attachment" "dns_role_attachment" {
  role       = aws_iam_role.dns_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "dns_instance_profile" {
  name = "dns-server-instance-profile"
  role = aws_iam_role.dns_role.name
}

resource "aws_eip" "dns_eip" {
  instance = aws_instance.dns_server.id
  domain = "vpc"
}

data "aws_vpc" "default" {
  default = true
}