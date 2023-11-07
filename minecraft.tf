
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

resource "aws_iam_role" "efs_access" {
  name = "efs_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "efs_access_policy" {
  name = "efs_access_policy"
  role = aws_iam_role.efs_access.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:DescribeFileSystems",
        ],
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_instance_profile" "efs_access_profile" {
  name = "efs_access_profile"
  role = aws_iam_role.efs_access.name
}

resource "aws_instance" "minecraft_instance" {
  ami                         = "ami-0840becec4971bb87"
  instance_type               = "t4g.large"
  subnet_id                   = aws_subnet.public_subnets[0].id
  vpc_security_group_ids      = [aws_security_group.minecraft_sg.id]
  associate_public_ip_address = true
  key_name                    = "Macbook Pro"
  iam_instance_profile        = aws_iam_instance_profile.efs_access_profile.id
  tags = {
    Name       = "Minecraft v3"
    Autodeploy = "true"
  }

  user_data = <<-EOF
              #!/bin/bash
              yum install -y amazon-efs-utils nfs-utils
              mkdir -p /mnt/efs
              mount -t efs ${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs
              echo ${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs efs defaults,_netdev 0 0 >> /etc/fstab
              EOF
}

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
