

# Summary
The [AWS DDNS for Docker](https://hub.docker.com/repository/docker/taegost/aws-ddns) project is a container that performs a simple task: Whenever your external (WAN) IP address changes, update one or more DNS records in Amazon Route 53.

# Description
This project is aimed at anybody who self-hosts services without a static IP and uses Route 53 for their domain DNS. Whether you use it to connect to your home VPN, host game servers, or have a small home business, this is a quick, free, and easy alternative to services such as DynDNS.

By using this container you'll have your own self-hosted dynamic DNS updater up and running in a matter of minutes!

If you are hosting multiple domains (or sub-domains), you can enter them all, leaving a space between each \
**Example**: `shop.example.com mail.mycustomdomain.com vpn.familynamehere.com`

---

# Pre-Requisites
- Get the [Zone ID]((http://docs.aws.amazon.com/Route53/latest/DeveloperGuide/UsingWithIAM.html)) for the hosted domain from the Route 53 Hosted Zones console
- Create a new user. **Make sure you record the Access Key ID and Access Key Secret**
- Edit the new user and click ```Inline Policies``` 
- Use the Visual Editor:
  - **Service**: Amazon Route 53
  - **Actions**: Add `ChangeResourceRecordSets` and `
  - **Effect**: Allow
  - **Resources**: Under `HostedZone`, click `Add ARN`. In the `ID` field, enter the Zone ID you got earlier 
    - Example: ```arn:aws:route53:::hostedzone/Z148QEXAMPLE8V```
- Click Review Policy
- Give the policy a descriptive name
- Click `Create Policy`

Here is a JSON version ready to drop-in, all you have to do is change the Resource ARN

```json
{
	"Version": "2012-10-17",
	"Statement": [
		{
			"Sid": "VisualEditor0",
			"Effect": "Allow",
			"Action": [
				"route53:ChangeResourceRecordSets",
				"route53:ListResourceRecordSets"
			],
			"Resource": "arn:aws:route53:::hostedzone/Z148QEXAMPLE8V"
		}
	]
}
```

---

# Environment Variables
**All variable names and values are case-sensitive!**

Any variable with a blank default is **REQUIRED**, the container will not start properly without them being defined.

| Name             | Default | Description                                                                |
| ---------------- | ------- | -------------------------------------------------------------------------- |
| `AWS_ACCESS_KEY` |         | Access key from AWS                                                        |
| `AWS_SECRET`     |         | Secret key from AWS                                                        |
| `AWS_ZONE_ID`    |         | Unique zone ID from Route 53 for the hosted domain                         |
| `DOMAIN`         |         | Space-separated list of domains to keep updated                            |
| `LOG_LEVEL`      | `INFO`  | Console logging level. Values are: DEBUG, INFO, WARNING, ERROR, CRITICAL   |
| `DNS_TTL`        | `300`   | TTL value for the DNS record, in seconds                                   |
| `RECHECK_SECS`   | `900`   | Number of seconds between checking for IP address updates                  |
| `MAX_RETRIES`    | `10`    | Maximum number of times to retry the DNS update if an error is encountered |
| `RETRY_DELAY`    | `30`    | Number of seconds before retrying a failed DNS update                      |

---

# Docker Configuration
The container doesn't require any volumes or special setup besides the proper values in the environment variables. It **MUST** be able to connect to the internet.

## Using Docker Run
```
$ docker run -d \
    --name aws-ddns \
    -e AWS_ACCESS_KEY="AK6fakekey4EE" \
    -e AWS_SECRET="SuperDuperSecret" \
    -e AWS_ZONE_ID="Z0000fakezone000" \
    -e DOMAIN="example.com" \
    taegost/aws-ddns
```

If you're updating multiple domains, change the DOMAIN line to something like:
```
-e DOMAIN="shop.example.com mail.mycustomdomain.com vpn.familynamehere.com" \
```

## Using Docker Compose
*The latest version of the sample docker-compose.yml will always be found in the root of the repo.*

```
services: 
  aws-ddns: 
    image: taegost/aws-ddns:latest
    restart: unless-stopped
    environment:
      AWS_ACCESS_KEY: AK6fakekey4EE
      AWS_SECRET: SuperDuperSecret
      AWS_ZONE_ID: Z0000fakezone000
      DOMAIN: example.com
      DNS_TTL: 300
      RECHECK_SECS: 900
```
If you're updating multiple domains, put a space between each entry in the DOMAIN variable, like:
```
DOMAIN: shop.example.com mail.mycustomdomain.com vpn.familynamehere.com
```

## Image Tags

Images are published to Docker Hub at `taegost/aws-ddns`.

| Tag | When it's updated | Recommended use |
|---|---|---|
| `latest` | Every push to `main` and weekly scheduled rebuild | Day-to-day use, always current |
| `sha-<commit>` | Every build | Tracing a specific build back to a commit |
| `1.2.3` | When a `v1.2.3` Git tag is pushed | Pinning to a known stable version |
| `1.2` | When any `v1.2.x` Git tag is pushed | Pinning to a minor version |
| `1` | When any `v1.x.x` Git tag is pushed | Loose pinning to a major version |

### Why No Date or "Weekly" Tag?

A `weekly` tag would be a moving pointer, semantically identical to `latest`.
It would add noise to Docker Hub without adding meaning — anyone pinning to
`weekly` gets the same behavior as pinning to `latest`. The tags above cover
all real use cases:

- **Staying current**: use `latest`
- **Stability**: pin to a semver tag (`1.2.3`)
- **Traceability**: use the `sha-<commit>` tag to trace any image back to its
  exact source commit

The weekly scheduled pipeline rebuild ensures `latest` always incorporates
the most recent base image security patches, even without a code change.

---