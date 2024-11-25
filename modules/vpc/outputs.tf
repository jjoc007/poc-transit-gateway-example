output "vpc_id" {
  value = aws_vpc.this.id
  description = "ID de la VPC creada"
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
  description = "Lista de IDs de las subredes públicas"
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
  description = "Lista de IDs de las subredes privadas"
}

output "private_route_table_ids" {
  value = aws_route_table.private[*].id
}

output "public_route_table_ids" {
  value = aws_route_table.public[*].id
}
