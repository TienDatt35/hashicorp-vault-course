# Khóa học HashiCorp Vault Associate (003)

Khóa học mã nguồn mở, miễn phí giúp bạn vượt qua kỳ thi **HashiCorp Certified: Vault Associate (003)**.

Khóa học gồm hai phần:

- **Lý thuyết** — một trang Docusaurus tương tác với sơ đồ, bài kiểm tra và cây quyết định, được xuất bản qua GitHub Pages.
- **Bài thực hành** — mỗi bài học có một thư mục riêng trong [`labs/`](./labs), kèm theo devcontainer GitHub Codespace để bạn có thể chạy một Vault server thật chỉ trong vài giây và tự kiểm tra bài làm bằng `make verify`.

## Cách sử dụng khóa học

1. **Đọc lý thuyết** — truy cập [trang khóa học](https://example.github.io/hashicorp-vault-course) (cập nhật lại sau khi bạn xuất bản) và học theo thứ tự các chương.
2. **Làm bài thực hành** — ở cuối mỗi bài học, bấm **Mở trong Codespaces** để khởi chạy bài thực hành tương ứng. Codespace sẽ khởi động với `vault` đã được cài sẵn và một dev server đang chạy.
3. **Kiểm tra đáp án** — trong Codespace, chạy `make verify`. Bạn sẽ thấy toàn bộ dòng `[PASS]`. Nếu bí, hãy xem trong thư mục `solution/`.
4. **Làm bài kiểm tra** — mỗi chương kết thúc bằng một widget kiểm tra, lưu tiến độ ngay trong trình duyệt của bạn.

## Chương trình học

Các chương bám sát mục tiêu chính thức của kỳ thi Vault Associate (003):

1. Kiến thức nền tảng về Vault
2. Phương thức xác thực (Authentication methods)
3. Secrets engines
4. Policies
5. Tokens
6. Kiến trúc triển khai Vault
7. Mã hóa như một dịch vụ (Encryption as a service)

## Cấu trúc repository

```
site/    Trang Docusaurus (lý thuyết + widget tương tác)
labs/    Mỗi thư mục là một bài thực hành; có .devcontainer riêng + verify.sh
.github/ CI: deploy site lên GitHub Pages, kiểm tra mọi solution của bài thực hành
```

## Đóng góp

- Thêm bài thực hành mới? Hãy sao chép `labs/_template/` và làm theo quy ước trong [`labs/README.md`](./labs/README.md).
- Thêm bài học mới? Tạo một file `.mdx` trong `site/docs/<chương>/` rồi liên kết tới bài thực hành tương ứng bằng `<LabCallout labId="..." />`.

## Giấy phép

MIT — xem [LICENSE](./LICENSE).
