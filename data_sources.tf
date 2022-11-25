data "aws_availability_zones" "available" {
  # description = "Checking availability zones in a region. We need AmazonEC2readOnlyAccess IAM policy to perform the action"
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}
