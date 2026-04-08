# Dockerfile
FROM hashicorp/vault:latest

# Install git and other tooling
RUN apk add --no-cache git jq logrotate openssl

# Set environment variables for dev mode
ENV VAULT_DEV_ROOT_TOKEN_ID=root
ENV VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200

# Expose the default Vault port
EXPOSE 8200
