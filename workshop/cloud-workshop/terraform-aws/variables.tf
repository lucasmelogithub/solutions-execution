variable "name_prefix" {
  description = "Unique prefix per attendee (e.g. bob). Tags every resource."
  type        = string
  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 10
    error_message = "name_prefix must be 3-10 characters."
  }
}

variable "aws_region" {
  description = "AWS region. m8i is region-limited; us-east-1 is the safe default."
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  description = "Intel Xeon 6 instance type (Granite Rapids, AMX, DDR5). m8i.32xlarge = 128 vCPU / 512 GiB / 2 NUMA nodes (vLLM tensor-parallel-size 2)."
  type        = string
  default     = "m8i.32xlarge"
}

variable "allowed_cidrs" {
  description = "CIDR ranges allowed to reach SSH (22). Defaults to Intel proxy egress."
  type        = list(string)
  default = [
    "134.134.0.0/16",
    "192.55.0.0/16",
    "146.152.0.0/16",
  ]
}

variable "root_volume_size_gb" {
  description = "Root EBS volume size in GiB. Needs headroom for the vLLM image + BF16 model weights (~61 GB)."
  type        = number
  default     = 150
}
