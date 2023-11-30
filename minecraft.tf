
resource "aws_route53_zone" "minecraft_zone" {
  name = var.domain
}

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

resource "aws_iam_role" "minecraft_instance_role" {
  name = "minecraft_instance_role"

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

resource "aws_iam_policy" "scale_down_policy" {
  name        = "minecraft_scale_down_policy"
  description = "A policy to scale down the autoscaling group"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
        ],
        Effect   = "Allow",
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "scale_down_policy_attachment" {
  role       = aws_iam_role.minecraft_instance_role.name
  policy_arn = aws_iam_policy.scale_down_policy.arn
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "minecraft_instance_profile"
  role = aws_iam_role.minecraft_instance_role.name
}

resource "aws_launch_template" "minecraft_launch_template" {
  name_prefix   = "minecraft-lt-"
  image_id      = "ami-03a1107d67ec0a28f"
  instance_type = "t4g.large"
  key_name      = "Macbook Pro"

  # Add the following if you want to use spot instances.
  # Careful, it's a cutthroat market out there!
  # instance_market_options {
  #   market_type = "spot"
  # }

  iam_instance_profile {
    name = aws_iam_instance_profile.instance_profile.name
  }

  network_interfaces {
    subnet_id                   = aws_subnet.public_subnets[0].id
    associate_public_ip_address = true
    security_groups             = [aws_security_group.minecraft_sg.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name       = "Minecraft v4"
      Autodeploy = "true"
    }
  }

  user_data = base64encode(<<EOF
#!/bin/bash
apt-get update -y
apt-get install -y nfs-common
mkdir -p /mnt/efs
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs
echo '${aws_efs_file_system.minecraft_efs.id}.efs.${var.aws_region}.amazonaws.com:/ /mnt/efs nfs4 defaults,_netdev 0 0' >> /etc/fstab
EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "minecraft_asg" {
  name                = "Minecraft ASG"
  desired_capacity    = 0
  max_size            = 1
  min_size            = 0
  vpc_zone_identifier = [aws_subnet.public_subnets[0].id]

  launch_template {
    id      = aws_launch_template.minecraft_launch_template.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "MinecraftServerASG"
    propagate_at_launch = true
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300
}

### EFS ###
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
