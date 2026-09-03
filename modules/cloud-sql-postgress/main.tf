# modules/cloud-sql-postgres/main.tf

# 1. Instância Cloud SQL Postgres
resource "google_sql_database_instance" "postgres" {
  name             = var.instance_name
  database_version = "POSTGRES_15"
  region           = var.region
  project          = var.project_id

  # Garante que as APIs em services.tf estejam ativas antes de tentar criar a instância
  depends_on = [google_project_service.gcp_services]

  settings {
    tier = var.db_tier

    # Controle de Acesso de Rede (Correção do Timeout de Conexão)
    ip_configuration {
      ipv4_enabled = true

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    # Habilita a integração nativa com o IAM do GCP
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
  }
}

# 2. Banco de Dados Lógico
resource "google_sql_database" "db" {
  name     = var.database_name
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
}

# 3. Definição de senha para o superusuário local 'postgres'
# Correção do erro de autenticação (28P01) para permitir que o provider se conecte internamente
resource "google_sql_user" "postgres_admin" {
  name     = "postgres"
  instance = google_sql_database_instance.postgres.name
  project  = var.project_id
  password = var.db_admin_password
}

# 4. Pausa estratégica de 60 segundos
# Evita a Condição de Corrida (Race Condition), aguardando o GCP criar as roles internas de IAM
resource "time_sleep" "wait_for_gcp_roles" {
  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_user.postgres_admin
  ]
  create_duration = "60s"
}

# 5. Contas de Serviço registradas como usuários de Banco com Autenticação IAM
resource "google_sql_user" "github_deployer" {
  # O Terraform vai trocar ${var.project_id} pelo projeto que o desenvolvedor passar
  name     = "github-deployer@${var.project_id}.iam"
  
  instance = google_sql_database_instance.postgres.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}

resource "google_sql_user" "app_dev" {
  name     = "hyper-challenge-app-dev@${var.project_id}.iam"
  
  instance = google_sql_database_instance.postgres.name
  type     = "CLOUD_IAM_SERVICE_ACCOUNT"
}