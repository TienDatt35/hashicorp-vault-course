# Dockerfile cho Vault
FROM hashicorp/vault:latest

# hashicorp/vault kết thúc bằng USER vault (non-root).
# Phải chuyển về root trước khi cài packages, nếu không devcontainer
# features sẽ bị lỗi "Permission denied" khi apk add.
USER root

# Cài đặt các gói cần thiết
RUN apk add --no-cache git jq vim curl openssl

# Set biến môi trường cho dev mode
ENV VAULT_DEV_ROOT_TOKEN_ID=root
ENV VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200

# Expose port 8200 để truy cập Vault từ máy local
EXPOSE 8200
