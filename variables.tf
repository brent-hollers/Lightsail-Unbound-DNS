locals{
    common_tags = {
        Project = "Lightsail-Unbound-DNS"
        Owner = "Brent Hollers"
        ManagedBy = "Terraform"
    }
}

variable "datadog_api_key" {
    description = "Datadog API key for agent installation"
    type = string
    sensitive = true
  
}