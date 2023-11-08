variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24"]
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["us-east-1a"]
}

variable "domain" {
  description = "The domain you want to use for your Minecraft server"
  type        = string
}
