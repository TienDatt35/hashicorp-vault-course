---
title: Đồng bộ secret từ Vault vào Kubernetes với 3 CRD
estMinutes: 25
---

# Đồng bộ secret từ Vault vào Kubernetes với 3 CRD

## Mục tiêu

Sau khi hoàn thành bài thực hành, bạn sẽ biết cách khai báo cả ba loại sync CRD
của Vault Secrets Operator (`VaultStaticSecret`, `VaultDynamicSecret`,
`VaultPKISecret`) và xác minh rằng Kubernetes Secret tương ứng được tạo ra
với dữ liệu đúng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này — Vault dev server đã khởi
  động tại `http://127.0.0.1:8200` với root token `root`.
- Bạn đã hoàn thành bài 02 (Cài đặt VSO): cluster Kind đang chạy, VSO đã được
  cài bằng Helm, namespace `app` đã tồn tại, VaultAuth `static-auth` và
  VaultConnection `default` đã được khai báo.
- Nếu chưa có cluster, bạn cần tạo lại theo hướng dẫn bài 02 trước khi tiếp tục.

## Nhiệm vụ của bạn

### Bước 1 — Chuẩn bị Vault: enable KV v2 engine và ghi secret

Bạn cần enable KV v2 secrets engine tại path `kvv2`, ghi một secret vào
`kvv2/webapp/config`, và tạo hoặc cập nhật Vault policy `webapp` để cho phép
đọc secret đó.

Lưu ý: policy KV v2 bắt buộc có prefix `/data/` trong path, nhưng trong CRD
sau này bạn sẽ dùng path không có `/data/`.

Sau bước này, hãy xác minh rằng bạn có thể đọc secret bằng:

```bash
vault kv get kvv2/webapp/config
```

### Bước 2 — Khai báo VaultStaticSecret và xác minh K8s Secret

Tạo file manifest YAML khai báo `VaultStaticSecret` trong namespace `app` với
các thông tin sau:

- Tên resource: `webapp-static`
- Tham chiếu VaultAuth: `static-auth`
- Mount: `kvv2`, type engine: `kv-v2`
- Path trong mount: `webapp/config`
- Refresh interval: `60s`
- Destination: tạo mới Secret tên `webapp-static-secret`, loại `Opaque`

Apply manifest và chờ một vài giây. Sau đó kiểm tra xem Kubernetes Secret
đã được tạo chưa:

```bash
kubectl get secret webapp-static-secret -n app
```

Bạn cũng nên kiểm tra Secret có chứa dữ liệu (field `data` không rỗng):

```bash
kubectl get secret webapp-static-secret -n app -o jsonpath='{.data}' | base64 -d 2>/dev/null || true
```

> Gợi ý: nếu Secret không được tạo, kiểm tra logs của VSO controller và
> trạng thái của VaultStaticSecret resource bằng `kubectl describe`.

### Bước 3 — Enable database engine, tạo role, khai báo VaultDynamicSecret

Bài này thực hành với database engine ở chế độ demo (không cần PostgreSQL thực).
Bạn cần:

**Phía Vault:**
- Enable database secrets engine tại path `db`
- Tạo Vault policy `vso-dynamic` cho phép đọc `db/creds/my-postgresql-role`

**Phía Kubernetes:**
- Cập nhật Vault policy của VaultAuth `static-auth` (role1) để gồm cả policy mới
- Khai báo `VaultDynamicSecret` trong namespace `app` với:
  - Tên resource: `webapp-dynamic`
  - Tham chiếu VaultAuth: `static-auth`
  - Mount: `db`, path: `creds/my-postgresql-role`
  - `renewalPercent: 67`
  - `revoke: true`
  - Destination: tạo mới Secret tên `dynamic-db-creds`, loại `Opaque`

> Lưu ý: vì không có PostgreSQL thực, bước cấu hình connection và role database
> sẽ được thực hiện nhưng việc sinh credential thực sự sẽ thất bại. Verify script
> chỉ kiểm tra resource CRD và Secret đã được tạo — không kiểm tra nội dung
> credential thực tế.

Sau khi apply, kiểm tra:

```bash
kubectl get secret dynamic-db-creds -n app
```

### Bước 4 — Enable PKI engine, tạo root CA, khai báo VaultPKISecret

**Phía Vault:**
- Enable PKI secrets engine
- Đặt max-lease-ttl cho PKI engine là `8760h`
- Tạo root CA certificate với common_name `example.com`
- Cấu hình issuing_certificates và crl_distribution_points
- Tạo PKI role tên `default` với `allowed_domains=example.com`, `allow_subdomains=true`, `max_ttl=72h`
- Tạo Vault policy `vso-pki` cho phép `create` và `update` trên `pki/issue/default`
- Cập nhật Vault role của VaultAuth để gồm policy mới

**Phía Kubernetes:**
- Khai báo `VaultPKISecret` trong namespace `app` với:
  - Tên resource: `webapp-pki`
  - Tham chiếu VaultAuth: `static-auth`
  - Mount: `pki`, role: `default`
  - `commonName: example.com`
  - `ttl: 72h`
  - `expiryOffset: 5m`
  - `revoke: true`
  - Destination: tạo mới Secret tên `pki-tls-secret`, loại `kubernetes.io/tls`

Sau khi apply, xác minh Secret TLS đã được tạo và có đủ hai key:

```bash
kubectl get secret pki-tls-secret -n app -o jsonpath='{.data}' | python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.keys()))"
```

Bạn phải thấy `tls.crt` và `tls.key` trong kết quả.

> Gợi ý: nếu VaultPKISecret báo lỗi quyền, kiểm tra lại Vault policy `vso-pki`
> và Vault role liên kết với ServiceAccount.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
