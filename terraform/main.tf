# Get Available AZs
data "aws_availability_zones" "available" {
    state = "available"
}

# VPC
resource "aws_vpc" "main" {
    cidr_block           = "10.1.0.0/16"      
    enable_dns_hostnames = true
    enable_dns_support   = true

    tags = {
        Name        = "${var.project_name}-vpc"
        Environment = var.environment
    }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
    vpc_id = aws_vpc.main.id

    tags = {
        Name        = "${var.project_name}-IGW"
        Environment = var.environment 
    }
}

# Public Subnets


resource "aws_subnet" "public" {
    count                   = 2
    vpc_id                  = aws_vpc.main.id
    cidr_block              = "10.1.${count.index}.0/24"  # Use 10.1.x.0/24 instead of 10.0.x.0/24
    availability_zone       = data.aws_availability_zones.available.names[count.index]
    map_public_ip_on_launch = true

    tags = {
        Name        = "${var.project_name}-public-subnet-${count.index + 1}"
        Environment = var.environment
    }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.main.id
    }

    tags = {
        Name        = "${var.project_name}-public-rt"
        Environment = var.environment
    }
}

# Route Table Association
resource "aws_route_table_association" "public" {
    count          = 2
    subnet_id      = aws_subnet.public[count.index].id
    route_table_id = aws_route_table.public.id
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_task" {
    name        = "${var.project_name}-ecs-task-sg"
    description = "Allow inbound HTTP traffic for ECS task"
    vpc_id      = aws_vpc.main.id

    ingress {
        description = "Allow HTTP inbound"
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Allow SSH access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name        = "${var.project_name}-ecs-tasks-sg"
        Environment = var.environment
    }
}

# ECS Repository
resource "aws_ecr_repository" "app" {
    name = "hello-world-app"  # Corrected name

    image_scanning_configuration {
        scan_on_push = true
    }

    tags = {
        Name        = "${var.project_name}-ecr"
        Environment = var.environment
    }
}
# ECS Cluster
resource "aws_ecs_cluster" "main" {
    name = "${var.project_name}-cluster"

    tags = {
        Name        = "${var.project_name}-ecs-cluster"
        Environment = var.environment
    }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs-task-execution-role" {
    name = "${var.project_name}-ecs-task-execution-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ecs-tasks.amazonaws.com"
                }
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# Attach the AWS Managed Policy for ECS Task Execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
    role       = aws_iam_role.ecs-task-execution-role.name
    policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
    family                   = "${var.project_name}-task"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = "256"
    memory                   = "512"
    execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn

    container_definitions = jsonencode([
        {
            name  = "${var.project_name}-container",
            image = "${aws_ecr_repository.app.repository_url}:latest",
            essential = true,

            portMappings = [
                {
                    containerPort = 80,
                    hostPort      = 80,
                    protocol      = "tcp"
                }
            ],

            logConfiguration = {
                logDriver = "awslogs",
                options = {
                    "awslogs-group"         = "/ecs/${var.project_name}",
                    "awslogs-region"        = var.aws_region,
                    "awslogs-stream-prefix" = "ecs"
                }
            }
        }
    ])

    tags = {
        Name        = "${var.project_name}-taskdef"
        Environment = var.environment
    }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_logs" {
    name              = "/ecs/${var.project_name}"
    retention_in_days = 30

    tags = {
        Name        = "${var.project_name}-logs"
        Environment = var.environment
    }
}

# ECS Service
resource "aws_ecs_service" "app" {
    name            = "${var.project_name}-service"
    cluster         = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.app.arn
    desired_count   = 1
    launch_type     = "FARGATE"

    network_configuration {
        subnets          = aws_subnet.public[*].id
        security_groups  = [aws_security_group.ecs_task.id]
        assign_public_ip = true
    }

    tags = {
        Name        = "${var.project_name}-ecs-service"
        Environment = var.environment
    }
}



# #Get Available AZs

# data "aws_availability_zones" "available" {

#     state = "available"
# }

# #VPC

# resource "aws_vpc" "main" {
#     cidr_block = "10.1.0.0/16"      
#     enable_dns_hostnames = "true"
#     enable_dns_support = "true"

#     tags = {
#             Name = var.project_name+ "-vpc"
#             Environment = var.environment
#     }

# }

# #internet gateway 

# resource "aws_internet_gateway" "main" {
#     vpc_id = aws_vpc.main.id

#     tags = {
#         Name = var.project_name + "-IGW"
#         Environment = var.environment 
#     }
# }

# #public subnet

# resource "aws_subnet" "public" {
#         count = 2
#         vpc_id = aws_vpc.main.id
#         cidr_block = "10.0.${count.index+1}.1/24"
#         availability_zone = data.aws_availability_zones.available.names[count.index]
#         map_public_ip_on_launch = true

#         tags = {
#             Name = "${var.project_name}-public-subnet-${count.index + 1}"
#             Environment = var.environment
#        }
  
# }

# # Route Table for Public Subnets

# resource "aws_route_table" "public" {
#     vpc_id = aws_vpc.main.id
#     route = {
#         cidr_block = "0.0.0.0/0"
#         gateway_id = aws_internet_gateway.main.id
#     }

#     tags = {
#       Name = "${var.project_name}-public-rt"
#       Environment =var.environment
#     }
# }

# #route table association

# resource "aws_route_table_association" "public" {

#     count = 2
#     subnet_id = aws_subnet.public[count.index].id
#     route_table_id = aws_route_table.public.id
  
# }


# #security Group for Ecs Tasks

# resource "aws_security_group" "esc_task" {
#     name = "${var.project_name}-ecs-task-sg"
#     description = "Allow inbound http port 80 for ecs task"
#     vpc_id = aws_vpc.main.id

#     ingress {
#         description = "Allow Http inbound"
#         from_port = 80
#         to_port = 80
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]

#     }

#     ingress {
#         description = "allow ssh port 22"
#         from_port = 22
#         to_port = 22
#         protocol = "tcp"
#         cidr_blocks = ["0.0.0.0/0"]

#     }

#     egress {

#         from_port = 0
#         to_port = 0
#         cidr_blocks = ["0.0.0.0/0"]
#     }

#     tags = {

#         Name = "${var.project_name}-ecs-tasks-sg"
#         Environment = var.environment
#     }
# }

# #ecs repository

# resource "aws_ecr_repository" "app" {

#     name = "${var.project_name}-app"

#     image_scanning_configuration {
#       scan_on_push = true
#     }

#     tags = {
#         Name = "${var.project_name}-ecr"
#         Environment = var.environment
#     }
  

# }

# #ecs cluster

# resource "aws_ecs_cluster" "main" {
#     name = "${var.project_name}"-cluster

#     tags = {
#         Name = "${var.project_name}"-ecs-cluster
#         Environment = var.environment
#     }
  
# }


# #ecs Task execution role

# resource "aws_iam_role" "ecs-task-execution-role" {
#     name = "${var.project_name}-ecs-task-execution-role"

#     assume_role_policy = jsondecode({
#         Version = "2012-10-17"
#         statement = [
#             {
#             Action = "sts:AssumeRole"
#             Effect = "Allow"
#             Principal = {
#                 Service = "ecs-tasks.amozonaws.com"

#             }

#     }

#         ]
#     }) 
  
# }

# #Attach the AWS managed policy for ECS task execution
# resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
#     role = aws_iam_role.ecs-task-execution-role.name
#     policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  
# }


# resource "aws_ecs_task_definition" "app" {
#     family                   = "${var.project_name}-task"
#     network_mode             = "awsvpc"
#     requires_compatibilities = ["FARGATE"]
#     cpu                      = "256"
#     memory                   = "512"
#     execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn

#     container_definitions = jsonencode([
#         {
#             name  = "${var.project_name}-container",
#             image = "${aws_ecr_repository.app.repository_url}:latest",
#             essential = true,

#             portMappings = [
#                 {
#                     containerPort = 80,
#                     hostPort      = 80,
#                     protocol      = "tcp"
#                 }
#             ],

#             logConfiguration = {
#                 logDriver = "awslogs",
#                 options = {
#                     "awslogs-group"         = "/ecs/${var.project_name}",
#                     "awslogs-region"        = var.aws_region,
#                     "awslogs-stream-prefix" = "ecs"
#                 }
#             }
#         }
#     ])

#     tags = {
#         Name        = "${var.project_name}-taskdef"
#         Environment = var.environment
#     }
# }



# # #ecs task defination

# # resource "aws_ecs_task_definition" "app" {
# #     family = "${var.project_name}-task"
# #     network_mode = "awsvpc"
# #     requires_compatibilities = ["FARGATE"]
# #     cpu = 256
# #     memory = 512
# #     execution_role_arn = aws_iam_role.ecs-task-execution-role.arn

# #     container_definitions = jsonencode([
# #         name = "${var.project_name}-container",
# #         image = "${aws_ecr_repository.app.repository_url}:latest",
# #         portMappings =[{
# #             containerPort = 80
# #             hostport =80
# #             protocol= "tcp"


# #         }]

# #         logconfiguration = {

# #             logDriver = "awslog"
# #             options = {

# #                 "awslogs-group" = "/ecs/${var.project_name}"
# #                 "awslogs-region" = var.aws_region
# #                 "awslogs-stream-prefix" = "ecs"

# #             }
# #         }

# #     ])
# #     tags {
# #         Name = "${var.project_name}-taskdef"
# #         Environment = var.environment
# #     }
  
# # }


# #cloudwatch log group

# resource "aws_cloudwatch_log_group" "ecs_logs" {
#     name = "/ecs/${var.project_name}"
#     retention_in_days = 30

#     tags = {

#         Name = "${var.project_name}-logs"
#         Environment = var.environment
#     }
  
# }

# #ecs-service

# resource "aws_ecs_service" "app" {
#     name = "${var.project_name}-service"
#     cluster = aws_ecs_cluster.main.id
#     task_definition = aws_ecs_task_definition.app.arn
#     desired_count = 1
#     launch_type = "FARGATE"

#     network_configuration {
#     subnets = aws_subnet.public[*].id
#     security_groups = [aws_ecs_service.ecs_tasks.id]
#     assign_public_ip = true


# }
#     tags = {
#         Name = "${var.project_name}-ecs_service"
#         Environment= var.environment
#     }

  
# }




