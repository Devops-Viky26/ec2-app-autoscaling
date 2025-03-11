# Target Application Architecture  

## Frontend Tier  
- EC2 instances in an **Auto Scaling Group (ASG)**.  
- Deployed across **two public subnets** in different **Availability Zones (AZs)**.  
- Traffic managed by an **Application Load Balancer (ALB)**.  
- ASG scales based on **CPU utilization**.  

## Database Tier  
- **PostgreSQL RDS** in **private subnets**.  
- Accessible only by EC2 instances via **security group rules**.  
- **Multi-AZ deployment** enabled for production.  

## Network  
- **VPC** with **public and private subnets**.  
- **NAT Gateway** for internet access from private subnets.  

---

# Auto Scaling  

- **Metric:** Average **CPU utilization** across ASG instances.  
- **Threshold:** **70%**.  
- **Evaluation Period:** **2 minutes**.  

### Why 70%?  
- Provides headroom for traffic spikes.  
- Prevents unnecessary scaling.  
- Follows cloud best practices.  

---

# Health Checks  

- **ALB Health Checks:** Replace failed instances.  
- **ASG Health Checks:** Ensure EC2 instances are healthy.  

