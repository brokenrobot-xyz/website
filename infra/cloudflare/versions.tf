terraform {
  required_version = "~> 1.15.8"

  # Remote runs are VCS-driven and ignore this block; it is here so the repo
  # states where state lives, and so a local `terraform` cannot quietly start a
  # second state file of its own.
  cloud {
    organization = "brokenrobot-xyz"

    workspaces {
      name = "cloudflare-production"
    }
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.22.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
