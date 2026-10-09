output "whoami" {
  value = data.aws_caller_identity.me.arn
}
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "nat_public_ips" {
  value = aws_eip.nat[*].public_ip
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_ssh_command" {
  value = "ssh -i ~/.ssh/final-lab-bastion ubuntu@${aws_instance.bastion.public_ip}"
}

output "alb_dns_name" {
  value = aws_lb.web.dns_name
}

output "site_bucket" {
  value = aws_s3_bucket.site.bucket
}
