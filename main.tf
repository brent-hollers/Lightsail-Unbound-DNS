terraform {
  required_providers{
    aws = {
        source = "hashicorp/aws"
        region = "us-east-1"
    }
    tags = common_tags
  }
    
    }

resource "aws_lightsail_instance" "dns_server" {
  name              = "example"
  availability_zone = "us-east-1b"
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = "micro_3_0"
  user_data         = templatefile("${path.module}/scripts/user_data.sh")

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lightsail_vpc_peering" "dns_peering" {
  enabled = true
}