provider "postgresql" {
  host            = google_sql_database_instance.postgres.public_ip_address
  port            = 5432
  database        = google_sql_database.db.name
  username        = "postgres"
  password        = var.db_admin_password
  sslmode         = "require"
  superuser       = false
}

locals {
  roles_iam = [
    google_sql_user.github_deployer.name,
    google_sql_user.app_dev.name
  ]
}

# Conexão e permissão de Schema (Usage/Create)
resource "postgresql_grant" "schema_privileges" {
  for_each    = toset(local.roles_iam)
  database    = google_sql_database.db.name
  role        = each.key
  schema      = "public"
  object_type = "schema"
  privileges  = ["USAGE", "CREATE"]
}

# Tabelas Atuais (Select/Insert)
resource "postgresql_grant" "table_privileges" {
  for_each    = toset(local.roles_iam)
  database    = google_sql_database.db.name
  role        = each.key
  schema      = "public"
  object_type = "table"
  privileges  = ["SELECT", "INSERT"]
}

# Sequences Atuais (Usage/Select)
resource "postgresql_grant" "sequence_privileges" {
  for_each    = toset(local.roles_iam)
  database    = google_sql_database.db.name
  role        = each.key
  schema      = "public"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}

# Tabelas Futuras (Default Privileges)
resource "postgresql_default_privileges" "future_tables" {
  for_each    = toset(local.roles_iam)
  database    = google_sql_database.db.name
  role        = each.key
  schema      = "public"
  owner       = "postgres"
  object_type = "table"
  privileges  = ["SELECT", "INSERT"]
}

# Sequences Futuras (Default Privileges)
resource "postgresql_default_privileges" "future_sequences" {
  for_each    = toset(local.roles_iam)
  database    = google_sql_database.db.name
  role        = each.key
  schema      = "public"
  owner       = "postgres"
  object_type = "sequence"
  privileges  = ["USAGE", "SELECT"]
}