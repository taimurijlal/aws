provider "aws" {
  region = "eu-west-2"

# Dont store your access keys in the code ! 
  access_key = ""
  secret_key = ""
}

# Create a VPC 
resource "aws_vpc" "terraform-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    "name" = "My Terraform VPC"
  }
}

#Create subnet 
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.terraform-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "My terraform subnet"
  }
}

# Create Internet Gateway so that we can access the internet 
  resource "aws_internet_gateway" "Internet_GW" {
  vpc_id     = aws_vpc.terraform-vpc.id

  tags = {
    Name = "My terraform gateway"
  }
  }


# Create Route Table for internet traffic routing 
resource "aws_route_table" "Public_RT" {
  vpc_id     = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_GW.id
  }

  tags = {
    Name = "My terraform route table"
  }
}

# Associate Route Table with the subnet 
 resource "aws_route_table_association" "RT_association" {
  subnet_id      = aws_subnet.public.id 
  route_table_id = aws_route_table.Public_RT.id 
}


# Create security group to allow port 22,80,443 
resource "aws_security_group" "allow_traffic" {
  name        = "allow_web_traffic"
  description = "Allow traffic from internet"
  vpc_id     = aws_vpc.terraform-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

    ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }


  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow Web Traffic"
  }
}

#Create Network Interface and associate with the subnet 
resource "aws_network_interface" "NIC" {
  subnet_id       = aws_subnet.public.id 
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_traffic.id]
}


# Create an elastic IP . This needs an internet gateway to be present so setting the depends on flag 
resource "aws_eip" "MyElasticIP" {
  vpc                       = true
  network_interface         = aws_network_interface.NIC.id 
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.Internet_GW]
}

# Create an Ec2 instance
resource "aws_instance" "terraform-webserver" {
 # Make sure this ami exsists in the region otherwise it will throw an error 
 ami            = "ami-0d26eb3972b7f8c96"
 instance_type  = "t2.micro"
 availability_zone = "eu-west-2a"
 key_name = "MyTFKeyPair"
 network_interface {
   device_index = 0
   network_interface_id = aws_network_interface.NIC.id
 }

 user_data = <<-EOF
          #!/bin/bash
          sudo apt update -y
          sudo apt install apache2 -y
          sudo systemctl start apache2
          sudo bash -c 'echo your very first web server > /var/www/html/index.html'
        EOF

 tags = {
   Name = "Terraform webserver"
 }
}
