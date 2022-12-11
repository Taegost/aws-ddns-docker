#!/bin/bash

# ================ FUNCTIONS ================

function validate_ip() 
{
	[[ $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

function fullstop_on_error()
{
  sv down ddns
  exit 1  
}

function process_update_error()
{
  echo "There was an error updating the DNS record"
  if [ $CURRENT_ATTEMPT -lt $MAX_RETRIES ]
  then
    local RETRIES_LEFT=$(($MAX_RETRIES - $CURRENT_ATTEMPT))
    echo "Will retry $RETRIES_LEFT more times"
    echo "Pausing for $RETRY_DELAY second(s) before trying again"
    sleep "${RETRY_DELAY}s"
    let "CURRENT_ATTEMPT++"
  else
    echo "Maximum number of retries reached, killing service"
    sv down ddns
    exit 1
  fi
} # function process_update_error()

# ================ MAIN ================

if [ -z "$AWS_ACCESS_KEY" ]; then
  echo 'You MUST specify the AWS_ACCESS_KEY'
  fullstop_on_error
fi
if [ -z "$AWS_SECRET" ]; then
  echo 'You MUST specify the AWS_SECRET'
  fullstop_on_error
fi
if [ -z "$AWS_ZONE_ID" ]; then
  echo 'You MUST specify the AWS_ZONE_ID'
  fullstop_on_error
fi
if [ -z "$DOMAIN" ]; then
  echo 'You MUST specify the DOMAIN'
  fullstop_on_error
fi

# Sets defaults
if [ -z "$DNS_TTL" ]; then
  DNS_TTL=300 # 5 minutes
fi
if [ -z "$RECHECK_SECS" ]; then
  RECHECK_SECS=900 # 15 minutes
fi
if [ -z "$MAX_RETRIES" ]; then
  MAX_RETRIES=10
fi
if [ -z "$RETRY_DELAY" ]; then
  RETRY_DELAY=30 # This is in seconds
fi

# Configure AWS
aws configure set aws_access_key_id $AWS_ACCESS_KEY
aws configure set aws_secret_access_key $AWS_SECRET

OLD_IP=""
TS=0
CURRENT_ATTEMPT=1

while true
do
	sleep "${TS}s"
	TS="$RECHECK_SECS" # first run is without a sleep

  for i in $(echo $DOMAIN | tr " " "\n")
  do
    sleep 1s # We need a slight delay in case there are multiple domains
    OLD_IP="$(dig +short "$i")"
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

      {
        aws route53 change-resource-record-sets \
          --hosted-zone-id "$AWS_ZONE_ID" --change-batch "$JSON_CMD"
      } || {
        # We don't want to stop processing in case the error is temporary.
        process_update_error
        continue
      }

      # XXX: No "get-change" is performed.
      # We update at most every 30 seconds.
      # Enough time for the AWS Route 53 changes to propagate.

      CURRENT_ATTEMPT=1
      echo "Done. Request sent to update IP to: $NEW_IP ($i)"
      echo "Please be patient while the DNS records update. This may take quite some time"
      echo "depending on TTL, whether it's a new record, or other situations."
    done
  done # for i in $(echo $DOMAIN | tr " " "\n")
done # while true