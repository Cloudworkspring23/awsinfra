

resource "aws_vpc" "cloud_vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name = "cloud-vpc"
  }
}
locals {
  vpc_id = aws_vpc.cloud_vpc.id
}
resource "aws_subnet" "public_subnet" {

  count                   = var.subnet_public_count
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(aws_vpc.cloud_vpc.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]}"
  }
}


resource "aws_subnet" "private_subnet" {
  count                   = var.subnet_private_count
  vpc_id                  = local.vpc_id
  cidr_block              = cidrsubnet(aws_vpc.cloud_vpc.cidr_block, 8, count.index + var.subnet_private_count)
  availability_zone       = data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]
  map_public_ip_on_launch = false

  tags = {
    Name = "private-subnet-${data.aws_availability_zones.available.names[(count.index % length(data.aws_availability_zones.available.names))]}"
  }
}



resource "aws_internet_gateway" "cloud_gateway" {
  vpc_id = local.vpc_id

  tags = {
    Name = "cloud_gateway"
  }
}
resource "aws_route_table" "public_route_table" {
  vpc_id = local.vpc_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cloud_gateway.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_subnet_a_association" {
  count          = var.subnet_public_count
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table" "private" {
  vpc_id = local.vpc_id

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet" {
  count          = var.subnet_private_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}
resource "aws_security_group" "ami-ec2-sg" {
  name_prefix = "ami-ec2-sg"
  description = "ec2 security group"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "dev"
  }
}

# resource "aws_key_pair" "tf" {
#   key_name   = "tf"
#   public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDCPHptzJLbmg465AU7vR37xefRDjfZj5hOgd0XUJ5OcyhQJripIz9N1UK+miRPJOhfg7P6881tsPQeI3BtNOL4eX/pWahGQ+A0VZKLJMUF7xsiEPQjXWy0KkoBakqAFbyn3m6L9iZkoxB6m8n+d6BOm9eZ9Gd1eFx1KLjLSagh9KpkxtzuePzdC4HVgAfRYwXG+JzxOrSptjdRyHZth4bs1qL/uqkVcWJQ5xz643EVjr2GTr0WneKUO6HONfibexHgy20XwvW/5BnXl8m3MlVs+wnWE7caz6fvD4UZPjslVTmmgM8l8QPaBkaWncMO5O9qHipp9BPI49zu8qliPRsZAhYOZvgqbnfQVkMe3rlU+29SKMR7hBAEm4SsFigLenreleHz0f3NkR4+0Z0H6mVgmtYr2fpGM23bXsTxJH0DVSkW8mWAIDQkbQv55jXElVNj6EhpOZ557SKprPzCJXzxfQ2JQwkxQEIGMlhFVYLEjjtRMbou4osfQDH9mGnip4M= maverick1997@Arjuns-MacBook-Air.local"
# }

resource "aws_instance" "cloud_instance" {
  ami             = var.ami_id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.ami-ec2-sg.id]
  subnet_id       = aws_subnet.public_subnet[0].id
  key_name        = var.ssh_key_name

  tags = {
    Name = "cloudami"
  }
}