# Dockerfile cho Vault
# Dùng base image devcontainer-compatible (chạy root) thay vì hashicorp/vault
# (hashicorp/vault chạy non-root nên devcontainer features bị lỗi permission)
FROM mcr.microsoft.com/devcontainers/base:alpine

# Cài đặt các gói cần thiết
RUN apk add --no-cache git jq vim curl openssl unzip libcap

# Cài đặt Vault binary từ HashiCorp releases
RUN VAULT_VERSION=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/vault/latest | jq -r .version) \
    && curl -fsSL "https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip" -o /tmp/vault.zip \
    && unzip /tmp/vault.zip -d /usr/local/bin \
    && rm /tmp/vault.zip \
    && chmod +x /usr/local/bin/vault \
    && setcap cap_ipc_lock=+ep /usr/local/bin/vault

# Set biến môi trường cho dev mode
ENV VAULT_DEV_ROOT_TOKEN_ID=root
ENV VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200

# Expose port 8200 để truy cập Vault từ máy local
EXPOSE 8200
