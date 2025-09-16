# terraform/variables.tf

variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "mern-app"
}

variable "db_username" {
  description = "Master username for the DocumentDB cluster."
  type        = string
  sensitive   = true
  # Note: For a real project, use a secrets manager.
  # For this tutorial, we'll pass it during the 'apply' step.
}

variable "db_password" {
  description = "Master password for the DocumentDB cluster."
  type        = string
  sensitive   = true
  # Note: For a real project, use a secrets manager.
}