/*--------------------------------------------------------------
  main.tf
  * maintained by @norchen
  * for educational purpose only, no production readyness
    garantued

  This file contains a sample setup for a fargte distributed service architecture
  Including:
    - ECS Cluster (Fargate)
    - Cluster Security Group
    - Service Discovery (Namespace)
--------------------------------------------------------------*/

/*--------------------------------------------------------------
   set provider
--------------------------------------------------------------*/
# the starting point to connect to AWS
provider "aws" {
  region  = local.region

  default_tags {
    tags = {
      project    = local.project
      env        = local.stage
      region     = local.region
      maintainer = "Nora Schöner"
    }
  }
}

locals {
  region  = "us-east-1"
  project = "jug-demo"
  stage   = "dev"

  resource_prefix = join("-", [local.project, local.stage])

  use_loadbalancer_for_service = true
  fargate_sevice_desired_count = 1
  fargate_log_group_name       = "fargate/demo-app"
  fargate_container_name = "jug-demo"
}

/*--------------------------------------------------------------
  Networking Stuff
--------------------------------------------------------------*/
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "${local.region}a"

  tags = {
    Name = "Default subnet for ${local.region}a"
  }
}

resource "aws_default_subnet" "default_az2" {
  availability_zone = "${local.region}b"

  tags = {
    Name = "Default subnet for ${local.region}b"
  }
}

/*--------------------------------------------------------------
  Fargate Cluster
--------------------------------------------------------------*/
resource "aws_ecs_cluster" "fargate" {
  name = join("-", [local.resource_prefix, "cluster"])

  # enable container insights if needed (costs extra)
  # setting {
  #   name  = "containerInsights"
  #   value = "enabled"
  # }
}


resource "aws_security_group" "fargate" {
  name        = join("-", [local.resource_prefix, "fargate"])
  description = "security group for AWS fargate"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self = true
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = join("-", [local.resource_prefix, "fargate"]) }
}
/*--------------------------------------------------------------
  Service w/o Loadbalancer
--------------------------------------------------------------*/
resource "aws_ecs_service" "service" {
  count           = local.use_loadbalancer_for_service ? 0 : 1
  name            = "web-app-test-without-lb"
  cluster         = aws_ecs_cluster.fargate.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = local.fargate_sevice_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.fargate.id]
    subnets          = [aws_default_subnet.default_az1.id]
    assign_public_ip = true
  }

  # ignore changes when desired count differ
  lifecycle {
    ignore_changes = [desired_count]
  }
}

/*--------------------------------------------------------------
  Service w/ Loadbalancer
--------------------------------------------------------------*/
resource "aws_ecs_service" "service_with_loadbalancer" {
  count           = local.use_loadbalancer_for_service ? 1 : 0
  name            = "web-app-test-with-lb"
  cluster         = aws_ecs_cluster.fargate.id
  task_definition = aws_ecs_task_definition.task.arn
  desired_count   = local.fargate_sevice_desired_count
  launch_type     = "FARGATE"
  #health_check_grace_period_seconds = var.ecs_service_health_check_grace_period_seconds


  network_configuration {
    security_groups  = [aws_security_group.fargate.id]
    subnets          = [aws_default_subnet.default_az1.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.loadbalancer[0].id
    container_name   = local.fargate_container_name
    container_port   = 80
  }

  # ignore changes when desired count differ
  lifecycle {
    ignore_changes = [desired_count]
  }
}

/*-----------------------------------------------------------
  Loadbalancer
-----------------------------------------------------------*/
# Security Group
resource "aws_security_group" "loadbalancer" {
  count       = local.use_loadbalancer_for_service ? 1 : 0
  name        = join("-", [local.resource_prefix, "lb"])
  description = "Loadbalancer for Fargate demo"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = join("-", [local.resource_prefix, "lb"]) }
}

resource "aws_lb" "loadbalancer" {
  count              = local.use_loadbalancer_for_service ? 1 : 0
  name               = join("-", [local.resource_prefix, "lb"])
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.loadbalancer[0].id]
  subnets = [
    aws_default_subnet.default_az1.id,
    aws_default_subnet.default_az2.id,
  ]
}

resource "aws_lb_target_group" "loadbalancer" {
  count       = local.use_loadbalancer_for_service ? 1 : 0
  name        = join("-", [local.resource_prefix, "tg"])
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_default_vpc.default.id
  target_type = "ip"
}

resource "aws_lb_listener" "loadbalancer" {
  count             = local.use_loadbalancer_for_service ? 1 : 0
  load_balancer_arn = aws_lb.loadbalancer[0].arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.loadbalancer[0].arn
  }
}

/*--------------------------------------------------------------
  Logging
--------------------------------------------------------------*/
resource "aws_cloudwatch_log_group" "log" {
  name              = local.fargate_log_group_name
  retention_in_days = 7
}

/*--------------------------------------------------------------
  ECS task execution role & policy
--------------------------------------------------------------*/
# ECS task execution role data
data "aws_iam_policy_document" "ecs_task_execution" {
  version = "2012-10-17"
  statement {
    sid     = ""
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# ECS task execution role
resource "aws_iam_role" "ecs_task_execution" {
  name               = join("-", [local.resource_prefix, "ecs-execution-role"])
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution.json
}

# ECS task execution role policy attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

/*--------------------------------------------------------------
  Task
--------------------------------------------------------------*/
resource "aws_ecs_task_definition" "task" {
  family                   = local.fargate_container_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  container_definitions = jsonencode([
    {
      name  = local.fargate_container_name
      image = "yeasy/simple-web:latest"
      # environment = []
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = local.fargate_log_group_name
          awslogs-region        = local.region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  # needed if you want to call other AWS services
  # task_role_arn            = aws_iam_role.ecs_task.arn
}
