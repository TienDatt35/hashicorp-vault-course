# raft-cluster.hcl
# Config mẫu cho cluster 3 node — chỉ để đọc hiểu, không chạy trong Codespace.

ui            = true
cluster_addr  = "https://vault-node1:8201"
api_addr      = "https://vault-node1:8200"
disable_mlock = true

storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node1"

  retry_join {
    leader_api_addr = "https://vault-node2:8200"
  }
  retry_join {
    leader_api_addr = "https://vault-node3:8200"
  }
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/etc/vault.d/tls/vault.crt"
  tls_key_file  = "/etc/vault.d/tls/vault.key"
}
