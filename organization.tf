data "aws_organizations_organization" "main" {}

# Crear Unidades Organizativas (OU)
resource "aws_organizations_organizational_unit" "networking_ou" {
  name      = "Networking"
  parent_id = data.aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "applications_ou" {
  name      = "Applications"
  parent_id = data.aws_organizations_organization.main.roots[0].id
}

resource "aws_organizations_organizational_unit" "analytics_ou" {
  name      = "Analytics"
  parent_id = data.aws_organizations_organization.main.roots[0].id
}

# Crear cuentas de la organización
resource "aws_organizations_account" "networking" {
  parent_id = aws_organizations_organizational_unit.networking_ou.id
  name      = "Networking & Security"
  email     = "${local.my_email_user_name}+networking@${local.my_email_domain}"
  role_name = "OrganizationAccountAccessRole"
}

resource "aws_organizations_account" "development" {
  parent_id = aws_organizations_organizational_unit.applications_ou.id
  name      = "Development"
  email     = "${local.my_email_user_name}+development@${local.my_email_domain}"
  role_name = "OrganizationAccountAccessRole"
}

resource "aws_organizations_account" "production" {
  parent_id = aws_organizations_organizational_unit.applications_ou.id
  name      = "Production"
  email     = "${local.my_email_user_name}+production@${local.my_email_domain}"
  role_name = "OrganizationAccountAccessRole"
}

resource "aws_organizations_account" "analytics" {
  parent_id = aws_organizations_organizational_unit.analytics_ou.id
  name      = "Analytics"
  email     = "${local.my_email_user_name}+analytics@${local.my_email_domain}"
  role_name = "OrganizationAccountAccessRole"
}
