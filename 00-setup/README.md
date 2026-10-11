# 00-setup — account baseline

One-time guardrails for the practice account. **Apply this before your first lab.**
Unlike labs, this is meant to stay up permanently — it costs nothing.

## What it creates

- An AWS Budget of `$monthly_budget_usd` (default $10) on total account spend.
- Email alerts at **50% actual**, **90% actual**, and **100% forecast** — the forecast
  alarm is the one that actually saves you, since it fires before the money is gone.

## Apply

```bash
../scripts/whoami.sh
cd terraform
terraform init
terraform apply -var="alert_email=user@domain.com"
```

AWS sends a confirmation email to that address for the SNS subscription — **click it**,
or the alerts silently go nowhere.

## Also do this once, by hand

These are console-only toggles Terraform can't set on a standalone account:

1. **Billing → Billing preferences** → enable *Receive Free Tier Usage Alerts* and
   *Receive Billing Alerts*.
2. **Billing → Cost Explorer** → enable it (takes ~24h to populate the first time).
3. **IAM → Account settings** → make sure MFA is on `aws-iam-user`. It is an admin user
   with long-lived access keys; that is the one real risk in this setup.
