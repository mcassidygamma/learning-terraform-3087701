data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner] # Bitnami
}

module "blogm_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["us-west-2a","us-west-2b","us-west-2c"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24", "${var.environment.network_prefix}.103.0/24"]


  tags = {
    Terraform = "true"
    Environment = var.environment.name
  }
}

module "blogm_autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.5.2"
  
  name = "blog-martin"
  min_size = var.min_size
  max_size = var.max_size

  vpc_zone_identifier = module.blogm_vpc.public_subnets
  target_group_arns = module.blogm_alb.target_group_arns
  security_groups = [module.blogm_sg.security_group_id]
  image_id = data.aws_ami.app_ami.id
  instance_type = var.instance_type
}

module "blogm_alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name    = "blog-martin-alb"

load_balancer_type = "application"

  vpc_id  = module.blogm_vpc.vpc_id
  subnets = module.blogm_vpc.public_subnets
  security_groups = [module.blogm_sg.security_group_id]

  target_groups = [
    {
      name_prefix      = "blogm-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners  = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = var.environment.name
  }
}

module "blogm_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.13.0"

  vpc_id  = module.blogm_vpc.vpc_id
  name    = "blog-martin"
  ingress_rules = ["https-443-tcp","http-80-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]
  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}