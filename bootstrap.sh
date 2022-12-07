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

function validate_ip() 
{
	[[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

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

OLD_IP=""
TS=0

while true
do
	sleep "${TS}s"
	TS="$RECHECK_SECS" # first run is without a sleep

  for i in $(echo $DOMAIN | tr " " "\n")
  do
    OLD_IP="$(dig +short "$i")"
    sleep 5s
    NEW_IP="$(curl -sS --max-time 5 https://api.ipify.org)"

    # Skip validating the old IP, we don't care what it is anyway
    
    if ! validate_ip "$NEW_IP" ; then
      echo "Invalid NEW_IP for $i: $NEW_IP"
      continue
    fi

    if [ "$OLD_IP" == "$NEW_IP" ]; then
      echo "No IP change detected for $i: $OLD_IP"
      continue
    fi

    # UPSERT: http://docs.aws.amazon.com/Route53/latest/APIReference/API_ChangeResourceRecordSets.html

    # http://stackoverflow.com/questions/1167746/how-to-assign-a-heredoc-value-to-a-variable-in-bash
    read -r -d '' JSON_CMD << EOF
      {
        "Comment": "DynDNS update",
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
              "Name": "$i.",
              "Type": "A",
              "TTL": $DNS_TTL,
              "ResourceRecords": [
                {
                  "Value": "$NEW_IP"
                }
              ]
            }
          }
        ]
      }
EOF

      echo "Updating IP for $i to: New=$NEW_IP Old=$OLD_IP"

      aws route53 change-resource-record-sets \
        --hosted-zone-id "$AWS_ZONE_ID" --change-batch "$JSON_CMD"

      # XXX: No "get-change" is performed.
      # We update at most every 30 seconds.
      # Enough time for the AWS Route 53 changes to propagate.

      echo "Done. Request sent to update IP to: $NEW_IP ($i)"
      echo "Please be patient while the DNS records update. This may take quite some time"
      echo "depending on TTL, whether it's a new record, or other situations."
    done
  done # for i in $(echo $DOMAIN | tr " " "\n")
done # while true