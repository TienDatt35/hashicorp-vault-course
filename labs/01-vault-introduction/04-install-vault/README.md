---
title: Khám phá Vault Dev Server trong Codespace
estMinutes: 20
---

# Khám phá Vault Dev Server trong Codespace

## Mục tiêu

Xác nhận trực tiếp các đặc điểm của Vault Dev Server đang chạy trong Codespace — không cần cài đặt thêm gì, chỉ quan sát và tương tác với server đã sẵn sàng.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Biến môi trường `VAULT_ADDR=http://127.0.0.1:8200` và `VAULT_TOKEN=root` đã được set sẵn trong terminal.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/01-vault-introduction/04-install-vault/theory.mdx`.

## Nhiệm vụ của bạn

1. **Kiểm tra trạng thái Vault.** Chạy `vault status` và đọc kỹ output. Xác nhận ba thông tin: `Initialized` là `true`, `Sealed` là `false`, và `Storage Type` là `inmem`. Đây là bằng chứng trực tiếp rằng Dev Server đã tự động init, tự động unseal, và đang dùng in-memory storage.

2. **Ghi lại phiên bản Vault.** Chạy `vault version` và ghi lại version đang dùng trong Codespace.

3. **Xem danh sách secrets engines đã mount.** Chạy `vault secrets list`. Tìm engine tên `secret/` trong danh sách và xác nhận đây là KV version 2 — đây là engine mà Dev Server mount sẵn cho bạn. Lưu ý cột `Type` hiển thị `kv`.

4. **Ghi và đọc một secret.** Thực hiện hai thao tác theo thứ tự:
   - Ghi secret: `vault kv put secret/hello foo=bar`
   - Đọc lại: `vault kv get secret/hello`
   
   Xác nhận rằng giá trị `foo` bạn đọc ra khớp với `bar` bạn đã ghi vào.

5. **Đọc hiểu config file HCL production mẫu.** Mở file `vault-production.hcl` trong thư mục lab này và trả lời ba câu hỏi sau (chỉ để tự kiểm tra — không cần nộp):
   - Block nào quy định nơi lưu trữ dữ liệu (storage)?
   - Block nào quy định TLS certificate?
   - Giá trị của `api_addr` là gì?

6. **Chạy `bash verify.sh`** để xác nhận tất cả các bước trên đều hoàn tất.

> Gợi ý: hãy tự thực hành các bước 1-5 trước khi chạy `verify.sh`. Nếu bí ở bước nào, hãy đối chiếu với `solution.md`.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
