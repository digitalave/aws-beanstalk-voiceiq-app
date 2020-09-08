### AWS Creds ###
variable "aws_access_key_id" {
  description = "AWS access key"
}

variable "aws_secret_access_key" {
  description = "AWS secret access key"
}

### VPC ####
variable "availability_zone" {
  description = "availability zone used for the demo, based on region"
  default = {
    ap-southeast-1 = "ap-southeast-1a"
    ap-southeast-1 = "ap-southeast-1b"
  }
}

variable "vpc_voiceiq" {
  description = "VPC for building voiceiq assigment"
}

variable "vpc_region" {
  description = "AWS region"
}
### VPC Subnets ###
variable "vpc_public_subnet_1_cidr" {
  description = "Public 0.0 CIDR for externally accessible subnet"
}

variable "vpc_private_subnet_1_cidr" {
  description = "Private CIDR for internally accessible subnet"
}
