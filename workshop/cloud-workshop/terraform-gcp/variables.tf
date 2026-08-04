variable "name_prefix" {
  description = "Unique prefix per attendee (e.g. bob). Tags every resource."
  type        = string
  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 10
    error_message = "name_prefix must be 3-10 characters."
  }
}

variable "project_id" {
  description = "GCP project ID for the workshop sandbox (provided by the instructor)."
  type        = string
}

variable "region" {
  description = "GCP region."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone."
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "GCP machine type. Default starts on Axion (ARM, no Intel TDX). Switch to c3-standard-4 (Intel Xeon, Sapphire Rapids) and set enable_confidential_vm = true to get an Intel TDX Confidential VM."
  type        = string
  default     = "c4a-standard-2"
}

variable "enable_confidential_vm" {
  description = "Enable Intel TDX Confidential Computing. Requires a c3-standard machine type. Leave false for the ARM box; set true when switching to c3-standard-4."
  type        = bool
  default     = false
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to SSH to the VM. Defaults to Intel proxy egress."
  type        = list(string)
  default = [
    "134.134.0.0/16",
    "192.55.0.0/16",
    "146.152.0.0/16",
  ]
}
