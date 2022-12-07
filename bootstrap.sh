#!/bin/bash

if [ -z "$AWS_ACCESS_KEY" ]; then
  echo 'You MUST specify the AWS_ACCESS_KEY'
  exit 1
fi
if [ -z "$AWS_SECRET" ]; then
  echo 'You MUST specify the AWS_SECRET'
  exit 1
fi
if [ -z "$AWS_ZONE_ID" ]; then
  echo 'You MUST specify the AWS_ZONE_ID'
  exit 1
fi
if [ -z "$DOMAIN" ]; then
  echo 'You MUST specify the DOMAIN'
  exit 1
fi

# Sets defaults
if [ -z "$DNS_TTL" ]; then
  DNS_TTL=300 # 5 minutes
fi
if [ -z "$RECHECK_SECS" ]; then
  RECHECK_SECS=900 # 15 minutes
fi

# Configure AWS
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET

cd /app/aws-dyndns

# We are hanging up on the first domain here because it's waiting for the script to finish,
# which is never does.
for i in $(echo $DOMAIN | tr " " "\n")
do
  ./aws-dyndns $i $DNS_TTL $AWS_ZONE_ID $RECHECK_SECS
done

