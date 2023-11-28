packer {
  required_plugins {
    amazon = {
      version = ">= 0.0.2"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# aws ec2 describe-images --image-ids ami-0feba2720136a0493
source "amazon-ebs" "ubuntu" {
  ami_name      = "minecraft-on-demand"
  instance_type = "t4g.large"
  region        = "us-east-1"
  subnet_id     = "subnet-08dad3ad03e6fd34a"

  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-jammy-22.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "setup-minecraft"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  provisioner "file" {
    source      = "./docker-compose.yml"
    destination = "docker-compose.yml"
  }

  provisioner "shell" {
    inline = [
      "echo Installing Docker",
      "sudo apt-get update",
      "sudo apt-get install -y curl",
      "sudo install -m 0755 -d /etc/apt/keyrings",
      "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg",
      "sudo chmod a+r /etc/apt/keyrings/docker.gpg",
      "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin",
      "echo Pulling Minecraft image",
      "sudo docker image pull itzg/minecraft-server"
    ]
  }
}