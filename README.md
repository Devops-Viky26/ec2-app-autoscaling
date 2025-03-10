Target Application Architecture - ec2-autoscaling-app

Frontend Tier
Stateless web servers on EC2 instances in an Auto Scaling Group (ASG).
Deployed across public subnets in two Availability Zones (AZs).
Behind an Application Load Balancer (ALB) for traffic distribution.
Auto-scaling triggered by CPU utilization.

Database Tier
PostgreSQL RDS instance in private subnets.
Access restricted to EC2 instances via security groups.
Multi-AZ deployment enabled for production.

Network
VPC with public and private subnets.
NAT Gateway for outbound internet access from private subnets.

Auto Scaling Threshold
Metric: Average CPU Utilization across ASG instances
Threshold: 70%
Evaluation Period: 2 minutes
Why 70%?
Handles Traffic Spikes: Leaves room for sudden load increases.
Cost-Efficient: Prevents over-scaling for short traffic bursts.
Industry Standard: Matches best practices for different workloads:
Stateless apps: 60-70%
Stateful apps: 50-60%
Bursty workloads: 80-90%

Health Checks
ALB Health Checks: Replaces instances that fail HTTP health checks.
ASG Health Checks: Ensures instances are running correctly at the hardware/OS level.
