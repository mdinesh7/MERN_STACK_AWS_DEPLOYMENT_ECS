# terraform/ecs.tf

# Create an ECS cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
}

# Create an Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

# Create a listener for the ALB on port 80
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  # Default action sends traffic to the webapp (frontend)
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
}

# Create a listener rule to route API traffic to the backend
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.server.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"] # Any URL starting with /api/ goes to the server
    }
  }
}

# Create a target group for the webapp
resource "aws_lb_target_group" "webapp" {
  name     = "${var.project_name}-webapp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/"
  }
}

# Create a target group for the server
resource "aws_lb_target_group" "server" {
  name     = "${var.project_name}-server-tg"
  port     = 3003 # Your server's port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path = "/" # Assuming your server responds to '/' for health checks
  }
}

# IAM role that allows ECS tasks to be executed
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# Attach the required policy to the IAM role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Create the ECS Task Definition for the webapp
resource "aws_ecs_task_definition" "webapp" {
  family                   = "${var.project_name}-webapp"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name      = "webapp"
    image     = aws_ecr_repository.webapp.repository_url
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 80
      hostPort      = 80
    }]
  }])
}

# Create the ECS Task Definition for the server
resource "aws_ecs_task_definition" "server" {
  family                   = "${var.project_name}-server"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name      = "server"
    image     = aws_ecr_repository.server.repository_url
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 3003
      hostPort      = 3003
    }]
    environment = [
      {
        name  = "DATABASE_URL"
        value = "mongodb://${var.db_username}:${var.db_password}@${aws_docdb_cluster.main.endpoint}:27017"
      }
    ]
  }])
}

# Create the ECS Service for the webapp
resource "aws_ecs_service" "webapp" {
  name            = "${var.project_name}-webapp-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.webapp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.webapp.arn
    container_name   = "webapp"
    container_port   = 80
  }
}

# Create the ECS Service for the server
resource "aws_ecs_service" "server" {
  name            = "${var.project_name}-server-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.server.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = aws_subnet.public[*].id
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.server.arn
    container_name   = "server"
    container_port   = 3003
  }
}