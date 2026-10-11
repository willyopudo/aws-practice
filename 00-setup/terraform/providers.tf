terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile

  # Guard: refuse to run against any account other than the practice one.
  # This is the single most important line in the file — it makes it impossible
  # to apply a lab into a One Acre Fund org account by mistake.
  allowed_account_ids = [var.practice_account_id]

  # Every resource that supports tagging gets these automatically.
  # scripts/sweep.sh relies on them to find orphans.
  default_tags {
    tags = {
      Project   = "aws-practice"
      Lab       = "00-setup"
      ManagedBy = "terraform"
    }
  }
}
