variable "region" {
  description = "AWS region to deploy in"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use (leave null to use env/default credentials)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "GPU instance type. g5.2xlarge gives 32GB RAM (vs 16GB on g5.xlarge), which avoids page-cache thrashing during the 17GB model verify."
  type        = string
  default     = "g5.2xlarge"
}

variable "use_spot" {
  description = "Use spot instance for ~70% cost savings"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Root volume size in GB (model weights ~18GB)"
  type        = number
  default     = 100
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH (use your public IP/32)"
  type        = string
}

variable "model_name" {
  description = "Ollama model to pull"
  type        = string
  default     = "gemma4:26b"
}

variable "webui_title" {
  description = "Custom name shown in Open WebUI header"
  type        = string
  default     = "Gemma 4 Demo"
}

variable "admin_email" {
  description = "Email used for Let's Encrypt registration"
  type        = string
}

variable "project_name" {
  description = "Tag prefix for all resources"
  type        = string
  default     = "gemma-demo"
}
