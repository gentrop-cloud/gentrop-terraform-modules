variable "project_id" {
  type        = string
  description = "ID do projeto GCP onde os recursos serão criados"
}

variable "instance_name" {
  type        = string
  description = "Nome da instância do Cloud SQL"
}

variable "database_name" {
  type        = string
  description = "Nome do banco de dados lógico"
}

variable "region" {
  type        = string
  default     = "us-central1"
  description = "Região do GCP para o deploy"
}

variable "db_tier" {
  type        = string
  default     = "db-f1-micro"
  description = "Tamanho e capacidade da máquina da instância"
}

variable "db_admin_password" {
  type        = string
  sensitive   = true
  description = "Senha do usuário master 'postgres' para execução dos privilégios internos"
}

variable "iam_database_users" {
  type        = list(string)
  default     = []
  description = "Service accounts do GCP que devem virar usuarios do banco autenticados via IAM (CLOUD_IAM_SERVICE_ACCOUNT). O Cloud SQL exige o formato SEM o sufixo \".gserviceaccount.com\", ex: [\"github-deployer@projeto.iam\"] (nao \"...@projeto.iam.gserviceaccount.com\"). A service account precisa ja existir no projeto antes do apply."
}

variable "authorized_networks" {
  type = list(object({
    name  = string
    value = string
  }))
  default     = []
  description = "Lista de redes/IPs com permissão de acesso ao banco"
}