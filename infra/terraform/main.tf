terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "tiwa-devops-hng13-stage6"
    key            = "micro-todo-app/terraform.tfstate"
    region         = "af-south-1"
    encrypt        = true
    dynamodb_table = "tiwa-devops-terraform-state-lock"
  }
}

provider "aws" {
  region = var.aws_region
}

# Security Group
resource "aws_security_group" "micro_todo_app_sg" {
  name        = "micro-todo-app-sg"
  description = "Security group for the Microservice TODO app"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "micro-todo-app-sg"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Key Pair
resource "aws_key_pair" "micro_todo_app_key" {
  key_name   = "micro-todo-app-key"
  public_key = file("${path.module}/keys/id_rsa.pub")

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "micro-todo-app-key"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EC2 Instance
resource "aws_instance" "micro_todo_app_server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.micro_todo_app_key.key_name

  vpc_security_group_ids = [aws_security_group.micro_todo_app_sg.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y python3 python3-pip
              EOF

  tags = {
    Name        = "micro-todo-app-server"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [user_data]
  }
}

# Generate Ansible Inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    server_ip  = aws_instance.micro_todo_app_server.public_ip
    ssh_user   = var.ssh_user
    ssh_key    = var.ssh_private_key_path
  })
  filename = "${path.module}/../ansible/inventory/hosts"

  depends_on = [aws_instance.micro_todo_app_server]
}

# Wait for instance to be ready
resource "null_resource" "wait_for_instance" {
  provisioner "local-exec" {
    command = "sleep 30"
  }

  depends_on = [
    aws_instance.micro_todo_app_server,
    local_file.ansible_inventory
  ]
}

# Run Ansible - only executed when instance changes
resource "null_resource" "run_ansible" {
  triggers = {
    instance_id = aws_instance.micro_todo_app_server.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Running Ansible playbook..."
      
      # Create .ssh directory if it doesn't exist
      mkdir -p $HOME/.ssh
      chmod 700 $HOME/.ssh
      
      # Check if SSH key exists, if not, skip Ansible
      if [ ! -f "$HOME/.ssh/id_rsa" ]; then
        echo "SSH key not found at $HOME/.ssh/id_rsa"
        exit 0
      fi
      
      echo "SSH key found, proceeding with Ansible..."
      
      # Wait for instance to be ready
      sleep 30
      
      # Add server to known hosts
      ssh-keyscan -H ${aws_instance.micro_todo_app_server.public_ip} >> $HOME/.ssh/known_hosts 2>/dev/null || true
      
      # Change to ansible directory
      cd ${path.module}/../ansible
      
      # Check if ansible is installed
      if ! command -v ansible-playbook &> /dev/null; then
        echo "Installing Ansible..."
        pip install --user ansible
      fi
      
      # Run Ansible with explicit key path
      ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook \
        -i inventory/hosts \
        playbook.yml \
        --private-key=$HOME/.ssh/id_rsa \
        -e "domain_name=${var.domain_name}" \
        -e "acme_email=${var.acme_email}" \
        -v
    EOT
  }

  depends_on = [
    local_file.ansible_inventory,
    null_resource.wait_for_instance
  ]
}