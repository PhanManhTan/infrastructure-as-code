output "public_ec2_ip" {
  description = "Public IP of the public EC2 instance"
  value       = module.ec2.public_instance_ip
}

output "private_ec2_private_ip" {
  description = "Private IP of the private EC2 instance"
  value       = module.ec2.private_instance_private_ip
}

output "ssh_to_public" {
  description = "SSH command to connect to the public EC2"
  value       = "ssh -i ${module.ec2.private_key_path} ubuntu@${module.ec2.public_instance_ip}"
}

output "ssh_to_private_via_proxy" {
  description = "SSH proxy command to connect to the private EC2 via public EC2"
  value       = "ssh -i ${module.ec2.private_key_path} -o ProxyCommand='ssh -i ${module.ec2.private_key_path} -W %h:%p ubuntu@${module.ec2.public_instance_ip}' ubuntu@${module.ec2.private_instance_private_ip}"
}
