output "public_instance_ip" {
  value = aws_instance.public.public_ip
}

output "private_instance_private_ip" {
  value = aws_instance.private.private_ip
}

output "key_name" {
  value = aws_key_pair.this.key_name
}

output "private_key_path" {
  value = local_sensitive_file.private_key.filename
}
