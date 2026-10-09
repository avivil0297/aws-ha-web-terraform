resource "aws_key_pair" "bastion" {
  key_name   = "final-lab-bastion"
  public_key = file(pathexpand(var.bastion_public_key_path))
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  key_name                    = aws_key_pair.bastion.key_name
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  associate_public_ip_address = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    hostnamectl set-hostname final-lab-bastion
  EOF

  tags = {
    Name = "final-lab-bastion"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}


resource "aws_launch_template" "web" {
  name                   = "final-lab-web-lt"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.web.id]
  update_default_version = true

  iam_instance_profile {
    name = aws_iam_instance_profile.web.name
  }

  metadata_options {
    http_tokens = "required"
  }

  block_device_mappings {
    device_name = data.aws_ami.ubuntu.root_device_name

    ebs {
      volume_type = "gp3"
      encrypted   = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/web_user_data.sh.tftpl", {
    project_name = var.project_name
    bucket_name  = aws_s3_bucket.site.bucket

  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "final-lab-web"
    }
  }
}


resource "aws_autoscaling_group" "web" {
  name                      = "final-lab-web-asg"
  min_size                  = 1
  max_size                  = 4
  desired_capacity          = 2
  vpc_zone_identifier       = aws_subnet.private[*].id
  target_group_arns         = [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }

  depends_on = [aws_route_table_association.private]
}

resource "aws_autoscaling_policy" "cpu_target" {
  name                   = "final-lab-cpu-30"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 30
  }
}

