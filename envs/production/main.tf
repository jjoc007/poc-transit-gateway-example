provider "aws" {
  region = "us-east-1"
}

module "production_vpc" {
  source               = "../../modules/vpc"
  name                 = "Production-VPC"
  cidr_block           = "10.2.0.0/16"

  private_subnets      = [
    { cidr_block = "10.2.1.0/24", availability_zone = "us-east-1a" },
    { cidr_block = "10.2.2.0/24", availability_zone = "us-east-1b" },
  ]

  private_subnets_count = 2

  tags = {
    Environment = "Production"
    Owner       = "Production Team"
  }
}

resource "aws_ram_resource_share_accepter" "transit_gateway_share" {
  share_arn = "arn:aws:ram:us-east-1:180294178325:resource-share/6c78c527-3d8b-4221-a2dc-88b47bcfe3e0" # ARN del recurso compartido desde Networking
  depends_on = [module.production_vpc] # Asegura que la VPC esté creada antes de aceptar
}

data "aws_ec2_transit_gateway" "shared" {
  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "transit-gateway-id"
    values = ["tgw-027785fe77cab11f9"]
  }

  depends_on = [aws_ram_resource_share_accepter.transit_gateway_share]
}

resource "aws_ec2_transit_gateway_vpc_attachment" "production_attachment" {
  transit_gateway_id = data.aws_ec2_transit_gateway.shared.id
  vpc_id             = module.production_vpc.vpc_id
  subnet_ids         = module.production_vpc.private_subnet_ids

  tags = {
    Name = "Production-VPC-TGW-Attachment"
  }
}

resource "aws_route" "to_transit_gateway_internet" {
  count = length(module.production_vpc.private_route_table_ids)
  route_table_id         = element(module.production_vpc.private_route_table_ids, count.index)
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = data.aws_ec2_transit_gateway.shared.id
}

resource "aws_iam_role" "ssm_role" {
  name               = "poc-transit-gateway-SSM-Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ssm_policy_attachment" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_instance" "private_instance" {
  ami                    = "ami-012967cc5a8c9f891"
  instance_type          = "t3.micro"
  subnet_id              = element(module.production_vpc.private_subnet_ids, 0)
  associate_public_ip_address = false
  iam_instance_profile   = aws_iam_instance_profile.ssm_instance_profile.name

  tags = {
    Name = "Production-Private-Instance"
  }
}

resource "aws_iam_instance_profile" "ssm_instance_profile" {
  name = "Analytics-SSM-Instance-Profile"
  role = aws_iam_role.ssm_role.name
}

resource "aws_security_group" "private_instance_sg" {
  name        = "Production-Private-Instance-SG"
  description = "Allow outbound traffic for private instance"
  vpc_id      = module.production_vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Production-Private-Instance-SG"
  }
}