# The only variable in this workshop. Everything else is hardcoded in main.tf
# so there is a single place to look when reading the configuration.
variable "name_prefix" {
  description = "Unique prefix per attendee (e.g. bob). Tags every resource."
  type        = string
  validation {
    condition     = length(var.name_prefix) >= 3 && length(var.name_prefix) <= 10
    error_message = "name_prefix must be 3-10 characters."
  }
}
