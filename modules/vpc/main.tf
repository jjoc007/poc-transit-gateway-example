resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    { Name = var.name }
  )
}

resource "aws_subnet" "public" {
  count = var.public_subnets_count > 0 ? var.public_subnets_count : 0

  vpc_id                = aws_vpc.this.id
  cidr_block            = var.public_subnets[count.index].cidr_block
  map_public_ip_on_launch = true
  availability_zone     = var.public_subnets[count.index].availability_zone

  tags = merge(
    var.tags,
    { Name = "${var.name}-Public-Subnet-${count.index}" }
  )
}

resource "aws_subnet" "private" {
  count                 = var.private_subnets_count
  vpc_id                = aws_vpc.this.id
  cidr_block            = var.private_subnets[count.index].cidr_block
  availability_zone     = var.private_subnets[count.index].availability_zone

  tags = merge(
    var.tags,
    { Name = "${var.name}-Private-Subnet-${count.index}" }
  )
}

resource "aws_internet_gateway" "this" {
  count = var.public_subnets_count > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    { Name = "${var.name}-IGW" }
  )
}

resource "aws_nat_gateway" "this" {
  count = var.nat_gateways_count

  allocation_id    = var.nat_gateways[count.index].eip_allocation_id
  subnet_id        = aws_subnet.public[var.nat_gateways[count.index].subnet_index].id
  connectivity_type = "public"

  tags = merge(
    var.tags,
    { Name = "${var.name}-NAT-Gateway-${count.index + 1}" }
  )
}

resource "aws_route_table" "private" {
  count  = var.private_subnets_count
  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    { Name = "${var.name}-Private-Route-Table-${count.index + 1}" }
  )
}

resource "aws_route" "private" {
  count = var.nat_gateways_count > 0 ? var.private_subnets_count : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[count.index % var.nat_gateways_count].id
}

resource "aws_route_table_association" "private" {
  count          = var.private_subnets_count
  route_table_id = aws_route_table.private[count.index].id
  subnet_id      = aws_subnet.private[count.index].id
}

resource "aws_route_table" "public" {
  count = var.public_subnets_count > 0 ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(
    var.tags,
    { Name = "${var.name}-Public-Route-Table" }
  )
}

resource "aws_route" "public" {
  count = var.public_subnets_count > 0 ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route_table_association" "public" {
  count = var.public_subnets_count

  route_table_id = aws_route_table.public[0].id
  subnet_id      = aws_subnet.public[count.index].id
}
