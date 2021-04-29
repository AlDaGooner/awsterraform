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

resource "aws_instance" "simple" {
    ami = "ami-076a5bf4a712000ed"
    instance_type = "t2.micro"
    vpc_security_group_ids = [ aws_security_group.instance.id ]
    key_name = "win10-key"

    user_data = <<-EOF
                #!/usr/bin/env bash
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.port_web} &
                EOF
    
    tags = {
        Name = "Simple terraform example"
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

resource "aws_key_pair" "win10" {
  key_name   = "win10-key"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC+GjTVDTutrR6B2kn8L94K1uT48Mnpo1Ht9BYb7gSsLqqgqC+eF+dgYqWYYZVc+K4NxPZKqCfWhiOm0cpAYAuDtljMhnejPGqFgAXYj53cDI2TzuJvde5QDMP9CD1G/xm1aL2bWnjWNl0C7avHpP9VaF0f84ICSqHV/NjoLn8p+zZyi8Z5CSGeUcM/HukNLGcGsudJ9Tx87zEbvJYKI0dE+FEaSyoygxrdEZ5qtqhW++uy+UA1Cd5LO1kn0sbeMh9qtPaT7bVTFO5gD1PjIPw+GK3QKg1fHkKnITy02z35C551qOhaGESZ3Wx0KZO2rlg16pgbjv8pm3uIw2gZ1ysb alexy@DESKTOP-84PV354"
}

output "public_ip" {
    value = aws_instance.simple.public_ip
    description = "The public IP of the created EC2 instance."
}