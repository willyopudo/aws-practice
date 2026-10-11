output "budget_name" {
  value = aws_budgets_budget.practice.name
}

output "monthly_limit_usd" {
  value = "${var.monthly_budget_usd} USD"
}

output "next_step" {
  value = "Confirm the budget alert email sent to ${var.alert_email}, then enable Free Tier alerts + Cost Explorer in the console (see ../README.md)."
}
