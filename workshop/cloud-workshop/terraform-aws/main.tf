terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

# m8i is region-limited; us-east-1 is the safe default.
provider "aws" {
  region = "us-east-1"
}

# Use the account's default VPC to keep this module beginner-friendly.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Canonical Ubuntu 24.04 LTS (Noble), x86_64.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# SSH keypair for the instance. Gitignored.
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_sensitive_file" "private_key" {
  filename        = "${path.module}/tfkey"
  content         = tls_private_key.ssh.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = "${path.module}/tfkey.pub"
  content         = tls_private_key.ssh.public_key_openssh
  file_permission = "0644"
}

resource "aws_key_pair" "this" {
  key_name   = "smg-${var.name_prefix}-key"
  public_key = tls_private_key.ssh.public_key_openssh

  tags = {
    Name     = "smg-${var.name_prefix}-key"
    Workshop = "from-zero-to-xeon"
    Attendee = var.name_prefix
    Owner    = "SMGWorkshop@intel.com"
  }
}

# Shared security group: SSH (22) from Intel proxy CIDRs only.
resource "aws_security_group" "this" {
  name        = "smg-${var.name_prefix}-vllm-sg"
  description = "SSH (22) from Intel proxy CIDRs only"
  vpc_id      = data.aws_vpc.default.id

  # Intel proxy egress ranges.
  ingress {
    description = "SSH from allowed CIDRs"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [
      "134.134.0.0/16",
      "192.55.0.0/16",
      "146.152.0.0/16",
    ]
  }

  egress {
    description = "All egress (apt, HuggingFace, Docker Hub, pip, etc.)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "smg-${var.name_prefix}-vllm-sg"
    Workshop = "from-zero-to-xeon"
    Attendee = var.name_prefix
    Owner    = "SMGWorkshop@intel.com"
  }
}

# Intel Xeon 6 (Granite Rapids, AMX, DDR5): 128 vCPU / 512 GiB / 2 NUMA nodes
# (vLLM tensor-parallel-size 2).
resource "aws_instance" "vm" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "m8i.32xlarge"
  subnet_id                   = data.aws_subnets.default.ids[0]
  vpc_security_group_ids      = [aws_security_group.this.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true

  # Headroom for the vLLM image + BF16 model weights (~61 GB).
  root_block_device {
    volume_size           = 150
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name     = "smg-${var.name_prefix}-xeon6"
    Workshop = "from-zero-to-xeon"
    Attendee = var.name_prefix
    Owner    = "SMGWorkshop@intel.com"
  }
}

resource "local_file" "ssh_config" {
  filename        = "${path.module}/ssh_config"
  file_permission = "0644"
  content         = <<-EOT
    Host vm
      HostName ${aws_instance.vm.public_ip}
      User ubuntu
      IdentityFile tfkey
      StrictHostKeyChecking no
      UserKnownHostsFile NUL
      ProxyCommand "C:\Program Files\Git\mingw64\bin\connect.exe" -S proxy-us.intel.com:1080 %h %p
  EOT
}

resource "local_file" "ssh_config_no_proxy" {
  filename        = "${path.module}/ssh_config_no_proxy"
  file_permission = "0644"
  content         = <<-EOT
    Host vm
      HostName ${aws_instance.vm.public_ip}
      User ubuntu
      IdentityFile tfkey
      StrictHostKeyChecking no
      UserKnownHostsFile NUL
  EOT
}

# Linux/macOS variant of the Intel-proxy ssh_config: uses `nc -X 5 -x ...`
# instead of Git-for-Windows's connect.exe. Run with:
#   ssh -F ssh_config_linux vm
resource "local_file" "ssh_config_linux" {
  filename        = "${path.module}/ssh_config_linux"
  file_permission = "0644"
  content         = <<-EOT
    Host vm
      HostName ${aws_instance.vm.public_ip}
      User ubuntu
      IdentityFile tfkey
      StrictHostKeyChecking no
      UserKnownHostsFile /dev/null
      ProxyCommand nc -X 5 -x proxy-us.intel.com:1080 %h %p
  EOT
}
