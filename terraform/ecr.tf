# terraform/ecr.tf

resource "aws_ecr_repository" "server" {
  name = "${var.project_name}/server"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # <-- ADD THIS LINE
}

resource "aws_ecr_repository" "webapp" {
  name = "${var.project_name}/webapp"
  image_tag_mutability = "MUTABLE"
  force_delete         = true # <-- ADD THIS LINE
}