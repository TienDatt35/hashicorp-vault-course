# CLAUDE.md — Hướng dẫn cho Claude Code khi làm việc với repo này

Repo này là khóa học **HashiCorp Vault Associate (003)** bằng tiếng Việt. Mọi
nội dung học viên đọc phải bằng tiếng Việt; chỉ giữ tiếng Anh cho thuật ngữ kỹ
thuật khi cần (`token`, `policy`, `secrets engine`, v.v.).

## Cấu trúc repo

```
site/docs/<NN-chapter>/<NN-lesson>/   Lý thuyết + quiz cho mỗi bài học
labs/<NN-chapter>/<NN-lesson>/        Bài thực hành tương ứng
.devcontainer/                        Codespace với Vault dev server tự khởi động
```

Tên `<NN-chapter>` và `<NN-lesson>` phải khớp **chính xác** giữa `site/docs/`
và `labs/`. Ví dụ: `site/docs/01-fundamentals/01-dev-server/` ↔
`labs/01-fundamentals/01-dev-server/`.

## Templates

Khi tạo bài học mới, **luôn phát triển từ template** thay vì viết từ đầu:

- Site lesson template: `site/docs/_template/`
  - `_category_.json` — label & position cho sidebar
  - `theory.mdx` — lý thuyết, có Codespace badge và `<LabCallout/>`
  - `quiz.mdx` — `<Quiz/>` widget
- Lab template: `labs/_template/`
  - `README.md` — bài tập từng bước
  - `solution.md` — đáp án mẫu kèm giải thích
  - `verify.sh` — assertions in `[PASS]` / `[FAIL]`

## Quy tắc cho mỗi bài học

### Bài lý thuyết (`site/docs/.../theory.mdx`)

1. Front-matter phải có `sidebar_position: 1` và `title`.
2. Mở đầu bằng phần "Mục tiêu của bài học" — 2-4 gạch đầu dòng cụ thể.
3. Giải thích **vì sao** trước **làm như thế nào**.
4. Ưu tiên ví dụ ngắn (HCL hoặc CLI) thay vì đoạn văn dài.
5. Ưu tiên tạo, chèn widget tương tác từ
   `@site/src/components/widgets`: `ArchitectureDiagram`, `Flowchart`,
   `Quiz`, `LabCallout` để trực quan hoá các nội dung trong bài.
6. Kết bài luôn có:
   - Đường dẫn tới tài liệu tham khảo
   - Codespace badge: `[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/TienDatt35/hashicorp-vault-course)`
   - `<LabCallout labId="<NN-chapter>/<NN-lesson>" title="..." estMinutes={N} />`
7. Nội dung phải bám sát mục tiêu chính thức của kỳ thi Vault Associate (003).

### Quiz (`site/docs/.../quiz.mdx`)

1. Front-matter: `sidebar_position: 2`, `title: Quiz`.
2. Tối thiểu 10 câu hỏi, ưu tiên hỗn hợp `mcq` và `fill`.
3. Mỗi câu hỏi phải có `explanation` giải thích vì sao đáp án đúng vì sao sai.
4. `lessonId` đặt theo dạng `NN-chapter/NN-lesson` để Quiz widget lưu tiến độ
   không bị trùng với bài khác.
5. **Hành vi MCQ cần biết khi viết câu hỏi**:
   - MCQ cho phép thử lại tới khi đúng; điểm chỉ tính nếu đúng ngay lần đầu.
   - `explanation` hiển thị cả khi đúng lẫn khi sai → viết như một giải thích
     khái niệm, dẫn dắt trước rồi mới kết luận đáp án (đừng mở đầu bằng tên
     đáp án đúng).
   - Distractor phải hợp lý, không vô lý hiển nhiên.

### Bài thực hành (`labs/.../`)

1. `README.md` mô tả bài tập từng bước. Front-matter có `title` + `estMinutes`.
2. Học viên mặc định đã có Vault dev server chạy ở `127.0.0.1:8200` với token
   `root` (do devcontainer khởi động) — **không** yêu cầu họ chạy `vault server`
   thủ công.
3. `solution.md` các bước làm bài tập — markdown thuần, có script chạy được để học viên copy.
4. `verify.sh`:
   - Dùng các hàm `pass` / `fail` đã có sẵn trong template.
   - Kiểm tra đầu tiên luôn là "Vault có thể truy cập".
   - Mỗi bước trong README phải có ít nhất một assertion tương ứng.
   - Exit 0 chỉ khi mọi assertion `[PASS]`.
5. Học viên chạy bài kiểm tra bằng `bash verify.sh` (không dùng `make`).

## Quy ước viết

- Toàn bộ văn bản hướng tới học viên: tiếng Việt, xưng "bạn".
- Comment trong `verify.sh` và file lý thuyết: tiếng Việt.
- Tên biến shell, tên file, tên path: tiếng Anh.
- Không dùng emoji trong nội dung bài học.

## Quy trình làm việc khi thêm bài học mới

1. Người dùng cung cấp chương + tên bài + nội dung cần dạy và nhấn mạnh.
2. Dùng subagent `vault-docs-researcher` để lấy thông tin chính
   xác từ tài liệu Vault chính thức.
3. Trao đổi với người dùng để chỉnh sửa nội dung trước khi sang bước tiếp theo.
4. Dùng subagent `lesson-writer` (hoặc trực tiếp) để:
   - Sao chép `site/docs/_template/` → `site/docs/<NN-chapter>/<NN-lesson>/`
   - Sao chép `labs/_template/` → `labs/<NN-chapter>/<NN-lesson>/`
   - Phát triển nội dung theo các quy tắc ở trên
5. Cập nhật `_category_.json` với label đúng cho lesson.

## Codespace + Vault dev server

- Devcontainer gốc khởi động Vault qua `postStartCommand` trong
  `.devcontainer/devcontainer.json`. Lệnh hiện tại:
  `nohup vault server -dev -dev-root-token-id=root >/tmp/vault.log 2>&1 & sleep 3`
- `sleep 3` là **load-bearing** — đừng xóa nếu chưa hiểu lý do (xem lịch sử
  thảo luận: nó giữ `postStartCommand` sống đủ lâu để Vault hoàn tất khởi
  động trước khi Codespaces dọn process group).
- Biến môi trường mặc định trong Codespace: `VAULT_ADDR=http://127.0.0.1:8200`,
  `VAULT_TOKEN=root`.

## Những thứ KHÔNG làm

- **Không** publish `site/` lên GitHub Pages (đã bị `.gitignore`, đã xóa CI
  workflow). Chỉ build Docusaurus local nếu cần xem trước.
- **Không** push thư mục `.claude/` (chứa secret cục bộ, đã bị `.gitignore`).
- **Không** thêm CI workflow trong `.github/` trừ khi người dùng yêu cầu rõ.
- **Không** đưa đáp án trực tiếp vào `README.md` của lab — phải nằm trong
  `solution.md`.
- **Không** viết bài học bằng tiếng Anh.
