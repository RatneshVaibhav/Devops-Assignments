output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for az, s in aws_subnet.public : az => s.id }
}

output "private_subnet_ids" {
  value = { for az, s in aws_subnet.private : az => s.id }
}

output "web_security_group_id" {
  value = aws_security_group.web.id
}

output "ami_id" {
  description = "AMI chosen by the data source."
  value       = data.aws_ami.al2023.id
}

output "web_instance_id" {
  value = aws_instance.web.id
}

output "web_public_ip" {
  value = aws_instance.web.public_ip
}

output "web_url" {
  value = "http://${aws_instance.web.public_ip}/"
}

output "assets_bucket" {
  value = aws_s3_bucket.assets.bucket
}
