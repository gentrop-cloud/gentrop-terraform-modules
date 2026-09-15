output "queue_id" {
  description = "Full resource id of the queue (projects/PROJECT/locations/LOCATION/queues/NAME)."
  value       = google_cloud_tasks_queue.this.id
}

output "queue_name" {
  description = "Cloud Tasks queue name."
  value       = google_cloud_tasks_queue.this.name
}
