---
title: Đáp án mẫu — Quản lý Vault Token bằng CLI
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `sh verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài lab này thực hành vòng đời đầy đủ của một Vault token. Chúng ta dùng root token (đã có sẵn trong dev server) để tạo policy, sau đó tạo token thường với policy đó. Token thường bị giới hạn quyền theo policy — đây là nguyên tắc least privilege. Lệnh `capabilities` cho phép kiểm tra nhanh xem token có quyền cụ thể nào trên path nào mà không cần đọc policy từng dòng.

## Các lệnh

```bash
# Bước 1 — Tạo policy lab-policy
# Viết nội dung policy ra file tạm
cat > /tmp/lab-policy.hcl << 'EOF'
path "secret/data/lab/*" {
  capabilities = ["read", "list"]
}
EOF

# Nạp policy vào Vault
vault policy write lab-policy /tmp/lab-policy.hcl

# Bước 2 — Tạo token với policy và TTL
# Lưu token vào biến môi trường LAB_TOKEN
LAB_TOKEN=$(vault token create \
  -policy=lab-policy \
  -ttl=30m \
  -explicit-max-ttl=2h \
  -display-name=lab-token \
  -format=json \
  | jq -r '.auth.client_token')

echo "Token vừa tạo: $LAB_TOKEN"

# Bước 3 — Tra cứu metadata của token
vault token lookup "$LAB_TOKEN"
# Quan sát: ttl, policies, explicit_max_ttl, display_name

# Bước 4 — Kiểm tra quyền trên các path
# Path được phép — phải thấy [read list] hoặc tương tự có "read"
vault token capabilities "$LAB_TOKEN" secret/data/lab/test

# Path không được phép — phải thấy [deny]
vault token capabilities "$LAB_TOKEN" secret/data/other

# Bước 5 — Gia hạn token với increment 15 phút
vault token renew -increment=15m "$LAB_TOKEN"

# Lookup lại để xác nhận TTL đã được cập nhật
vault token lookup "$LAB_TOKEN"

# Bước 6 — Thu hồi token và xác nhận
vault token revoke "$LAB_TOKEN"

# Thử lookup token đã bị revoke — sẽ trả về lỗi
# vault token lookup "$LAB_TOKEN"
# Output: Error looking up token: Error making API request. ... Code: 403
```

## Giải thích chi tiết từng bước

**Bước 1:** Policy dùng glob `*` để áp dụng cho tất cả path bắt đầu bằng `secret/data/lab/`. Capabilities `read` và `list` tối thiểu để đọc và duyệt secret.

**Bước 2:** Flag `-format=json` kết hợp với `jq` cho phép lấy chính xác token string từ output. Nếu không dùng `-format=json`, bạn có thể copy token từ dòng `token` trong bảng output.

**Bước 3:** Hai field quan trọng cần chú ý: `ttl` cho biết số giây còn lại, `explicit_max_ttl` cho biết trần cứng. Nếu `explicit_max_ttl = 0`, token không có trần cứng.

**Bước 4:** `capabilities` trả về danh sách capabilities dạng `[create delete list read update]` hoặc `[deny]`. Chú ý rằng `lab-policy` chỉ cấp `read` và `list` cho `secret/data/lab/*`, nên `secret/data/other` (không khớp path) sẽ trả về `[deny]`.

**Bước 5:** `-increment=15m` yêu cầu TTL mới là 15 phút từ thời điểm hiện tại. Kết quả thực tế bị giới hạn bởi `explicit-max-ttl=2h` tính từ lúc tạo token.

**Bước 6:** Sau khi revoke, mọi thao tác với token đó (lookup, renew, dùng để gọi API) đều trả về lỗi 403. Đây là xác nhận token đã bị vô hiệu hóa hoàn toàn.

## Kiểm tra lại

```bash
sh verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
