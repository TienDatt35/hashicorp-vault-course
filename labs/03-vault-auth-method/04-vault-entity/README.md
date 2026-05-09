---
title: Hợp nhất identity với Vault Entities và Aliases
estMinutes: 20
---

# Hợp nhất identity với Vault Entities và Aliases

## Mục tiêu

Bạn sẽ tái hiện vấn đề identity phân tán thực tế — khi một người dùng có hai tài khoản trên hai auth methods khác nhau và bị Vault coi là hai entity riêng biệt — rồi giải quyết vấn đề đó bằng cách tạo entity chung và gắn aliases, để hợp nhất toàn bộ policy vào một identity duy nhất.

## Yêu cầu

- Bạn đang làm việc bên trong Codespace của repo này, nên Vault dev server đã được khởi động sẵn ở `http://127.0.0.1:8200` với root token là `root`.
- Bạn đã đọc bài lý thuyết tương ứng trong `site/docs/03-vault-auth-method/03-vault-entity/theory.mdx`.

## Nhiệm vụ của bạn

### Phần 1: Thiết lập môi trường

**Bước 1** — Tạo ba policies cần thiết cho bài lab. Bạn sẽ cần:
- Policy `test`: cho phép đọc path `secret/data/test`
- Policy `team-qa`: cho phép đọc path `secret/data/qa`
- Policy `base`: cho phép đọc path `secret/data/base`

Tạo ba file HCL tương ứng rồi dùng lệnh `vault policy write` để nạp vào Vault.

**Bước 2** — Enable userpass auth method tại hai path riêng biệt:
- Path `userpass-test` (kiểu: `userpass`)
- Path `userpass-qa` (kiểu: `userpass`)

**Bước 3** — Tạo hai người dùng:
- User `bob` (password: `training`) trên mount `userpass-test`, gán policy `test`
- User `bsmith` (password: `training`) trên mount `userpass-qa`, gán policy `team-qa`

### Phần 2: Quan sát vấn đề

**Bước 4** — Đăng nhập bằng `bob` qua `userpass-test` và xem token info. Ghi lại `entity_id` trong output của `vault token lookup`. Đây là entity tự động tạo cho `bob`.

**Bước 5** — Đăng nhập bằng `bsmith` qua `userpass-qa` và xem token info. Ghi lại `entity_id`. Quan sát rằng đây là entity khác hoàn toàn so với bước 4.

> Bước 4 và 5 minh hoạ vấn đề: Vault tạo 2 entities riêng biệt cho cùng một người dùng thực tế.

### Phần 3: Hợp nhất identity

**Bước 6** — Đặt lại VAULT_TOKEN về root để có quyền quản trị:

```
export VAULT_TOKEN=root
```

**Bước 7** — Tạo entity mới có tên `bob-smith` với policy `base` và metadata:
- `organization=ACME Inc.`
- `team=QA`

Ghi lại `id` (entity_id) từ output.

**Bước 8** — Lấy mount accessor của cả hai auth method. Sử dụng lệnh `vault auth list` với format JSON để lấy accessor của `userpass-test` và `userpass-qa`.

**Bước 9** — Gắn hai aliases vào entity `bob-smith`:
- Alias thứ nhất: `name="bob"`, trỏ đến mount `userpass-test`
- Alias thứ hai: `name="bsmith"`, trỏ đến mount `userpass-qa`

**Bước 10** — Kiểm tra entity đã được tạo đúng bằng cách đọc thông tin entity theo ID.

### Phần 4: Kiểm tra kết quả

**Bước 11** — Đăng nhập lại bằng `bob` qua `userpass-test`. Dùng `vault token capabilities secret/data/base` để xác nhận token mới có quyền truy cập path `secret/data/base` (từ entity policy `base`) — dù alias `bob` chỉ được gán policy `test`.

> Gợi ý: hãy tự suy nghĩ trước khi mở `solution.md`. Nếu bị mắc kẹt ở bước nào, hãy đối chiếu với phần giải đáp.

## Tiêu chí thành công

Chạy bộ kiểm tra:

```bash
bash verify.sh
```

Bạn phải thấy `[PASS]` cho từng kiểm tra và dòng cuối `Tất cả kiểm tra đều đạt.`

## Cần đáp án?

Mở [`solution.md`](./solution.md) để xem lời giải mẫu kèm giải thích.
