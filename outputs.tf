output "instance_public_ip" {
  description = "Public IP of Lightsail instance"
  value       = aws_lightsail_instance.test.*.public_ip_address
}

