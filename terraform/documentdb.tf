# terraform/documentdb.tf

# Create a subnet group required for DocumentDB
resource "aws_docdb_subnet_group" "main" {
  name       = "${var.project_name}-docdb-subnet-group"
  subnet_ids = aws_subnet.public[*].id
  tags = {
    Name = "${var.project_name}-docdb-subnet-group"
  }
}

# Create the DocumentDB cluster
resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.project_name}-docdb-cluster"
  engine                  = "docdb"
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.docdb.id]
  skip_final_snapshot     = true
}

# Create a cluster instance (the actual database node)
resource "aws_docdb_cluster_instance" "main" {
  cluster_identifier = aws_docdb_cluster.main.id
  identifier         = "${var.project_name}-docdb-instance"
  instance_class     = "db.t3.medium"
  engine             = aws_docdb_cluster.main.engine
}