

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
  availability_zone       = data.aws_availability_zones.available.names[(count.index% length(data.aws_availability_zones.available.names))]
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
  route {
    cidr_block = "10.1.0.0/16"
    gateway_id = aws_internet_gateway.cloud_gateway.id
  }

  tags = {
    Name = "private-route-table"
  }
}

resource "aws_route_table_association" "private_subnet" {
  count          = var.subnet_private_count
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private.id
}

