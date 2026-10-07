output "instance_connection_name" {
  value       = google_sql_database_instance.postgres.connection_name
  description = "String de conexão para ser usada por Cloud Run, funções ou GKE"
}

output "instance_ip_address" {
  value       = google_sql_database_instance.postgres.public_ip_address
  description = "Endereço IP público atribuído à instância"
}

output "database_name" {
  value       = google_sql_database.db.name
  description = "Nome do banco de dados lógico provisionado"
}