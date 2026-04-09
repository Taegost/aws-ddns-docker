# Contributing to aws-ddns-docker

Thanks for your interest in contributing! This is a small, focused project
and contributions are welcome — whether that's a bug fix, a new feature, or
improved documentation.

## Getting Started

1. Fork the repository and clone your fork locally.
2. Create a feature branch from `main`: `git checkout -b feature/your-description`
3. Make your changes, test them locally (see below), then open a pull request
   against `main`.

## Local Development
**Requirements:** Docker, an AWS Account with a Route 53 Hosted Zone
### Without Docker
**Additional Requirements:** Python 3.12+

```bash
# Install dependencies
pip install -r requirements.txt

# Run locally (without Docker)
export AWS_ACCESS_KEY="your-key"
export AWS_SECRET="your-secret"
export AWS_ZONE_ID="your-zone-id"
export DOMAIN="example.com"
export LOG_LEVEL="DEBUG"
python ddns.py
```
### With Docker
To build and test the container locally:

```bash
docker build -t local/aws-ddns .
docker run --rm \
  -e AWS_ACCESS_KEY="your-key" \
  -e AWS_SECRET="your-secret" \
  -e AWS_ZONE_ID="your-zone-id" \
  -e DOMAIN="example.com" \
  -e LOG_LEVEL="DEBUG" \
  local/aws-ddns-local
```

## Guidelines

- Keep the scope focused — this project does one thing and should continue to
  do it well. Features that significantly expand scope may be better as a fork.
- Match the existing code style (PEP 8, descriptive variable names, log
  statements at appropriate levels).
- If you're adding a new environment variable, update both `ddns.py` and the
  environment variable table in `README.MD`.
- Don't commit real AWS credentials, zone IDs, or domain names — use the
  placeholder values already shown in the README examples.

## Reporting Issues

Please use the issue templates provided. Bug reports that include log output
(with `LOG_LEVEL=DEBUG`) are significantly easier to diagnose.

## Pull Request Checklist

- [ ] Tested locally with a real Route 53 hosted zone
- [ ] Docker build completes successfully
- [ ] README updated if behavior or configuration changed
- [ ] No credentials or personal AWS data committed
- [ ] Branch is up to date with `main`