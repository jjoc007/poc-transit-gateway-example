provider "aws" {
  region = "us-east-1"
}

resource "aws_eip" "nat_eip_sub_net_0" {
  tags = {
    Name = "${local.name_ou}-NAT-EIP-0"
  }
}

resource "aws_eip" "nat_eip_sub_net_1" {
  tags = {
    Name = "${local.name_ou}-NAT-EIP-1"
  }
}

module "networking_vpc" {
  source               = "../../modules/vpc"
  name                 = "${local.name_ou}-VPC"
  cidr_block           = "10.0.0.0/16"
  public_subnets       = [
    { cidr_block = "10.0.1.0/24", availability_zone = "us-east-1a" },
    { cidr_block = "10.0.2.0/24", availability_zone = "us-east-1b" },
  ]
  private_subnets      = [
    { cidr_block = "10.0.3.0/24", availability_zone = "us-east-1a" },
    { cidr_block = "10.0.4.0/24", availability_zone = "us-east-1b" },
  ]
  nat_gateways         = [
    { eip_allocation_id = aws_eip.nat_eip_sub_net_0.id, subnet_index = 0 },
    { eip_allocation_id = aws_eip.nat_eip_sub_net_1.id, subnet_index = 1 }
  ]
  public_subnets_count = 2
  private_subnets_count = 2
  nat_gateways_count    = 2
}

resource "aws_ec2_transit_gateway" "this" {
  description         = "Central Transit Gateway for Hub-and-Spoke Architecture"
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments = "enable"

  tags = {
    Name = "Central-Transit-Gateway"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "networking_attachment" {
  transit_gateway_id = aws_ec2_transit_gateway.this.id
  vpc_id             = module.networking_vpc.vpc_id
  subnet_ids         = [module.networking_vpc.private_subnet_ids[0], module.networking_vpc.private_subnet_ids[1]]

  tags = {
    Name = "Networking-VPC-TGW-Attachment"
  }
}

# share transitgateway with others accounts
resource "aws_ram_resource_share" "tgw_share" {
  name = "TransitGateway-Share"

  allow_external_principals = true

  tags = {
    Name = "TransitGateway-Share"
  }
}

resource "aws_ram_resource_association" "transit_gateway" {
  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_ram_principal_association" "development_account" {
  principal          = "180294180627" # ID Development Account
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_ram_principal_association" "production_account" {
  principal          = "203918846938" # ID Production Account
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_ram_principal_association" "analytics_account" {
  principal          = "713881792350" # ID Analytics Account
  resource_share_arn = aws_ram_resource_share.tgw_share.arn
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "development_attachment_accept" {
  transit_gateway_attachment_id = "tgw-attach-0225c60ba313ca2b0" # ID del attachment
  tags = {
    Name = "Accepted-Development-VPC-TGW-Attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "production_attachment_accept" {
  transit_gateway_attachment_id = "tgw-attach-03950033d114267ad" # ID del attachment
  tags = {
    Name = "Accepted-Production-VPC-TGW-Attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "analytics_attachment_accept" {
  transit_gateway_attachment_id = "tgw-attach-002e22f87bf29bccb" # ID del attachment
  tags = {
    Name = "Accepted-Analytics-VPC-TGW-Attachment"
  }
}

data "aws_ec2_transit_gateway_route_table" "default" {
  filter {
    name   = "default-association-route-table"
    values = ["true"]
  }

  filter {
    name   = "transit-gateway-id"
    values = [aws_ec2_transit_gateway.this.id] # ID del Transit Gateway
  }
}

resource "aws_ec2_transit_gateway_route" "to_vpcs" {
  count = 3 # Número de VPCs conectadas (Development, Production, Analytics)

  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default.id
  destination_cidr_block         = element(["10.1.0.0/16", "10.2.0.0/16", "10.3.0.0/16"], count.index) # CIDRs de las VPCs
  transit_gateway_attachment_id  = element(
    [
      "tgw-attach-0225c60ba313ca2b0", # Attachment ID de Development
      "tgw-attach-03950033d114267ad", # Attachment ID de Production
      "tgw-attach-002e22f87bf29bccb"  # Attachment ID de Analytics
    ],
    count.index
  )

  depends_on = [
    aws_ec2_transit_gateway_vpc_attachment_accepter.development_attachment_accept,
    aws_ec2_transit_gateway_vpc_attachment_accepter.production_attachment_accept,
    aws_ec2_transit_gateway_vpc_attachment_accepter.analytics_attachment_accept
  ]
}

resource "aws_ec2_transit_gateway_route" "to_internet" {
  transit_gateway_route_table_id = data.aws_ec2_transit_gateway_route_table.default.id
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.networking_attachment.id
}

resource "aws_route" "private_routes_to_tgw" {
  for_each              = {
    route1 = { cidr = "10.1.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route2 = { cidr = "10.2.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route3 = { cidr = "10.3.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
  }
  route_table_id         = element(module.networking_vpc.private_route_table_ids, 0)
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = each.value.target_id
}

resource "aws_route" "private_routes_to_tgw_2" {
  for_each              = {
    route1 = { cidr = "10.1.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route2 = { cidr = "10.2.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route3 = { cidr = "10.3.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
  }
  route_table_id         = element(module.networking_vpc.private_route_table_ids, 1)
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = each.value.target_id
}

resource "aws_route" "public_routes_to_tgw" {
  for_each = {
    route1 = { cidr = "10.1.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route2 = { cidr = "10.2.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
    route3 = { cidr = "10.3.0.0/16", target_id = aws_ec2_transit_gateway.this.id }
  }
  route_table_id         = element(module.networking_vpc.public_route_table_ids, 0)
  destination_cidr_block = each.value.cidr
  transit_gateway_id         = each.value.target_id
}
