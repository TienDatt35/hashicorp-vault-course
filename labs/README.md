# Bài thực hành (Labs)

Mỗi bài thực hành nằm trong một thư mục riêng, gồm ba file:

| File | Mục đích |
|------|----------|
| `README.md` | Mô tả bài tập từng bước — đây là file bạn đọc trước tiên |
| `solution.md` | Đáp án mẫu kèm giải thích — mở khi bí |
| `verify.sh` | Kiểm tra tự động — chạy khi hoàn thành |

---

## Lưu ý về môi trường

Hầu hết các bài lab sử dụng **Dev Environment** — Vault dev server đã được
khởi động tự động trong Codespace, bạn không cần cấu hình thêm gì.

Ngoại lệ:

- **Chương 1, Bài 4** (`01-vault-introduction/04-install-vault`) yêu cầu
  **Self-Setup Environment** — bạn sẽ tự tải và cài Vault từ đầu. Bài này
  không dùng Vault dev server có sẵn.

---

## Cách làm một bài thực hành

### Bước 1 — Di chuyển vào thư mục bài lab

```bash
cd labs/<chương>/<bài>
```

Ví dụ:

```bash
cd labs/01-vault-introduction/01-problem-and-solution
```

### Bước 2 — Đọc README.md

```bash
Ctrl + Shift + V file README.md
```

Hoặc mở file trong VS Code bằng cách nhấn chuột phải → **Open Preview** để
đọc dạng Markdown có định dạng.

`README.md` mô tả mục tiêu, yêu cầu, và các bước thực hiện. Hãy đọc kỹ
trước khi bắt đầu gõ lệnh.

### Bước 3 — Tự thực hành

Thực hiện các bước trong `README.md` trực tiếp trên terminal. Vault dev
server đã chạy sẵn ở `http://127.0.0.1:8200` với token `root` — bạn không
cần khởi động lại.

### Bước 4 — Xem solution.md nếu gặp khó khăn

```bash
cat solution.md
```

`solution.md` chứa đáp án mẫu và giải thích tại sao làm như vậy. Hãy thử
tự làm trước, chỉ mở đáp án khi thực sự cần.

### Bước 5 — Chạy kiểm tra để xác nhận kết quả

```bash
bash verify.sh
```

Mỗi kiểm tra sẽ in ra `[PASS]` hoặc `[FAIL]`. Bài hoàn thành khi tất cả
đều `[PASS]` và dòng cuối là `Tất cả kiểm tra đều đạt.`

---

## Danh sách bài thực hành

### Chương 1 — Giới thiệu Vault

```
labs/01-vault-introduction/01-problem-and-solution/   Khám phá Vault dev server và token cơ bản
labs/01-vault-introduction/02-how-it-work/            Khám phá Vault qua CLI, UI và HTTP API
labs/01-vault-introduction/03-how-it-implemented/     Vault hoạt động như thế nào bên trong
labs/01-vault-introduction/04-install-vault/          Cài đặt Vault
```

### Chương 2 — Kiến trúc Vault

```
labs/02-vault-architecture/01-vault-components/              Các thành phần cốt lõi
labs/02-vault-architecture/02-vault-architecture-and-path/   Kiến trúc và path
labs/02-vault-architecture/03-vault-data-protection/         Bảo vệ dữ liệu
labs/02-vault-architecture/04-unseal-using-key-shard/        Unseal bằng key shard
labs/02-vault-architecture/05-auto-unseal/                   Auto unseal
labs/02-vault-architecture/06-auto-unseal-using-transit/     Auto unseal dùng Transit
labs/02-vault-architecture/08-vault-init/                    Khởi tạo Vault
```

### Chương 3 — Auth Method

```
labs/03-vault-auth-method/01-auth-method-introduction/       Giới thiệu auth method
labs/03-vault-auth-method/02-authen-using-api/               Xác thực qua API
labs/03-vault-auth-method/03-vault-entity/                   Vault entity
labs/03-vault-auth-method/04-vault-identity-group/           Identity group
labs/03-vault-auth-method/05-diff-and-choice-auth-methods/   So sánh và chọn auth method
```

### Chương 4 — Policy

```
labs/04-vault-policy/01-policy-introduction/   Giới thiệu policy
labs/04-vault-policy/02-policy-path/           Policy path
labs/04-vault-policy/03-policy-capabilities/   Capabilities
labs/04-vault-policy/04-custom-path/           Custom path
labs/04-vault-policy/05-using-policy/          Áp dụng policy
```

### Chương 5 — Token

```
labs/05-vault-token/01-token-introduction/    Giới thiệu token
labs/05-vault-token/02-token-metadata/        Token metadata
labs/05-vault-token/03-token-type/            Loại token
labs/05-vault-token/04-token-manage/          Quản lý token
labs/05-vault-token/05-token-best-practice/   Best practice
```

### Chương 6 — Secrets Engine

```
labs/06-vault-secret-engine/01-secret-engine-introduction/   Giới thiệu secrets engine
labs/06-vault-secret-engine/02-dynamic-secret-engine/        Dynamic secrets
labs/06-vault-secret-engine/03-static-secret-engine/         Static secrets (KV)
labs/06-vault-secret-engine/04-cubbyhole-secret-engine/      Cubbyhole
labs/06-vault-secret-engine/05-transit-secret-engine/        Transit (mã hóa)
```

### Chương 7 — Vault Agent

```
labs/07-vault-agent/01-agent-introduction/   Giới thiệu Vault Agent
labs/07-vault-agent/02-agent-auto-auth/      Auto auth
labs/07-vault-agent/03-agent-template/       Template rendering
```

### Chương 8 — Vault Secrets Operator

```
labs/08-vault-secret-operator/01-vso-introduction/        Giới thiệu VSO
labs/08-vault-secret-operator/02-install-and-config-vso/  Cài đặt và cấu hình
labs/08-vault-secret-operator/03-sync-secret/             Đồng bộ secret
labs/08-vault-secret-operator/04-vso-addition/            Nâng cao
```

### Chương 9 — Vault Replication

```
labs/09-vault-replication/01-replication-introduction/    Giới thiệu replication
labs/09-vault-replication/02-replication-architecture/    Kiến trúc
labs/09-vault-replication/03-setup-replication/           Cài đặt replication
labs/09-vault-replication/04-config-replication/          Cấu hình replication
```
