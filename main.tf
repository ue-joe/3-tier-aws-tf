terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "remote" {
    organization = "UEDEMO"

    workspaces {
      name = "AWSPROD"
    }
  }

}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create a VPC
resource "aws_vpc" "my-vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "UE Prod VPC"
  }
}

# Create Management Subnet
resource "aws_subnet" "management-subnet" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1c"
  map_public_ip_on_launch = true

  tags = {
    Name = "Management"
  }
}

# Create Web Public Subnet
resource "aws_subnet" "web-subnet-1" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-1a"
  }
}

resource "aws_subnet" "web-subnet-2" {
  vpc_id                  = aws_vpc.my-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "Web-2b"
  }
}

resource "aws_subnet" "database-subnet" {
  vpc_id            = aws_vpc.my-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Database"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "Demo IGW"
  }
}

# Create Web layber route table
resource "aws_route_table" "web-rt" {
  vpc_id = aws_vpc.my-vpc.id


  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "WebRT"
  }
}

# Create Web Subnet association with Web route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web-subnet-1.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.web-subnet-2.id
  route_table_id = aws_route_table.web-rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.management-subnet.id
  route_table_id = aws_route_table.web-rt.id
}

data "local_file" "userdata_web" {
    filename = "${path.module}/install_apache.sh"
}
data "local_file" "userdata_db" {
    filename = "${path.module}/install_db.sh"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}


#Create EC2 Instance
resource "aws_instance" "webserver1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-1.id
  user_data              = data.local_file.userdata_web.content

  tags = {
    Name = "Web Server"
    AnsibleGroup = "web_servers"
  }
}

resource "aws_instance" "webserver2" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1b"
  vpc_security_group_ids = [aws_security_group.webserver-sg.id]
  subnet_id              = aws_subnet.web-subnet-2.id
  user_data              = data.local_file.userdata_web.content

  tags = {
    Name = "Web Server"
    AnsibleGroup = "web_servers"
  }
}

#Create EC2 Instance
resource "aws_instance" "db1" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1a"
  vpc_security_group_ids = [aws_security_group.database-sg.id]
  subnet_id              = aws_subnet.database-subnet.id
  user_data              = data.local_file.userdata_db.content

  tags = {
    Name = "Database Server"
    AnsibleGroup = "database_servers"
  }
}
resource "aws_key_pair" "jumpbox_ssh"{
  key_name   = "jumpbox-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC5LZD9Ab+l+DfTTZigOhdx5mqHYkttDLkRSw8ZPzhXvj12gfLetWqZDZVLu+wFSGxeAqZtn7GhVIbTjCuQUfBPhaq9nn40GAxJJYJEehuoonTaFOdGBpvfpkRYf61gOQHW7D7AK7BuCVC8BPeCtCOvQNJnIoXS24GaxMKZCoYldrSBPfhA80J0aZLXQ4yoWIrqXIMekCWvblrXRDaN5pkeIFKvxDnrew1oUlzOQAJCAVL+4EUri7ICrPVw3t5bJbolVbUUlcsLndJ5snIXoV4QomTmRR0ZOI8ZIVkSbOdzIzVXwrwTof8rqWZU3YkNPAOL/eUWVK6/RfcKR0iF7J6jav4LEKWkJreDqwg1gKWw9ruXHytTF3WZmXn0YO4HXXjaL+qbF6gNf5aXDsPlgl/ewtApr3Ucxn1vl/QIk+jdP8rY+51lKNHI/ywfyMbYmvNlyc9/vvfGuHCaD0vssb8MjrYFoYDuf0j8r5jGksBO88AsdcRYOP76Cor7TSHF7B8= vagrant@ubuntu-focal"
}
#Create Jumpbox Instance
resource "aws_instance" "jumpbox" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  availability_zone      = "us-east-1c"
  vpc_security_group_ids = [aws_security_group.jumpbox-sg.id]
  subnet_id              = aws_subnet.management-subnet.id
  key_name               = "jumpbox-key"
  tags = {
    Name = "Jumpbox"
    AnsibleGroup = "management_servers"
  }
}

# Create Web Security Group
resource "aws_security_group" "web-sg" {
  name        = "Web-SG"
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Web-SG"
  }
}

# Create Application Security Group
resource "aws_security_group" "webserver-sg" {
  name        = "Webserver-SG"
  description = "Allow inbound traffic from ALB"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description     = "Allow traffic from web layer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.web-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Webserver-SG"
  }
}

# Create Database Security Group
resource "aws_security_group" "database-sg" {
  name        = "Database-SG"
  description = "Allow inbound traffic from application layer"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description     = "Allow traffic from application layer"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.webserver-sg.id]
  }

  egress {
    from_port   = 32768
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Database-SG"
  }
}

# Create Jumpbox Security Group
resource "aws_security_group" "jumpbox-sg" {
  name        = "Jumpbox-SG"
  description = "Allow SSH inbound from Workstation"
  vpc_id      = aws_vpc.my-vpc.id

  ingress {
    description = "SSH from Workstation"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.2.3.4/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Jumpbox-SG"
  }
}

resource "aws_lb" "external-elb" {
  name               = "External-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web-sg.id]
  subnets            = [aws_subnet.web-subnet-1.id, aws_subnet.web-subnet-2.id]
}

resource "aws_lb_target_group" "external-elb" {
  name     = "ALB-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver1.id
  port             = 80

  depends_on = [
    aws_instance.webserver1,
  ]
}

resource "aws_lb_target_group_attachment" "external-elb2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.webserver2.id
  port             = 80

  depends_on = [
    aws_instance.webserver2,
  ]
}

resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

output "lb_dns_name" {
  description = "The DNS name of the load balancer"
  value       = aws_lb.external-elb.dns_name
}

output "vpc_id" {
  description = "The VPC ID of this environment"
  value = aws_vpc.my-vpc.id
}
