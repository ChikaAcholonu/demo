terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }

  }
}
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIAVRYMHMKGRTWKCHO6"
  secret_key = "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"
}

#Create vpc


resource "aws_vpc" "Terraform_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {Name = "Terraform_vpc" 
  }
}

#Create subnet

resource "aws_subnet" "Subnet-1" {
  vpc_id     = aws_vpc.Terraform_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Prod-subnet"
  }
}

#Create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.Terraform_vpc.id

  tags = {
    Name = "Prod_IGW"
  }
}

#Create Route Table

resource "aws_route_table" "PROD_route_table" {
  vpc_id = aws_vpc.Terraform_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }


  tags = {
    Name = "Terraform_IGW"
  }
}

#Subnet association with route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.Subnet-1.id
  route_table_id = aws_route_table.PROD_route_table.id
}

#Create Security groups
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.Terraform_vpc.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress{

    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }

  ingress{

    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  



    
  

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" #Means any protocol
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}

#Create network interface
resource "aws_network_interface" "test" {
  subnet_id       = aws_subnet.Subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  
}

#Create an Elastic IP
resource "aws_eip" "lb" {
  network_interface = aws_network_interface.test.id
  vpc      = true
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
  
}
#Create an Ubuntu Server
resource "aws_instance" "Terraform_server" {
  ami= "ami-09e67e426f25ce0d7"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "Terraform_Key_Pair"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.test.id
    
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo your very first web server > /var/www/html/index.html'
              EOF
  tags = {"Name" = "Web_server"
  
  }


 
  
}