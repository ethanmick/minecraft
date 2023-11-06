
resource "aws_security_group" "minecraft_sg" {
  vpc_id = aws_vpc.minecraft_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Minecraft EC2 Instance Security Group"
  }
}

resource "aws_instance" "minecraft_instance" {
  ami                         = "ami-016485166ec7fa705"
  instance_type               = "t4g.large"
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.minecraft_sg.id]
  associate_public_ip_address = true
  key_name                    = "ethan_mick"
  tags = {
    Name       = "Minecraft v3"
    Autodeploy = "true"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y nfs-common
              mkdir -p /mnt/efs
              mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs
              echo '${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0' >> /etc/fstab
              EOF
}

### EFS
resource "aws_efs_file_system" "minecraft_efs" {
  creation_token = "minecraft-efs"

  tags = {
    Name = "Minecraft EFS"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "efs-sg"
  description = "Allow NFS for EFS"
  vpc_id      = aws_vpc.minecraft_vpc.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.public_subnet_cidrs[0]]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "efs_mt" {
  file_system_id  = aws_efs_file_system.minecraft_efs.id
  subnet_id       = aws_subnet.public_subnets[0].id
  security_groups = [aws_security_group.efs_sg.id]
}
