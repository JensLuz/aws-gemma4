output "public_ip" {
  description = "Elastic IP of the instance"
  value       = aws_eip.gemma.public_ip
}

output "https_url" {
  description = "Open WebUI HTTPS URL (ready ~5-10 min after apply)"
  value       = "https://${local.public_domain}"
}

output "ssh_command" {
  description = "SSH into the instance"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_eip.gemma.public_ip}"
}

output "tail_bootstrap_log" {
  description = "Watch the bootstrap progress"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ubuntu@${aws_eip.gemma.public_ip} 'sudo tail -f /var/log/gemma-bootstrap.log'"
}

output "estimated_hourly_cost_usd" {
  description = "Rough on-demand cost (EU regions, g5.2xlarge). Spot is ~70% cheaper."
  value       = var.use_spot ? "~$0.36/hr (spot)" : "~$1.21/hr (on-demand)"
}
