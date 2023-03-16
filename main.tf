

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
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = "dev"
  }
}


resource "aws_instance" "cloud_instance" {
  ami                     = var.ami_id
  instance_type           = "t2.micro"
  security_groups         = [aws_security_group.ami-ec2-sg.id]
  subnet_id               = aws_subnet.public_subnet[0].id
  key_name                = var.ssh_key_name
  disable_api_termination = false
  iam_instance_profile    = aws_iam_instance_profile.ec2_s3_profile.name
  root_block_device {
    delete_on_termination = true
    volume_size           = 50
    volume_type           = "gp2"
  }


  user_data = <<EOF
    #!/bin/bash

    cd /home/ec2-user/webapp/
    touch .env
    echo "API_PORT=5000" >> .env
    echo "DB_HOST=${aws_db_instance.database.address}" >> .env
    echo "DB_DATABASE=${aws_db_instance.database.db_name}" >> .env
    echo "DB_USER=${aws_db_instance.database.username}" >> .env
    echo "DB_PASSWORD=${aws_db_instance.database.password}" >> .env
    echo "AWS_REGION=${var.region}" >> .env
    echo "AWS_S3_BUCKET_NAME=${aws_s3_bucket.bucket.bucket}" >> .env
    sudo systemctl daemon-relod
    sudo systemctl enable webapp.service
    sudo systemctl start webapp.service
  EOF

  tags = {
    Name = "webapp"
  }

}
resource "aws_db_instance" "database" {
  allocated_storage = 10
  engine            = "mysql"
  #engine_version       = "5.7"
  instance_class = "db.t3.micro"
  #name                 = "csye6225"
  username               = "csye6225"
  password               = "Password"
  db_name                = "csye6225"
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.database_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.database.id
  skip_final_snapshot    = true
  parameter_group_name   = aws_db_parameter_group.mysql57_pg.name
  #final_snapshot_identifier = "mysnaptaken1197"
}
resource "aws_security_group" "database_sg" {
  name        = "database"
  description = "Allow inbound traffic to 3306 from VPC"
  vpc_id      = local.vpc_id

  ingress {
    description     = "open port 3306 to vpc"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ami-ec2-sg.id]
  }

  tags = {
    Name = "database"
  }
}

resource "aws_db_subnet_group" "database" {
  name       = "database"
  subnet_ids = [aws_subnet.private_subnet[0].id, aws_subnet.private_subnet[1].id]

  tags = {
    Name = "database subnet group"
  }
}
resource "aws_iam_policy" "webapp_s3_policy" {
  name        = "webapp_s3_policy"
  path        = "/"
  description = "Allow webapp s3 access"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        "Action" : [
          "s3:DeleteObject",
          "s3:GetObject",
          "s3:PutObject"
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "webapp_s3_access_role" {
  name = "webapp_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "ec2_s3_policy_role" {
  name       = "webapp_s3_attachment"
  roles      = [aws_iam_role.webapp_s3_access_role.name]
  policy_arn = aws_iam_policy.webapp_s3_policy.arn
}

resource "aws_iam_instance_profile" "ec2_s3_profile" {
  name = "webapp_s3_profile"
  role = aws_iam_role.webapp_s3_access_role.name
}

resource "aws_s3_bucket" "bucket" {
  bucket        = "csye6225002928646"
  force_destroy = true

  tags = {
    Name        = "CSYE 6225 webapp"
    Environment = var.profile
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "bucket_lifecycle_config" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    id     = "move_to_IA"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
resource "aws_route53_record" "server_mapping_record" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = "60"
  records = [aws_instance.cloud_instance.public_ip]
}
resource "aws_db_parameter_group" "mysql57_pg" {
  name   = "webapp-database-pg"
  family = "mysql5.7"

}

