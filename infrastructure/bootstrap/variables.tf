variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  type    = string
  default = "track-system-terraform-state"
}

variable "lock_table_name" {
  type    = string
  default = "track-system-terraform-locks"
}
