# vault-lab.hcl — cấu hình giống production nhưng không có TLS
# Sao chép file này ra ~/vault-lab/config.hcl

ui            = true
cluster_addr  = "http://127.0.0.1:8301"
api_addr      = "http://127.0.0.1:8300"
disable_mlock = true

storage "file" {
  path = "/root/vault-lab/data"
}

listener "tcp" {
  address     = "0.0.0.0:8300"
  tls_disable = 1
}
