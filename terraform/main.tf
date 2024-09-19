locals {
    cfg_paths = fileset(path.module, "../configs/*")
    configs   = [for path in local.cfg_paths : jsondecode(file(path))]
    timestamp = formatdate("YYMMDDhhmmss", timestamp())
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "../meeting-bot"
  output_path = "${var.function_name}-${local.timestamp}.zip"
}

resource "google_storage_bucket" "bucket" {
  project  = var.project_id
  name     = "bucket-name"
  location = "us-east1"
}

resource "google_storage_bucket_object" "archive" {
  name   = var.function_name
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.source.output_path
}

resource "google_project_iam_member" "functions-invoker" {
  for_each = {for config in local.configs: config.job_name => config}

  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.schedulers_sa[each.key].email}"
}

resource "google_cloudfunctions_function" "function" {
  project     = var.project_id
  name        = var.function_name
  description = "Bot to send reminder in chat for daily meetings."
  runtime     = "python38"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  trigger_http          = true
  timeout               = 60
  entry_point           = "main"
  labels = {
    name    = "meeting-bot",
    context = "daily"
  }

  service_account_email = google_service_account.function_sa.email
}

resource "google_cloud_scheduler_job" "jobs" {
    for_each = {for config in local.configs: config.job_name => config}

    name        = each.value.job_name
    description = each.value.description
    project     = var.project_id
    schedule    = each.value.frequency
    time_zone   = each.value.time_zone

    http_target {
        http_method = "POST"
        uri         = google_cloudfunctions_function.function.https_trigger_url
        body        = base64encode("{\"meeting_url\": \"${each.value.meeting_url}\", \"webhook\": \"${each.value.webhook}\"}")
        headers     = {
            "Content-Type": "application/octet-stream",
            "User-Agent": "Google-Cloud-Scheduler"
        }
        oidc_token {
            service_account_email = google_service_account.schedulers_sa[each.key].email
        }
        # retry_config {}?
  }
}

resource "google_service_account" "schedulers_sa" {
  for_each = {for config in local.configs: config.job_name => config}

  project      = var.project_id
  account_id   = "${each.value.job_name}-sa"
  display_name = "Service Account for scheduler ${each.value.job_name}"
}

resource "google_service_account" "function_sa" {
  project      = var.project_id
  account_id   = "${var.function_name}-sa"
  display_name = "Service Account for function ${var.function_name}"
}
