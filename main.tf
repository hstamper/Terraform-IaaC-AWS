provider "aws" {
    region = "us-east-1"
}

# Create a VPC 
resource "aws_vpc" "dev_vpc" {
  cidr_block = "10.0.0.0/16"
  
  tags = {
    Name = "dev-vpc"
  }
}

# Create an Internet Gateway 
resource "aws_internet_gateway" "dev_igw" {
    vpc_id = aws_vpc.dev_vpc.id

    tags = {
        Name = "dev-igw"
  }
}

# Create a Route Table 
resource "aws_route_table" "dev_route_table" {
    vpc_id = aws_vpc.dev_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev_igw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id             = aws_internet_gateway.dev_igw.id
  }

  tags = {
    Name = "dev-route-table"
  }
}

# Create a Subnet 
resource "aws_subnet" "dev_subnet_1" {
    vpc_id     = aws_vpc.dev_vpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"
  
    tags = {
        Name = "dev-public-subnet-1"
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "dev_route_table_association" {
  subnet_id      = aws_subnet.dev_subnet_1.id
  route_table_id = aws_route_table.dev_route_table.id
}

# Create a Security Group 
resource "aws_security_group" "dev_sg" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.dev_vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
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

   ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
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
    Name = "dev-sg"
  }
}

# Create a Network Interface 
resource "aws_network_interface" "dev_nic" {
  subnet_id       = aws_subnet.dev_subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.dev_sg.id]

}

# Assign an Elastic IP to the NIC
resource "aws_eip" "dev_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.dev_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.dev_igw]
}

# Create EC2 and install/enable httpd 
resource "aws_instance" "dev_server_1" {
    ami = "ami-090fa75af13c156b4"
    instance_type = "t2.micro"
    availability_zone = "us-east-1a"
    key_name = "hstamper"
    user_data = <<-EOF
                #!/bin/bash
                sudo yum update -y 
                sudo yum install httpd -y 
                sudo systemctl enable httpd
                sudo systemctl start httpd
                sudo bash -c "echo Very First Terraform Practice Project > /var/www/html/index.html"
                EOF 


    network_interface {
        device_index = 0 
        network_interface_id = aws_network_interface.dev_nic.id 
    }

    
    tags = {
        Name = "dev-server-1"
    }
}

# Create an EIP for the EC2 
resource "aws_eip" "dev_instance_eip" {
  instance = aws_instance.dev_server_1.id
  vpc      = true
}