variable "name_prefix" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "rds_security_group_id" {
  type = string
}

variable "postgres_version" {
  type    = string
  default = "16.3"
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "allocated_storage" {
  type    = number
  default = 20
}

variable "db_name" {
  type    = string
  default = "tracksystem"
}

variable "db_username" {
  type    = string
  default = "tracksystem_admin"
}

variable "multi_az" {
  type    = bool
  default = false
}
