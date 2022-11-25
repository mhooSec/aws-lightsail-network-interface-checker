terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.36.1"
    }
  }
}

provider "aws" {
  shared_credentials_files = ["$HOME/.aws/credentials"]
  shared_config_files      = ["$HOME/.aws/config"]
  profile                  = "${var.aws_profile}"
  region                   = var.region
}

# Create a new Lightsail instance
resource "aws_lightsail_instance" "test" {
  count             = length(data.aws_availability_zones.available.names)
  name              = "${var.instance_name}-${count.index}"
  availability_zone = data.aws_availability_zones.available.names[count.index]
  blueprint_id = var.blueprint_id
  bundle_id    = var.bundle_id
  tags = {
    "instance_type" = "checker"
  }

  # Execute any command in the server as long as it is available. This way we pause the script until servers are reachable
  provisioner "remote-exec" {
    inline = [
      "ifconfig -l"
    ]
  }

  # For reference purposes only. Not relevant
  provisioner "local-exec" {
    command = "echo The server IP is ${self.public_ip_address}"
  }

  connection {
    type        = "ssh"
    host        = self.public_ip_address
    user        = "${var.REMOTE_USER}"
    private_key = file("${var.SSHKEY_PATH}/${var.SSHKEY_FILE}")
    timeout     = "10m"
  }
}

resource "aws_lightsail_key_pair" "lg_key_pair" {
  name = "importing"
  public_key = file("${var.SSHKEY_PATH}/${var.SSHKEY_FILE}.pub")
}
