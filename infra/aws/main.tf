locals {
  apex_domain_name = "brokenrobot.xyz"

  tags = {
    Application = "brokenrobot.xyz"
    Environment = "production"
  }
}

# ########################################
# Simple Static Website
# ########################################

module "simple_static_website" {
  source = "./modules/simple-static-website"

  apex_domain_name = local.apex_domain_name

  cloudfront_website = {
    acm_certificate_arn                        = data.aws_acm_certificate.website.arn
    aws_cloudfront_function_viewer_request_arn = aws_cloudfront_function.viewer_request.arn
  }

  tags = local.tags
}

data "aws_acm_certificate" "website" {
  domain    = local.apex_domain_name
  statuses  = ["ISSUED"]
  types     = ["AMAZON_ISSUED"]
  key_types = ["RSA_2048"]

  provider = aws.certificate_authority
}

resource "aws_cloudfront_function" "viewer_request" {
  name    = "viewer-request"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file("${path.module}/cloudfront-functions/viewer-request/viewer-request.js")
}

# ########################################
# Route 53 Domains - registration
# ########################################
# The Route 53 Domains API lives in us-east-1 only, hence the aliased
# provider. Terraform adopts the already-registered domain rather than
# registering it; destroying only forgets it. Adoption also enforces the
# resource defaults: auto-renew on, WHOIS privacy on.
#
# Set cloudflare_name_servers (from the zone_name_servers output of
# infra/cloudflare) to delegate DNS to Cloudflare; while it is empty the
# registration keeps its current nameservers and stays out of Terraform.

resource "aws_route53domains_registered_domain" "website" {
  count = length(var.cloudflare_name_servers) > 0 ? 1 : 0

  domain_name   = local.apex_domain_name
  transfer_lock = var.domain_transfer_lock

  dynamic "name_server" {
    for_each = var.cloudflare_name_servers

    content {
      name = name_server.value
    }
  }

  tags = local.tags

  provider = aws.domain_registrar
}

# ########################################
# SNS - alarms
# ########################################

resource "aws_sns_topic" "website_alarms_topic" {
  name         = "brokenrobot-xyz-alarms-topic"
  display_name = "Alarm Notifications for brokenrobot.xyz"

  tags = local.tags
}

resource "aws_sns_topic_subscription" "website_alarms_subscription" {
  for_each  = toset(var.website_alarms_endpoints)
  topic_arn = aws_sns_topic.website_alarms_topic.arn
  protocol  = "email"
  endpoint  = each.value
}

data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish"
    ]

    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      aws_sns_topic.website_alarms_topic.arn
    ]

    sid = "__default_statement_ID"
  }
}

# ########################################
# CloudWatch - metrics
# ########################################

resource "aws_cloudwatch_metric_alarm" "website_1k_requests_alarm" {
  alarm_name        = "brokenrobot.xyz - 1k request alarm"
  alarm_description = "Checks for if the number of requests to CloudFront crossed the 1k threshold"

  metric_name         = "Requests"
  comparison_operator = "GreaterThanThreshold"
  period              = "300"
  statistic           = "Average"
  threshold           = "1000"
  evaluation_periods  = "1"
  namespace           = "AWS/CloudFront"
  treat_missing_data  = "missing"

  actions_enabled = true
  alarm_actions = [
    aws_sns_topic.website_alarms_topic.arn
  ]

  dimensions = {
    DistributionId = module.simple_static_website.cloudfront_website.arn
    Region         = "Global"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "website_5k_requests_alarm" {
  alarm_name        = "brokenrobot.xyz - 5k request alarm"
  alarm_description = "Checks for if the number of requests to CloudFront crossed the 5k threshold"

  metric_name         = "Requests"
  comparison_operator = "GreaterThanThreshold"
  period              = "300"
  statistic           = "Average"
  threshold           = "5000"
  evaluation_periods  = "1"
  namespace           = "AWS/CloudFront"
  treat_missing_data  = "missing"

  actions_enabled = true
  alarm_actions = [
    aws_sns_topic.website_alarms_topic.arn
  ]

  dimensions = {
    DistributionId = module.simple_static_website.cloudfront_website.arn
    Region         = "Global"
  }

  tags = local.tags
}

resource "aws_cloudwatch_metric_alarm" "website_10k_requests_alarm" {
  alarm_name        = "brokenrobot.xyz - 10k request alarm"
  alarm_description = "Checks for if the number of requests to CloudFront crossed the 10k threshold"

  metric_name         = "Requests"
  comparison_operator = "GreaterThanThreshold"
  period              = "300"
  statistic           = "Average"
  threshold           = "10000"
  evaluation_periods  = "1"
  namespace           = "AWS/CloudFront"
  treat_missing_data  = "missing"

  actions_enabled = true
  alarm_actions = [
    aws_sns_topic.website_alarms_topic.arn
  ]

  dimensions = {
    DistributionId = module.simple_static_website.cloudfront_website.arn
    Region         = "Global"
  }

  tags = local.tags
}
