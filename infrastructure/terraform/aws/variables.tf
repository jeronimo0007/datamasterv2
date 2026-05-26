variable "aws_region" {
  description = "Regiao AWS"
  type        = string
  default     = "sa-east-1"
}

variable "environment" {
  description = "Ambiente (dev, prod)"
  type        = string
  default     = "dev"
}

variable "lake_bucket_name" {
  description = "Nome global unico do bucket S3 (lake Medallion)"
  type        = string
}
