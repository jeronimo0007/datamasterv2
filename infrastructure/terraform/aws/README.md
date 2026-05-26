# Terraform AWS (branch `aws`)

Provisionamento minimo: bucket S3 para lake Medallion.

```bash
cp terraform.tfvars.example terraform.tfvars
# edite lake_bucket_name (unico globalmente)
terraform init
terraform plan
terraform apply
```

Deploy automatico: merge na branch **`aws`** dispara `.github/workflows/deploy-aws.yml`.

Secrets no GitHub: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (opcional, padrao `sa-east-1`).
