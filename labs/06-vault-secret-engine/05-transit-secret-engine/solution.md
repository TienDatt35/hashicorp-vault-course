---
title: Đáp án mẫu — Thực hành Transit Secrets Engine
---

# Đáp án mẫu

> Đây là một cách giải chuẩn cho bài thực hành. Có thể có nhiều cách khác cũng
> đúng — miễn là `bash verify.sh` báo `[PASS]` cho mọi kiểm tra.

## Giải thích ngắn

Transit Secrets Engine hoạt động theo mô hình Encryption as a Service: ứng dụng gửi plaintext (đã base64) lên Vault, Vault mã hóa bằng named key và trả về ciphertext. Vault không lưu ciphertext — ứng dụng phải tự lưu vào storage. Bài lab này đi qua toàn bộ vòng đời: tạo key, mã hóa, giải mã, rotate, kiểm soát version bằng `min_decryption_version`, và rewrap ciphertext cũ.

---

## Các lệnh

```bash
# ========================================
# Bước 1 — Bật Transit Secrets Engine
# ========================================
# Transit engine được bật tại path mặc định "transit/"
vault secrets enable transit

# Xác nhận transit đã được bật
vault secrets list

# ========================================
# Bước 2 — Tạo key mặc định
# ========================================
# vault write -f: flag -f dùng khi không có data body
# Type mặc định là aes256-gcm96, không cần chỉ định rõ
vault write -f transit/keys/lab-key

# Đọc thông tin key để xem version ban đầu
# latest_version=1, min_decryption_version=1
vault read transit/keys/lab-key

# ========================================
# Bước 3 — Encrypt dữ liệu
# ========================================
# Quan trọng: plaintext PHẢI là base64 trước khi gửi lên Vault
# Trên Linux, "base64 <<< text" thêm newline vào cuối
# Vault chấp nhận điều này bình thường
PLAINTEXT_B64=$(base64 <<< "Hello Vault Transit")

vault write transit/encrypt/lab-key plaintext="$PLAINTEXT_B64"
# Output có dạng:
#   ciphertext    vault:v1:AbCdEf...
#   key_version   1

# Lưu lại ciphertext vào biến để dùng ở các bước sau
CIPHER_V1=$(vault write -field=ciphertext transit/encrypt/lab-key plaintext="$PLAINTEXT_B64")
echo "Ciphertext v1: $CIPHER_V1"

# ========================================
# Bước 4 — Decrypt và kiểm tra kết quả
# ========================================
# Vault trả về plaintext dạng base64
RESULT_B64=$(vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_V1")

# Decode base64 để lấy lại chuỗi gốc
echo "$RESULT_B64" | base64 --decode
# Kết quả: Hello Vault Transit

# ========================================
# Bước 5 — Rotate key và encrypt lại
# ========================================
# Rotate tạo version 2 trong keyring; version 1 vẫn còn và dùng được
vault write -f transit/keys/lab-key/rotate

# Xác nhận latest_version=2
vault read transit/keys/lab-key

# Encrypt lại — ciphertext mới sẽ dùng version 2 (vault:v2:...)
CIPHER_V2=$(vault write -field=ciphertext transit/encrypt/lab-key plaintext="$PLAINTEXT_B64")
echo "Ciphertext v2: $CIPHER_V2"
# Prefix phải là vault:v2:...

# ========================================
# Bước 6 — Cấu hình min_decryption_version
# ========================================
# Đặt min_decryption_version=2: Vault từ chối decrypt ciphertext v1
vault write transit/keys/lab-key/config min_decryption_version=2

# Thử decrypt ciphertext v1 — phải thất bại
vault write transit/decrypt/lab-key ciphertext="$CIPHER_V1"
# Lỗi: requested version for decryption is less than the minimum allowed version

# Decrypt ciphertext v2 — vẫn thành công
vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_V2" | base64 --decode
# Kết quả: Hello Vault Transit

# ========================================
# Bước 7 — Rewrap ciphertext
# ========================================
# Rewrap cho phép "nâng cấp" ciphertext từ version cũ sang version mới
# mà không để lộ plaintext ra ngoài Vault
# Lưu ý: min_decryption_version=2, nhưng rewrap vẫn dùng được vì
# Vault tự xử lý nội bộ; rewrap không bị giới hạn bởi min_decryption_version
# đối với đầu vào — chỉ đầu ra dùng version mới nhất

# Trước tiên, tạm thời hạ min_decryption_version=1 để rewrap có thể đọc v1
vault write transit/keys/lab-key/config min_decryption_version=1

CIPHER_REWRAPPED=$(vault write -field=ciphertext transit/rewrap/lab-key ciphertext="$CIPHER_V1")
echo "Ciphertext sau rewrap: $CIPHER_REWRAPPED"
# Prefix phải là vault:v2:... (version mới nhất)

# Kiểm tra kết quả: decrypt ciphertext đã rewrap
vault write -field=plaintext transit/decrypt/lab-key ciphertext="$CIPHER_REWRAPPED" | base64 --decode
# Kết quả: Hello Vault Transit

# Đặt lại min_decryption_version=2 sau khi rewrap xong
vault write transit/keys/lab-key/config min_decryption_version=2
```

---

## Lưu ý kỹ thuật quan trọng

### base64 trên Linux vs macOS

```bash
# Linux (GNU coreutils): base64 <<< "text" thêm newline vào chuỗi
# Vault chấp nhận chuỗi base64 có newline trailing
base64 <<< "Hello Vault Transit"
# → SGVsbG8gVmF1bHQgVHJhbnNpdAo=  (có \n ở cuối)

# Nếu muốn base64 không có newline (phòng trường hợp so sánh chính xác):
printf '%s' "Hello Vault Transit" | base64
# → SGVsbG8gVmF1bHQgVHJhbnNpdA==  (không có \n)

# Decode:
echo "SGVsbG8gVmF1bHQgVHJhbnNpdA==" | base64 --decode
# hoặc
base64 --decode <<< "SGVsbG8gVmF1bHQgVHJhbnNpdA=="
```

### Đọc key_version từ output

```bash
# Cách 1: đọc trực tiếp từ output của vault write encrypt
vault write transit/encrypt/lab-key plaintext="..."
# Key         Value
# key_version 2   ← đây là version đã dùng

# Cách 2: đọc từ prefix của ciphertext
echo "vault:v2:AbCdEf..." | cut -d: -f2
# → v2  (version là 2)
```

### Tại sao decrypt v1 thất bại sau khi set min_decryption_version=2

`min_decryption_version` là một ngưỡng bảo vệ: khi Vault nhận yêu cầu decrypt `vault:v1:...`, nó kiểm tra version trong prefix (là 1) so với `min_decryption_version` (là 2). Vì 1 < 2, Vault trả về lỗi. Key version 1 vẫn tồn tại trong keyring — chỉ là Vault chặn không cho dùng.

### Lưu ý về rewrap và min_decryption_version

Trong thực tế, bạn nên rewrap **trước** khi nâng `min_decryption_version`. Quy trình chuẩn:
1. Rotate key (tạo version mới).
2. Rewrap tất cả ciphertext cũ.
3. Nâng `min_decryption_version` để vô hiệu hóa version cũ.

Trong bài lab, để kiểm tra được cả hai trạng thái (v1 thất bại và rewrap thành công), chúng ta tạm thời hạ `min_decryption_version=1` để thực hiện rewrap, rồi nâng lại.

---

## Kiểm tra lại

```bash
bash verify.sh
```

Bạn phải thấy toàn bộ dòng `[PASS]`.
