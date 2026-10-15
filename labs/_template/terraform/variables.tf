variable "region" {
  description = "AWS region for this lab. Stick to eu-north-1 unless the lab needs otherwise — the Free Plan SCP denies us-east-1."
  type        = string
  default     = "eu-north-1"
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
