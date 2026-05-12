---
title: Secret Transformation — đổi tên key và reshape dữ liệu từ Vault
estMinutes: 20
---

# Secret Transformation — đổi tên key và reshape dữ liệu từ Vault

## Mục tiêu

Thực hành cấu hình Secret Transformation trong VSO để đổi tên key và kết hợp nhiều field thành một, giúp K8s Secret phù hợp với convention của ứng dụng mà không thay đổi gì trên Vault.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã làm xong bài 02 (có VaultAuth tên `static-auth` và namespace `app`).
- Bạn đã làm xong bài 03 (có KV v2 engine tại `kvv2` và secret `kvv2/webapp/config` với field `username` và `password`).
- Bạn đã đọc bài lý thuyết về Secret Transformation trong `site/docs/08-vault-secret-operator/04-vso-addition/theory.mdx`.

## Nhiệm vụ của bạn

### Bước 1: Xác minh môi trường từ bài trước

Kiểm tra các tài nguyên từ bài 02 và 03 đã sẵn sàng:
- Secret `kvv2/webapp/config` tồn tại trên Vault với field `username` và `password`.
- Namespace `app` tồn tại trong Kubernetes.
- VaultAuth `static-auth` tồn tại trong namespace `app`.

Nếu thiếu, hãy quay lại bài 02 và 03 để hoàn thành trước.

### Bước 2: Tạo VaultStaticSecret với transformation đổi tên key

Tạo một `VaultStaticSecret` tên `webapp-transform` trong namespace `app` với các yêu cầu sau:
- Trỏ đến secret `kvv2/webapp/config` (đã có từ bài 03).
- Dùng `destination.name: webapp-transformed`.
- Cấu hình transformation để:
  - Đổi tên key `username` thành `APP_USER`.
  - Đổi tên key `password` thành `APP_PASS`.
  - Key gốc `username` và `password` **không** xuất hiện trong K8s Secret kết quả.

### Bước 3: Xác minh K8s Secret có đúng key mới

Kiểm tra K8s Secret `webapp-transformed` trong namespace `app`:
- Phải có key `APP_USER`.
- Phải có key `APP_PASS`.
- Không được có key `username` gốc.
- Không được có key `password` gốc.

Gợi ý: dùng `kubectl get secret` với flag `-o jsonpath` hoặc `kubectl get secret -o yaml` để xem các key.

### Bước 4: Tạo VaultStaticSecret reshape thành DATABASE_URL

Tạo một `VaultStaticSecret` tên `webapp-reshape` trong namespace `app` với các yêu cầu sau:
- Trỏ đến cùng secret `kvv2/webapp/config`.
- Dùng `destination.name: webapp-reshaped`.
- Cấu hình transformation để:
  - Kết hợp `username` và `password` thành một key duy nhất `DATABASE_URL` theo format `postgresql://username:password@db-host:5432/mydb`.
  - Dùng `excludeRaw: true` để K8s Secret chỉ chứa `DATABASE_URL`, không chứa field gốc nào.

### Bước 5 (Conceptual): Xem cấu hình Helm values cho Encrypted Client Cache

Đây là bước tìm hiểu, không cần chạy lệnh. Xem lại phần Encrypted Client Cache trong lý thuyết và trả lời các câu hỏi sau để kiểm tra hiểu biết:
- Cache được lưu ở đâu (K8s Secret hay memory)?
- Engine nào của Vault được dùng để mã hóa?
- Tại sao cần giữ lease sau khi operator restart?

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bí, đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
sh verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
