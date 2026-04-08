FROM mcr.microsoft.com/devcontainers/base:ubuntu-22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Vault from the official HashiCorp apt repository, plus common tooling
RUN apt-get update \
 && apt-get install --yes --no-install-recommends \
        curl gpg lsb-release jq vim wget unzip git ca-certificates \
 && wget -O - https://apt.releases.hashicorp.com/gpg \
        | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/hashicorp.list \
 && apt-get update \
 && apt-get install --yes --no-install-recommends vault \
 && rm -rf /var/lib/apt/lists/*

EXPOSE 8200
