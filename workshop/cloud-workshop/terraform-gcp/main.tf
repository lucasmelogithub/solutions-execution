terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Pick the right Ubuntu 24.04 image for the architecture of var.machine_type.
# c4a* = Axion (ARM); everything else here is x86. The amd64 image is TDX-capable,
# which is what the Confidential VM (c3-standard-*) path needs.
locals {
  is_arm       = startswith(var.machine_type, "c4a")
  image_family = local.is_arm ? "ubuntu-2404-lts-arm64" : "ubuntu-2404-lts-amd64"
}

data "google_compute_image" "ubuntu" {
  family  = local.image_family
  project = "ubuntu-os-cloud"
}

# One-shot SSH keypair for this attendee/module. Gitignored.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/tfkey"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = "${path.module}/tfkey.pub"
  content         = tls_private_key.ssh.public_key_openssh
  file_permission = "0644"
}

# Wrap the SSH details in an ssh_config file so attendees never wrestle with
# nested-quote escaping in PowerShell. They just run: ssh -F ssh_config vm
resource "local_file" "ssh_config" {
  filename        = "${path.module}/ssh_config"
  file_permission = "0644"
  content         = <<-EOT
    Host vm
      HostName ${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}
      User ubuntu
      IdentityFile tfkey
      StrictHostKeyChecking no
      UserKnownHostsFile NUL
      ProxyCommand "C:\Program Files\Git\mingw64\bin\connect.exe" -S proxy-us.intel.com:1080 %h %p
  EOT
}

resource "local_file" "ssh_config_no_proxy" {
  filename        = "${path.module}/ssh_config_no_proxy"
  file_permission = "0644"
  content         = <<-EOT
    Host vm
      HostName ${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}
      User ubuntu
      IdentityFile tfkey
      StrictHostKeyChecking no
      UserKnownHostsFile NUL
  EOT
}

resource "google_compute_firewall" "ssh" {
  name    = "smg-${var.name_prefix}-allow-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_cidrs
  target_tags   = ["smg-${var.name_prefix}-ssh"]
}

resource "google_compute_instance" "vm" {
  name         = "smg-${var.name_prefix}-vm"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["smg-${var.name_prefix}-ssh"]

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "hyperdisk-balanced"
    }
  }

  # GCP "-lssd" machine types REQUIRE one or more attached local SSDs.
  # We add exactly one for any -lssd variant, none otherwise.
  dynamic "scratch_disk" {
    for_each = endswith(var.machine_type, "-lssd") ? [1] : []
    content {
      interface = "NVME"
    }
  }

  network_interface {
    network = "default"
    access_config {} # ephemeral public IP
  }

  # Intel TDX Confidential VM. Only added when enable_confidential_vm = true,
  # which requires a c3-standard machine type (enforced by the precondition below).
  dynamic "confidential_instance_config" {
    for_each = var.enable_confidential_vm ? [1] : []
    content {
      enable_confidential_compute = true
      confidential_instance_type  = "TDX"
    }
  }

  # Confidential VMs can't live-migrate, so host maintenance must TERMINATE the
  # VM. GCP rejects a TDX instance that is left on the default MIGRATE policy.
  dynamic "scheduling" {
    for_each = var.enable_confidential_vm ? [1] : []
    content {
      on_host_maintenance = "TERMINATE"
    }
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh.public_key_openssh}"
  }

  labels = {
    workshop = "from-zero-to-xeon"
    attendee = var.name_prefix
    owner    = "smgworkshop_intel_com"
  }

  # Guardrail: Intel TDX is only offered on c3-standard machine types. Catch an
  # ARM-plus-confidential mismatch at plan time with a clear message instead of a
  # cryptic GCP API error.
  lifecycle {
    precondition {
      condition     = !var.enable_confidential_vm || startswith(var.machine_type, "c3-")
      error_message = "enable_confidential_vm = true requires a c3-standard machine type (e.g. c3-standard-4) for Intel TDX."
    }
  }
}
