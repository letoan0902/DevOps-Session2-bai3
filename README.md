# DevOps - Session 02 - Bài 3: Cài đặt Nginx và cấu hình Website tĩnh cơ bản

Repository chứa bài nộp Bài 3 của Session 02 (môn DevOps): cài đặt Nginx từ repo mặc định của Ubuntu Server 24.04 LTS, tạo Server Block riêng lắng nghe cổng 80 và phục vụ một trang HTML tĩnh "Welcome to PTIT DevOps Course - Session 02" qua địa chỉ IP của máy chủ.

## Mục lục

| Nội dung | Đường dẫn |
|---|---|
| Báo cáo và hướng dẫn chi tiết Bài 3 | [`homework/session_02/ex3/README.md`](homework/session_02/ex3/README.md) |
| Cấu hình Server Block Nginx | [`homework/session_02/ex3/ptit-web.conf`](homework/session_02/ex3/ptit-web.conf) |
| Trang web tĩnh | [`homework/session_02/ex3/index.html`](homework/session_02/ex3/index.html) |
| Script triển khai idempotent | [`homework/session_02/ex3/deploy.sh`](homework/session_02/ex3/deploy.sh) |
| Log Terminal của toàn bộ phiên thực hiện | [`homework/session_02/ex3/terminal_log.txt`](homework/session_02/ex3/terminal_log.txt) |

## Tóm tắt

- Máy chủ: Ubuntu Server 24.04.3 LTS, hostname `halo`, IP `103.116.104.228`.
- Phần mềm: Nginx 1.24.0 cài bằng `sudo apt update && sudo apt install -y nginx`.
- Mã nguồn web: `/var/www/ptit-web/html/index.html`.
- Cấu hình: `/etc/nginx/sites-available/ptit-web.conf`, kích hoạt bằng symlink trong `/etc/nginx/sites-enabled/`, đã hủy kích hoạt cấu hình `default`.
- Kiểm tra: `sudo nginx -t`, `sudo systemctl reload nginx`, truy cập `http://103.116.104.228`.
