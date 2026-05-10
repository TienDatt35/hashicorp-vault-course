---
title: Cài đặt VSO và khai báo VaultConnection + VaultAuth
estMinutes: 25
---

# Cài đặt VSO và khai báo VaultConnection + VaultAuth

## Mục tiêu

Trong bài thực hành này, bạn sẽ cài đặt Vault Secrets Operator (VSO) lên một Kubernetes cluster cục bộ bằng Helm, xác minh kết quả cài đặt, sau đó khai báo các CRD `VaultConnection` và `VaultAuth` để chuẩn bị cho việc đồng bộ secret từ Vault.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này. Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Devcontainer đã cài sẵn `kubectl`, `helm`, và `kind`. Một Kubernetes cluster cục bộ (Kind) đã được khởi động sẵn trong devcontainer.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/08-vault-secret-operator/02-install-and-config-vso/`.

## Nhiệm vụ của bạn

### Bước 1 — Thêm Helm repo của HashiCorp

Thêm repo `hashicorp` vào Helm và cập nhật danh sách chart. Sau đó tìm kiếm các phiên bản có sẵn của chart `vault-secrets-operator` để xác nhận repo đã được thêm thành công.

### Bước 2 — Cài đặt VSO bằng Helm

Cài đặt VSO với các yêu cầu sau:

- Tên Helm release: `vault-secrets-operator`
- Chart: `hashicorp/vault-secrets-operator`
- Phiên bản: pin cố định `0.10.0`
- Namespace đích: `vault-secrets-operator`
- Tự động tạo namespace nếu chưa tồn tại

### Bước 3 — Xác minh sau cài đặt

Kiểm tra hai điều sau khi cài xong:

- Pod controller trong namespace `vault-secrets-operator` đang ở trạng thái `Running`.
- Đúng 7 CRD thuộc nhóm `secrets.hashicorp.com` đã được đăng ký trên cluster.

### Bước 4 — Tạo namespace cho ứng dụng

Tạo namespace `app` — đây là namespace nơi bạn sẽ khai báo các CRD VSO cho ứng dụng mẫu.

### Bước 5 — Khai báo VaultConnection

Tạo file `vaultconnection.yaml` và áp dụng lên cluster. `VaultConnection` phải thỏa mãn:

- Tên: `default`
- Namespace: `app`
- Địa chỉ Vault: `http://host.minikube.internal:8200` hoặc `http://172.17.0.1:8200` (địa chỉ mà cluster Kind có thể đến được Vault dev server chạy trong Codespace — xem gợi ý bên dưới).

> Gợi ý: Trong môi trường Kind/devcontainer, Vault dev server chạy ở `127.0.0.1:8200` trên máy host. Để Pod trong Kind cluster truy cập được, bạn cần dùng địa chỉ bridge network của host (thường là `172.17.0.1`) hoặc địa chỉ IP của node Kind. Chạy `kubectl get nodes -o wide` để xem IP, hoặc thử `ip route | grep default` để tìm gateway.

### Bước 6 — Khai báo VaultAuth

Tạo file `vaultauth.yaml` và áp dụng lên cluster. `VaultAuth` phải thỏa mãn:

- Tên: `static-auth`
- Namespace: `app`
- Tham chiếu đến `VaultConnection` tên `default`
- Method: `kubernetes`
- Mount: `demo-auth-mount`
- Role: `role1`
- ServiceAccount: `demo-static-app`
- Audiences: `["vault"]`

Bạn cũng cần tạo ServiceAccount `demo-static-app` trong namespace `app` để VaultAuth có thể tham chiếu.

### Bước 7 — Cấu hình phía Vault server

Để VaultAuth hoạt động hoàn chỉnh, bạn cần thực hiện các bước cấu hình trên Vault:

- Enable Kubernetes auth method với path `demo-auth-mount`.
- Cấu hình Kubernetes auth với địa chỉ API server của Kind cluster.
- Tạo policy `webapp` cho phép đọc secret KV v2 tại `kvv2/data/webapp/config`.
- Tạo Vault role `role1` liên kết ServiceAccount `demo-static-app` trong namespace `app` với policy `webapp`.

> Gợi ý: bạn cần biết địa chỉ API server của Kind cluster. Chạy `kubectl cluster-info` để lấy URL của Kubernetes control plane.

> Gợi ý về policy KV v2: đường dẫn trong policy bắt buộc phải có `/data/` ở giữa — ví dụ `kvv2/data/webapp/config`, không phải `kvv2/webapp/config`.

> Hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
