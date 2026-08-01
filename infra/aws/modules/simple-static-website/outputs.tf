output "cloudfront_website" {
  value = {
    arn = module.cloudfront_website.arn
  }
}
