#!/bin/bash

if [ ! -f "$AWS_ACCESS_KEY" ]; then
  echo 'You MUST specify the AWS_ACCESS_KEY'
  exit 1
fi
if [ ! -f "$AWS_SECRET" ]; then
  echo 'You MUST specify the AWS_SECRET'
  exit 1
fi
if [ ! -f "$AWS_ZONE_ID" ]; then
  echo 'You MUST specify the AWS_ZONE_ID'
  exit 1
fi
if [ ! -f "$DOMAIN" ]; then
  echo 'You MUST specify the DOMAIN'
  exit 1
fi

# Sets defaults
if [ ! -f "$DNS_TTL" ]; then
  DNS_TTL=300 # 5 minutes
fi
if [ ! -f "$RECHECK_SECS" ]; then
  RECHECK_SECS=900 # 15 minutes
fi

# Configure AWS
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET

cd /app/aws-dyndns

for i in $(echo $DOMAIN | tr " " "\n")
do
  ./aws-dyndns $i $DNS_TTL $AWS_ZONE_ID $RECHECK_SECS
done