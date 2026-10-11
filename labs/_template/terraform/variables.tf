variable "region" {
  description = "AWS region for this lab. Stick to us-east-1 unless the lab needs otherwise — it has the widest service coverage and the lowest prices."
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile. Must resolve to the practice account."
  type        = string
  default     = "default"
}

variable "practice_account_id" {
  description = "The only account this lab is allowed to touch."
  type        = string
  default     = "395931907369"
}
