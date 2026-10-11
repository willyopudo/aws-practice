# Account baseline: a budget that tells you before the bill hurts.
#
# Budgets are a global (us-east-1) service. Free: the first two budgets cost nothing.

resource "aws_budgets_budget" "practice" {
  name         = "aws-practice-monthly"
  budget_type  = "COST"
  limit_amount = var.monthly_budget_usd
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # 50% of actual spend — "heads up, you're using this".
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 50
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 90% of actual — "wrap it up".
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 90
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # 100% FORECAST — fires early in the month if your current burn rate would blow
  # the budget. This is the alert that catches a NAT Gateway you forgot to destroy.
  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }
}
