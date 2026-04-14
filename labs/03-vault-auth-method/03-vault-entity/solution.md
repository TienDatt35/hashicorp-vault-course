---
title: Đáp án mẫu — Hợp nhất identity với Vault Entities và Aliases
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Bài lab này minh hoạ vấn đề identity phân tán: khi người dùng đăng nhập qua nhiều auth methods, Vault tự động tạo nhiều entities riêng biệt và không tự gộp chúng lại. Giải pháp là tạo một entity chung thủ công, gắn tất cả aliases vào entity đó, rồi gán policy nền lên entity. Nhờ cơ chế union (token capabilities = alias policies + entity policies), bất kỳ alias nào đăng nhập cũng đều kế thừa policy của entity.

Điểm mấu chốt cần nhớ: `mount_accessor` là định danh bất biến của một auth mount — khác với mount path vốn có thể thay đổi. Accessor là cách Vault liên kết alias với đúng auth backend.

## Các lệnh

```bash
# ============================================================
# Phần 1: Thiết lập môi trường
# ============================================================

# Bước 1 — Tạo ba policies

# Policy test: đọc secret/data/test
vault policy write test - <<EOF
path "secret/data/test" {
  capabilities = ["read"]
}
EOF

# Policy team-qa: đọc secret/data/qa
vault policy write team-qa - <<EOF
path "secret/data/qa" {
  capabilities = ["read"]
}
EOF

# Policy base: đọc secret/data/base
vault policy write base - <<EOF
path "secret/data/base" {
  capabilities = ["read"]
}
EOF

# Bước 2 — Enable userpass tại hai paths riêng biệt
vault auth enable -path=userpass-test userpass
vault auth enable -path=userpass-qa userpass

# Bước 3 — Tạo users trên từng mount
vault write auth/userpass-test/users/bob \
    password="training" \
    policies="test"

vault write auth/userpass-qa/users/bsmith \
    password="training" \
    policies="team-qa"

# ============================================================
# Phần 2: Quan sát vấn đề (thông tin, không thay đổi state)
# ============================================================

# Bước 4 — Đăng nhập bằng bob, xem entity_id
vault login -method=userpass -path=userpass-test username=bob password=training
vault token lookup
# Ghi lại entity_id — đây là entity tự tạo cho bob

# Bước 5 — Đăng nhập bằng bsmith, xem entity_id khác
vault login -method=userpass -path=userpass-qa username=bsmith password=training
vault token lookup
# Ghi lại entity_id — khác với entity của bob ở bước 4

# ============================================================
# Phần 3: Hợp nhất identity
# ============================================================

# Bước 6 — Khôi phục root token để có quyền quản trị
export VAULT_TOKEN=root

# Bước 7 — Tạo entity bob-smith với policy base và metadata
vault write identity/entity \
    name="bob-smith" \
    policies="base" \
    metadata=organization="ACME Inc." \
    metadata=team="QA"

# Ghi lại id (entity_id) từ output, ví dụ:
# Key        Value
# ---        -----
# id         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
# name       bob-smith

ENTITY_ID=$(vault write -format=json identity/entity \
    name="bob-smith" \
    policies="base" \
    metadata=organization="ACME Inc." \
    metadata=team="QA" 2>/dev/null | jq -r '.data.id')

# Nếu entity đã tạo ở bước trên, đọc ID từ entity hiện có:
ENTITY_ID=$(vault list -format=json identity/entity/name | jq -r '.[]' | grep bob-smith | xargs -I{} vault read -format=json identity/entity/name/{} | jq -r '.data.id')

# Bước 8 — Lấy accessors của hai auth methods
ACCESSOR_TEST=$(vault auth list -format=json | jq -r '.["userpass-test/"].accessor')
ACCESSOR_QA=$(vault auth list -format=json | jq -r '.["userpass-qa/"].accessor')

echo "Accessor userpass-test: $ACCESSOR_TEST"
echo "Accessor userpass-qa:   $ACCESSOR_QA"

# Bước 9 — Gắn alias bob (từ userpass-test) vào entity bob-smith
vault write identity/entity-alias \
    name="bob" \
    canonical_id="$ENTITY_ID" \
    mount_accessor="$ACCESSOR_TEST"

# Gắn alias bsmith (từ userpass-qa) vào cùng entity
vault write identity/entity-alias \
    name="bsmith" \
    canonical_id="$ENTITY_ID" \
    mount_accessor="$ACCESSOR_QA"

# Bước 10 — Kiểm tra entity đã có đủ thông tin
vault read identity/entity/id/$ENTITY_ID

# ============================================================
# Phần 4: Kiểm tra kết quả
# ============================================================

# Bước 11 — Đăng nhập lại bằng bob, kiểm tra capabilities từ entity policy
vault login -method=userpass -path=userpass-test username=bob password=training

# Token này có policy "test" (từ alias) + policy "base" (từ entity)
# Kiểm tra quyền truy cập secret/data/base — phát sinh từ entity policy
vault token capabilities secret/data/base
# Kỳ vọng: read

# Kiểm tra quyền truy cập secret/data/test — phát sinh từ alias policy
vault token capabilities secret/data/test
# Kỳ vọng: read

# Xem đầy đủ thông tin token hiện tại
vault token lookup
```

## Lưu ý khi chạy

Lệnh `vault write identity/entity` trong bước 7 sẽ báo lỗi nếu entity `bob-smith` đã tồn tại từ bước trước đó. Trong trường hợp đó, dùng lệnh `vault read identity/entity/name/bob-smith` để lấy ID của entity đã tạo.

Thứ tự gắn alias không quan trọng — bạn có thể gắn alias của `userpass-qa` trước rồi `userpass-test` sau, kết quả vẫn như nhau.

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
