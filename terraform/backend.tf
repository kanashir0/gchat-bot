terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      # version = "~> x.x"
    }
  }

  backend "gcs" {
    credentials = "creds.json"
    bucket  = "state-bucket-name"
    prefix  = "kana"
  }
}
