# terraform init -backend-config=backend-emulator.hcl
bucket       = "ratnesh-tfstate-s19"
key          = "session-19/terraform.tfstate"
region       = "ap-south-1"
encrypt      = true
use_lockfile = true # S3-native lock: a <key>.tflock object, no DynamoDB table needed

# local AWS emulator only
endpoints = {
  s3 = "http://localhost:4566"
}
use_path_style              = true
skip_credentials_validation = true
skip_requesting_account_id  = true
skip_metadata_api_check     = true
