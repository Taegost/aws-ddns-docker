#!/usr/bin/env python3
"""
AWS Route 53 Dynamic DNS Updater
Replaces the original bootstrap.sh with a pure-Python implementation.
Dependencies: boto3, requests
"""

import logging
import os
import re
import sys
import time

import boto3
import requests
from botocore.exceptions import BotoCoreError, ClientError

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
logging.basicConfig(
    stream=sys.stdout,
    level=logging.INFO, # defaults to INFO in case there are any init issues
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("aws-ddns")

# ---------------------------------------------------------------------------
# Config – read from environment, with safe defaults
# ---------------------------------------------------------------------------
REQUIRED_VARS = ("AWS_ACCESS_KEY", "AWS_SECRET", "AWS_ZONE_ID", "DOMAIN")

def load_config() -> dict:
    missing = [v for v in REQUIRED_VARS if not os.environ.get(v)]
    if missing:
        for var in missing:
            log.error("You MUST specify the environment variable: %s", var)
        sys.exit(1)

    return {
        "aws_access_key": os.environ["AWS_ACCESS_KEY"],
        "aws_secret":     os.environ["AWS_SECRET"],
        "zone_id":        os.environ["AWS_ZONE_ID"],
        "domains":        os.environ["DOMAIN"].split(),
        "log_level":      os.environ.get("LOG_LEVEL", "INFO").upper(),
        "dns_ttl":        int(os.environ.get("DNS_TTL",      "300")),
        "recheck_secs":   int(os.environ.get("RECHECK_SECS", "900")),
        "max_retries":    int(os.environ.get("MAX_RETRIES",  "10")),
        "retry_delay":    int(os.environ.get("RETRY_DELAY",  "30")),
    }

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_IPV4_RE = re.compile(r"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$")

def is_valid_ipv4(addr: str) -> bool:
    return bool(_IPV4_RE.match(addr or ""))


def get_public_ip(timeout: int = 5) -> str | None:
    """Return the current WAN IP via ipify, or None on failure."""
    try:
        resp = requests.get("https://api.ipify.org", timeout=timeout)
        resp.raise_for_status()
        return resp.text.strip()
    except requests.RequestException as exc:
        log.error("Could not retrieve public IP: %s", exc)
        return None

def fetch_all_a_records(route53: object, zone_id: str) -> dict[str, str]:
    """
    Fetch all A records for the hosted zone in a single paginated request.
    Returns a dict of { "example.com.": "1.2.3.4", ... }
    """
    records = {}
    try:
        paginator = route53.get_paginator("list_resource_record_sets")
        for page in paginator.paginate(HostedZoneId=zone_id):
            for rrs in page.get("ResourceRecordSets", []):
                if rrs["Type"] == "A" and rrs.get("ResourceRecords"):
                    records[rrs["Name"]] = rrs["ResourceRecords"][0]["Value"]
    except (BotoCoreError, ClientError) as exc:
        log.error("Could not fetch A records for zone %s: %s", zone_id, exc)
    return records

def upsert_dns_record(
    route53: object,
    zone_id: str,
    domain: str,
    new_ip: str,
    ttl: int,
) -> bool:
    """Send a Route 53 UPSERT change batch. Returns True on success."""
    fqdn = domain.rstrip(".") + "."
    change_batch = {
        "Comment": "Updated by AWS DDNS updater",
        "Changes": [
            {
                "Action": "UPSERT",
                "ResourceRecordSet": {
                    "Name": fqdn,
                    "Type": "A",
                    "TTL": ttl,
                    "ResourceRecords": [{"Value": new_ip}],
                },
            }
        ],
    }
    try:
        route53.change_resource_record_sets(
            HostedZoneId=zone_id,
            ChangeBatch=change_batch,
        )
        return True
    except (BotoCoreError, ClientError) as exc:
        log.error("Route 53 update failed: %s", exc)
        return False

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------
def main() -> None:
    cfg = load_config()

    # Set requested log level and fallback to INFO if the user entered something invalid
    log_level = getattr(logging, cfg["log_level"], logging.INFO) 
    logging.getLogger().setLevel(log_level)

    route53 = boto3.client(
        "route53",
        aws_access_key_id=cfg["aws_access_key"],
        aws_secret_access_key=cfg["aws_secret"],
        # Route 53 is a global service; region is not required but boto3
        # needs something if no default region is configured in the environment.
        region_name=os.environ.get("AWS_DEFAULT_REGION", "us-east-1"),
    )

    log.info(
        "Starting AWS DDNS updater | domains=%d ttl=%ds recheck=%ds",
        len(cfg["domains"]),
        cfg["dns_ttl"],
        cfg["recheck_secs"],
    )
    log.debug("Full domain list: %s", cfg["domains"])

    first_run = True

    while True:

        # We use the first_run logic rather than a sleep at the end of the loop to keep the code easier to read
        if not first_run:
            log.info("Sleeping %d seconds until next check…", cfg["recheck_secs"])
            time.sleep(cfg["recheck_secs"])
        first_run = False

        # Gets and validates public IP
        public_ip = get_public_ip()
        if not public_ip or not is_valid_ipv4(public_ip):
            log.error("Invalid or missing public IP: %r – skipping", public_ip)
            continue # This will skip the rest of the loop and sleeps until the next check

        dns_cache = fetch_all_a_records(route53, cfg["zone_id"]) # Gets all records from the Hosted Zone
        for domain in cfg["domains"]:
            
            # The AWS dictionary will have trailing dots (.), so we need to normalize the key in case the user has a trailing . or not in the environment variable
            current_ip = dns_cache.get(domain.rstrip(".") + ".")

            if current_ip == public_ip:
                log.info("No IP change detected for %s: %s", domain, current_ip)
                continue

            log.info("IP change detected for %s: old=%s new=%s", domain, current_ip or "<none>", public_ip)

            # Retry loop
            for attempt in range(1, cfg["max_retries"] + 1):
                success = upsert_dns_record(
                    route53, cfg["zone_id"], domain, public_ip, cfg["dns_ttl"]
                )
                if success:
                    log.info(
                        "Successfully requested DNS update for %s → %s "
                        "(DNS propagation may take some time depending on TTL)",
                        domain,
                        public_ip,
                    )
                    break

                retries_left = cfg["max_retries"] - attempt
                if retries_left > 0:
                    log.warning(
                        "Update failed for %s (attempt %d/%d). "
                        "Retrying in %d second(s)…",
                        domain,
                        attempt,
                        cfg["max_retries"],
                        cfg["retry_delay"],
                    )
                    time.sleep(cfg["retry_delay"])
                else:
                    log.error(
                        "Maximum retries (%d) reached for %s. "
                        "Will try again on next recheck cycle.",
                        cfg["max_retries"],
                        domain,
                    )
        
        # Update heartbeat file for Docker healthcheck
        with open("/tmp/heartbeat", "w") as f:
            f.write(str(time.time()))

if __name__ == "__main__":
    main()
