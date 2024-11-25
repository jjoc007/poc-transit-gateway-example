variable "name" {
  description = "Nombre de la VPC"
  type        = string
}

variable "cidr_block" {
  description = "Bloque CIDR de la VPC"
  type        = string
}

variable "tags" {
  description = "Etiquetas adicionales para los recursos"
  type        = map(string)
  default     = {}
}

variable "public_subnets" {
  description = "Lista de subredes públicas"
  type = list(object({
    cidr_block       = string
    availability_zone = string
  }))
  default     = []
}

variable "private_subnets" {
  description = "Lista de subredes privadas"
  type = list(object({
    cidr_block       = string
    availability_zone = string
  }))
}

variable "nat_gateways" {
  description = "Configuración de NAT Gateways"
  type = list(object({
    eip_allocation_id = string
    subnet_index      = number
  }))
  default     = []
}

variable "public_subnets_count" {
  description = "Número de subredes públicas"
  type        = number
  default     = 0
}

variable "private_subnets_count" {
  description = "Número de subredes privadas"
  type        = number
  default     = 0
}

variable "nat_gateways_count" {
  description = "Número de NAT Gateways"
  type        = number
  default     = 0
}
