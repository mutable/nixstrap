data "google_project" "default" {}

locals {
  service_account = "${data.google_project.default.number}-compute@developer.gserviceaccount.com"
}

variable "nixstrap_path" {
  type = string
}

variable "nixstrap_hash" {
  type = string
}

resource "random_pet" "bucket_name" {
  prefix = "mut-nixstrap"
}

resource "google_storage_bucket" "default" {
  name     = random_pet.bucket_name.id
  location = "US-CENTRAL1"
  project  = data.google_project.default.project_id
  # Delete objects after a day, as they'll have been uploaded to a GCP disk image.
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 1
    }
  }
}

resource "google_storage_bucket_object" "default" {
  name   = "mut-${var.nixstrap_hash}.tar.gz"
  source = var.nixstrap_path
  bucket = google_storage_bucket.default.name
}

resource "google_compute_image" "default" {
  name = "nixstrap-${var.nixstrap_hash}"
  raw_disk {
    source = "https://storage.googleapis.com/${google_storage_bucket.default.name}/${google_storage_bucket_object.default.output_name}"
  }
  disk_size_gb = 1
  family       = "mut-nixstrap"

  guest_os_features {
    type = "UEFI_COMPATIBLE"
  }

  licenses = ["https://compute.googleapis.com/compute/v1/projects/vm-options/global/licenses/enable-vmx"]

  lifecycle {
    # ensure we atomically upgrade the nixstrap image
    create_before_destroy = true
  }
}

output "image" {
  value = google_compute_image.default.id
}