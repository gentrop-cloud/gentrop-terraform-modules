output "name" {
  description = "Full resource name of the database (projects/PROJECT/databases/DATABASE_ID)."
  value       = google_firestore_database.this.name
}
