# main.tf

provider "aws" {
  region = "us-east-1"
  profile = "skewb-demo-site"
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
#   version = "~> 3.0"

  name = "app-vpc"
  cidr = "192.168.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["192.168.1.0/24","192.168.2.0/24"]
  private_subnets = ["192.168.3.0/24","192.168.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
}

# Security Groups
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg"
  description = "Allow HTTP from ALB and SSH"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow PostgreSQL traffic from EC2"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

# Application Load Balancer
resource "aws_lb" "frontend_alb" {
  name               = "frontend-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "frontend_tg" {
  name     = "frontend-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path = "/"
  }
}

resource "aws_lb_listener" "frontend_listener" {
  load_balancer_arn = aws_lb.frontend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend_tg.arn
  }
}

# Auto Scaling Group
resource "aws_launch_template" "frontend_lt" {
  name_prefix   = "frontend-lt"
  image_id      = "ami-08b5b3a93ed654d19" # Amazon Linux 2
  instance_type = "t2.micro"
  key_name      = "ec2-app-autoscale"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "Hello from $(hostname)" > /var/www/html/index.html
    EOF
  )
}

resource "aws_autoscaling_group" "frontend_asg" {
  name                = "frontend-asg"
  desired_capacity    = 2
  max_size            = 5
  min_size            = 2
  vpc_zone_identifier = module.vpc.public_subnets
  target_group_arns   = [aws_lb_target_group.frontend_tg.arn]

  launch_template {
    id      = aws_launch_template.frontend_lt.id
    version = "$Latest"
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "scale-up-policy"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.frontend_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# RDS Database
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "rds-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_db_instance" "backend_rds" {
  identifier             = "backend-rds"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  username               = "postgres"
  password               = "securepassword123"
  skip_final_snapshot    = true
}