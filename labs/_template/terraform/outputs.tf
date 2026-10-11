output "account_id" {
  description = "Sanity check — should always be the practice account."
  value       = data.aws_caller_identity.current.account_id
}
