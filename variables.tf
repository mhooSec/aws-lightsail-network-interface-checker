variable "tf_resource_name" {
  description = "Hardcoded value of the Terraform resource value, for the state rm step"
  type = string
  default = "aws_lightsail_instance.test"
}

variable "availability_zone" {
  description = "The availability zone where we would like to deploy our instances"
  type        = list(any)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "region" {
  description = "The region where we would like to use"
  type        = string
  default     = "us-east-2"
}

variable "blueprint_id" {
  description = "The operating system or template to be used in the instance"
  type        = string
  default     = "freebsd_12"
}

variable "bundle_id" {
  description = "The Lightsail bundle which has an associated set of resources at a fixed price"
  type        = string
  default     = "nano_2_0"
}

variable "tags" {
  description = "Tags to add to the instance"
  type        = string
  default     = "key=instance_type,value=checker"
}

variable "instance_name" {
  description = "The name that the instance will have"
  type        = string
  default     = "checker"
}

variable "vm_count" {
  description = "Number of instances to deploy"
  default     = 2
  type        = string
}

variable "SSHKEY_PATH" {
  description = "Path where the SSH key is stored. Imported from environment variable."
  type = string
}

variable "SSHKEY_FILE" {
  description = "Name of the file containing the SSH private key to interact with the deployed resources. Imported from environment variable."
  type = string
}

variable "REMOTE_USER" {
  description = "SSH user we would like to use in order to perform the SSH connection. Imported from environment variable"
  type = string
}

variable "aws_profile" {
  description = "AWS profile we want to use, in order to identify relevant credentials"
  default = "alex"
  type = string
}
