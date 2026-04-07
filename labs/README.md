# Bài thực hành (Labs)

Mỗi thư mục con là một bài thực hành độc lập, gồm:

- một file `.devcontainer/devcontainer.json` riêng để mở trực tiếp trong GitHub Codespace với `vault` đã cài sẵn
- một `Makefile` cung cấp cùng bốn target chuẩn cho mọi bài thực hành
- một `verify.sh` kiểm tra trạng thái Vault và in ra các dòng `[PASS]` / `[FAIL]`
- một thư mục `solution/` chứa đáp án mẫu (dùng cho cả người học khi bí và cho CI)

## Quy ước Makefile

Mỗi bài thực hành đều có bốn target này để trải nghiệm học viên đồng nhất:

| Target          | Tác dụng                                                                 |
| --------------- | ------------------------------------------------------------------------ |
| `make setup`    | Khởi động `vault server -dev` ngầm, xuất `VAULT_ADDR`/`VAULT_TOKEN`.     |
| `make verify`   | Chạy `verify.sh`. Trả về mã lỗi khác 0 nếu có bất kỳ kiểm tra nào hỏng. |
| `make solution` | Áp dụng đáp án mẫu trong `solution/` rồi chạy lại verify.                |
| `make reset`    | Dừng server, xóa state và chạy lại `setup`.                              |

`make setup` cũng được nối vào `postCreateCommand` của devcontainer, nên khi Codespace khởi động xong là server đã sẵn sàng.

## Cách viết một bài thực hành mới

1. `cp -r _template <chương>/<tên-ngắn>`
2. Sửa `README.md` mô tả mục tiêu và tiêu chí thành công
3. Sửa `verify.sh` để kiểm tra trạng thái Vault mong muốn
4. Viết một đáp án chạy được trong `solution/`
5. Chạy `make solution` ở local — mọi kiểm tra phải `[PASS]`
6. Mở pull request. CI sẽ chạy `make solution` cho mọi bài thực hành; nếu bài của bạn không qua thì PR sẽ fail.

## Danh sách bài thực hành

- `01-fundamentals/01-dev-server-first-steps` — khởi động dev server, ghi và đọc một secret KV
