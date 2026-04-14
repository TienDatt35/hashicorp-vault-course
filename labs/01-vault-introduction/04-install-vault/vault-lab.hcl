# vault-lab.hcl — config template cho bài thực hành
# Sao chép file này ra ~/vault-lab/config.hcl rồi điều chỉnh path nếu cần.

ui            = true
api_addr      = "http://127.0.0.1:8300"
disable_mlock = true

storage "file" {
  path = "/root/vault-lab/data"
}

listener "tcp" {
  address     = "127.0.0.1:8300"
  tls_disable = 1
}
