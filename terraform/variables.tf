variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "cluster_name" {
  type    = string
  default = "chaos-canary-eks"
}

variable "vpc_id" {
  type = string
}

variable "subnets" {
  type = list(string)
}
