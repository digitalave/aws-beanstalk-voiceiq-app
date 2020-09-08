# Setup our aws provider
provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.vpc_region
}

# Define a vpc
resource "aws_vpc" "vpc_voiceiq" {
  cidr_block       = "172.25.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "VPC_voiceiq"
  }
}

# Internet gateway for the public subnet
resource "aws_internet_gateway" "IGW_voliceiq" {
  vpc_id = aws_vpc.vpc_voiceiq.id
  
  tags = {
    Name = "IGW_voliceiq"
  }
}

# Public subnet
resource "aws_subnet" "VPC_Public_Sub_voiceiq" {
  vpc_id            = aws_vpc.vpc_voiceiq.id
  cidr_block        = var.vpc_public_subnet_1_cidr
  map_public_ip_on_launch = true
//  availability_zone = "ap-southeast-1a"
  availability_zone = lookup(var.availability_zone, var.vpc_region)

  tags = {
    Name = "VPC_Public_Sub_voiceiq"
  }
}

# Private subnet
resource "aws_subnet" "VPC_Private_Sub_voiceiq" {
  vpc_id            = aws_vpc.vpc_voiceiq.id
  cidr_block        = var.vpc_private_subnet_1_cidr
//  availability_zone = "ap-southeast-1a"
  availability_zone = lookup(var.availability_zone, var.vpc_region)

  tags = {
    Name = "VPC_Private_Sub_voiceiq"
  }
}

# Routing table for public subnet
resource "aws_route_table" "VPC_Public_Sub_voiceiq_rt" {
  vpc_id = aws_vpc.vpc_voiceiq.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW_voliceiq.id
  }

  tags = {
    Name = "VPC_Public_Sub_voiceiq_rt"
  }

}

# Associate the routing table to public subnet
resource "aws_route_table_association" "VPC_Public_Sub_voiceiq_rt_assn" {
  subnet_id      = aws_subnet.VPC_Public_Sub_voiceiq.id
  route_table_id = aws_route_table.VPC_Public_Sub_voiceiq_rt.id
}

# Routing table for private subnet
resource "aws_route_table" "VPC_Private_Sub_voiceiq_rt" {
  vpc_id = aws_vpc.vpc_voiceiq.id
//  route {
//    cidr_block = "172.25.20.0/24"
  //  gateway_id = aws_internet_gateway.IGW_voliceiq.id
//  }

  tags = {
    Name = "VPC_Private_Sub_voiceiq_rt"
  }

}

# Associate the routing table to private subnet
resource "aws_route_table_association" "VPC_Private_Sub_voiceiq_rt_assn" {
  subnet_id      = aws_subnet.VPC_Private_Sub_voiceiq.id
  route_table_id = aws_route_table.VPC_Private_Sub_voiceiq_rt.id
}

# Web Server Instance Security group
resource "aws_security_group" "VPC_Public_Sub_voiceiq_sg" {
  name        = "VPC_Public_Sub_voiceiq_sg"
  description = "Public access security group"
  vpc_id      = aws_vpc.vpc_voiceiq.id

  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    # allow all traffic to private SN
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DB Server Instance Security group
resource "aws_security_group" "VPC_Private_Sub_voiceiq_sg" {
  name        = "Private_Sub_voiceiq_sg"
  description = "Security group to access private ports"

  # allow mysql port within VPC
  ingress {
    from_port = 3306
    to_port   = 3306
    protocol  = "tcp"
    cidr_blocks = [
    var.vpc_private_subnet_1_cidr]
  }

  egress {
    from_port = "0"
    to_port   = "0"
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

########## Elastic Load Balancer for the Public Subnet ############
# Create a new load balancer
resource "aws_elb" "voiceiq-elb" {
  name               = "voiceiq-elb"
  availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/index.html"
    interval            = 30
  }

//  instances                   = [aws_instance.foo.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "voiceiq-elb"
  }
}



############ Elastic Beanstalk Application Environment ############
resource "aws_elastic_beanstalk_application" "voiceiq-app" {
  name        = "voiceiq-app"
  description = "voiceiq-app"
}

# Production environment with basic configuration
resource "aws_elastic_beanstalk_environment" "production" {
  name                = "voiceiq-app-prod-env"
  application         = "voiceiq-app"
  solution_stack_name = "64bit Amazon Linux 2018.03 v2.15.3 running Docker 19.03.6-ce"
  tier                = "WebServer"

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = "2"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "3"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSizeType"
    value = "Fixed"
  }

  setting {
    namespace = "aws:elasticbeanstalk:command"
    name = "BatchSize"
    value = "1"
  }

  setting {
    namespace = "aws:elb:loadbalancer"
    name      = "CrossZone"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "aws-elasticbeanstalk-service-role"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = "t2.micro"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = aws_vpc.vpc_voiceiq.id
  }

  # Public subnets - used for EC2 instances facing traffic from internet
  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    # value     = "subnet-05de104c,subnet-c5fd3ea2,subnet-3af4fb62"
    value     = aws_subnet.VPC_Public_Sub_voiceiq.id
  }

  # Subnets ELB will connect to
  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    # value     = "subnet-05de104c,subnet-c5fd3ea2,subnet-3af4fb62"
    value     = aws_subnet.VPC_Public_Sub_voiceiq.id
  }

  # Assign public IP address to EC2 instances
  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateType"
    value     = "Health"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = "true"
  }
}

############# Amazon RDS For MySQL ###########

resource "aws_db_security_group" "voiceiq_rds_sg" {
  name = "rds_sg"

  ingress {
    cidr = "172.25.20.0/24"
  }
}

resource "aws_db_instance" "voiceiq_rds" {
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t2.micro"
  name                 = "voiceiqdb"
  username             = "voiceiq"
  password             = "voiceiqpw"
  parameter_group_name = "default.mysql5.7"
  availability_zone    = "ap-southeast-1a"

}


############## Output Variables #############


output "vpc_region" {
  value = "${var.vpc_region}"
}

output "vpc_id" {
  value = "${aws_vpc.vpc_voiceiq.id}"
}

output "VPC_Public_Sub_voiceiq_id" {
  value = "${aws_subnet.VPC_Public_Sub_voiceiq.id}"
}

output "VPC_Private_Sub_voiceiq_id" {
  value = "${aws_subnet.VPC_Private_Sub_voiceiq.id}"
}

output "VPC_Public_Sub_voiceiq_sg_id" {
  value = "${aws_security_group.VPC_Public_Sub_voiceiq_sg.id}"
}

output "VPC_Private_Sub_voiceiq_sg_id" {
  value = "${aws_security_group.VPC_Private_Sub_voiceiq_sg.id}"
}

