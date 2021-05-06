provider "aws" {
    region = "ap-southeast-2"
}

variable "port_web" {
    description = "The web server port exposed"
    type = number
    default = 8080
}

variable "port_ssh" {
    description = "The ssh server port"
    type = number
    default = 22
}

variable "aws_lb_port" {
    type = number
    default = 80
}

resource "aws_launch_configuration" "example" {
    image_id = "ami-05f65755d328aa341"
    instance_type = "t2.micro"
    security_groups = [ aws_security_group.instance.id ]
    key_name = "win10-key"

    user_data = <<-EOF
                #!/usr/bin/env bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.port_web} &
                EOF
    
    lifecycle {
        create_before_destroy = true
    }
}

resource "aws_autoscaling_group" "example" {
    launch_configuration = aws_launch_configuration.example.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids

    target_group_arns   = [aws_lb_target_group.asg.arn]
    health_check_type   = "ELB"

    min_size = 2
    max_size = 10

    tag {
        key                 = "Name"
        value               = "terraform-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_security_group" "instance" {
  name = "terraform-instance"

  ingress = [{
              cidr_blocks      = ["0.0.0.0/0"]
              description      = "shell"
              from_port        = var.port_ssh
              ipv6_cidr_blocks = []
              prefix_list_ids  = []
              protocol         = "tcp"
              security_groups  = []
              self             = false
              to_port          = var.port_ssh
            },
            {
                cidr_blocks      = ["0.0.0.0/0"]
                description      = "web"
                from_port        = var.port_web
                ipv6_cidr_blocks = []
                prefix_list_ids  = []
                protocol         = "tcp"
                security_groups  = []
                self             = false
                to_port          = var.port_web
            }]
}

resource "aws_security_group" "alb" {
    name = "terraform-example-alb"
    
    ingress = [{
        cidr_blocks      = ["0.0.0.0/0"]
        description      = "web"
        from_port        = var.aws_lb_port
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "tcp"
        security_groups  = []
        self             = false
        to_port          = var.aws_lb_port
    }]
    egress = [{
        cidr_blocks      = ["0.0.0.0/0"]
        description      = "any"
        from_port        = 0
        ipv6_cidr_blocks = []
        prefix_list_ids  = []
        protocol         = "-1"
        security_groups  = []
        self             = false
        to_port          = 0
    }]
}


resource "aws_key_pair" "win10" {
  key_name   = "win10-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+GjTVDTutrR6B2kn8L94K1uT48Mnpo1Ht9BYb7gSsLqqgqC+eF+dgYqWYYZVc+K4NxPZKqCfWhiOm0cpAYAuDtljMhnejPGqFgAXYj53cDI2TzuJvde5QDMP9CD1G/xm1aL2bWnjWNl0C7avHpP9VaF0f84ICSqHV/NjoLn8p+zZyi8Z5CSGeUcM/HukNLGcGsudJ9Tx87zEbvJYKI0dE+FEaSyoygxrdEZ5qtqhW++uy+UA1Cd5LO1kn0sbeMh9qtPaT7bVTFO5gD1PjIPw+GK3QKg1fHkKnITy02z35C551qOhaGESZ3Wx0KZO2rlg16pgbjv8pm3uIw2gZ1ysb alexy@DESKTOP-84PV354"
}

resource "aws_lb" "example" {
    name                    = "terraform-asg-example"
    load_balancer_type      = "application"
    subnets                 = data.aws_subnet_ids.default.ids
    security_groups         = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn       = aws_lb.example.arn
    port                    = var.aws_lb_port
    protocol                = "HTTP"

    default_action {
        type = "fixed-response"
        fixed_response {
            content_type = "text/plain"
            message_body = "404: page not found"
            status_code = 404
        }
    }
}

resource "aws_lb_target_group" "asg" {
    name            = "terraform-asg-example"
    port            = var.port_web
    protocol        = "HTTP"
    vpc_id          = data.aws_vpc.default.id

    health_check {
        path            = "/"
        protocol        = "HTTP"
        matcher         = "200"
        interval        = 15
        timeout         = 3
        healthy_threshold   = 2
        unhealthy_threshold = 2
    }
}

resource "aws_lb_listener_rule" "asg" {
    listener_arn = aws_lb_listener.http.arn
    priority    =   100

    condition {
        path_pattern {
            values = ["*"]
        }
    }

    action {
        type                = "forward"
        target_group_arn    = aws_lb_target_group.asg.arn
    }
}

data "aws_vpc" "default" {
    default = true
}

data "aws_subnet_ids" "default" {
    vpc_id = data.aws_vpc.default.id
}

output "alb_dns_name" {
    value = aws_lb.example.dns_name
    description = "The domain name of the load balancer"
}