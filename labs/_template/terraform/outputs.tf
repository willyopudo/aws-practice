output "account_id" {
  description = "Sanity check — should always be the practice account."
  value       = data.aws_caller_identity.current.account_id
}

output "region" {
  description = "Sanity check — should be eu-north-1 unless the lab says otherwise."
  value       = data.aws_region.current.region
}
