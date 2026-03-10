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

resource "aws_lightsail_instance" "dns_server" {
  name              = "example"
  availability_zone = "us-east-1b"
  blueprint_id      = "ubuntu_22_04"
  bundle_id         = "micro_3_0"
  user_data         = templatefile("${path.module}/scripts/userdata.sh", {datadog_api_key = var.datadog_api_key})

  lifecycle {
    prevent_destroy = true
  }
  tags = local.common_tags
}