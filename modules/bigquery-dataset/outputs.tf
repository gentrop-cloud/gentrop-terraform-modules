output "dataset_id" {
  description = "BigQuery dataset id."
  value       = google_bigquery_dataset.this.dataset_id
}

output "table_ids" {
  description = "Map of table key => full table id (project.dataset.table)."
  value       = { for k, t in google_bigquery_table.this : k => "${var.project_id}.${var.dataset_id}.${t.table_id}" }
}
