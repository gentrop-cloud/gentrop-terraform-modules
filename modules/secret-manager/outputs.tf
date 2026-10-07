output "secret_ids" {
  description = "Map of secret id => secret id (convenience for referencing in other modules)."
  value       = { for id, s in google_secret_manager_secret.this : id => s.secret_id }
}

output "secret_names" {
  description = "Map of secret id => full resource name."
  value       = { for id, s in google_secret_manager_secret.this : id => s.name }
}
