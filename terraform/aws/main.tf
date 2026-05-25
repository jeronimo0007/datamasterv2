# main.tf - AWS Equivalent
provider "aws" {
  region = var.aws_region
}

# Amazon S3 (Equivalente Azure: Data Lake Gen2)
resource "aws_s3_bucket" "data_lake" {
  bucket = "fraud-detection-data-${var.environment}"
  
  tags = {
    Environment = var.environment
    Application = "FraudDetection"
  }
}

resource "aws_s3_bucket_versioning" "data_lake" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Amazon Kinesis (Equivalente Azure: Event Hubs)
resource "aws_kinesis_stream" "transactions" {
  name             = "fraud-transactions-${var.environment}"
  shard_count      = 2
  retention_period = 24
  
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded"
  ]
  
  tags = {
    Environment = var.environment
  }
}

# AWS EMR (Equivalente Azure: Databricks)
resource "aws_emr_cluster" "spark_cluster" {
  name          = "fraud-spark-${var.environment}"
  release_label = "emr-6.9.0"
  applications  = ["Spark", "Hadoop"]
  
  ec2_attributes {
    subnet_id                         = aws_subnet.main.id
    emr_managed_master_security_group = aws_security_group.emr_master.id
    emr_managed_slave_security_group  = aws_security_group.emr_slave.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
  }
  
  master_instance_group {
    instance_type = "m5.xlarge"
  }
  
  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 2
  }
  
  tags = {
    Environment = var.environment
  }
}

# Amazon Redshift (Equivalente Azure: Synapse Analytics)
resource "aws_redshift_cluster" "data_warehouse" {
  cluster_identifier = "fraud-dw-${var.environment}"
  database_name      = "fraud_detection"
  master_username    = "admin"
  master_password    = random_password.redshift_password.result
  node_type          = "ra3.xlplus"
  cluster_type       = "single-node"
  
  tags = {
    Environment = var.environment
  }
}

# Amazon DynamoDB (Equivalente Azure: Cosmos DB)
resource "aws_dynamodb_table" "transactions" {
  name           = "fraud-transactions-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "transaction_id"
  range_key      = "timestamp"
  
  attribute {
    name = "transaction_id"
    type = "S"
  }
  
  attribute {
    name = "timestamp"
    type = "N"
  }
  
  tags = {
    Environment = var.environment
  }
}

# Amazon SageMaker (Equivalente Azure: Machine Learning)
resource "aws_sagemaker_domain" "ml_domain" {
  domain_name = "fraud-ml-${var.environment}"
  auth_mode   = "IAM"
  vpc_id      = aws_vpc.main.id
  subnet_ids  = [aws_subnet.main.id]
  
  default_user_settings {
    execution_role = aws_iam_role.sagemaker_execution.arn
  }
  
  tags = {
    Environment = var.environment
  }
}