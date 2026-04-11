# vault-production.hcl
# Đây là file config tham khảo — không chạy được trong Codespace vì thiếu TLS cert.
# Mục đích: hiểu cấu trúc config file production.

ui            = true
cluster_addr  = "https://vault.example.com:8201"
api_addr      = "https://vault.example.com:8200"
disable_mlock = true

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "node-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
}
