# source utility/aws-emulator/env.sh - point the AWS CLI and SDKs at the emulator.
# The keys are Moto's documented dummy values, not real credentials.
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=ap-south-1
export AWS_ENDPOINT_URL=http://localhost:4566
