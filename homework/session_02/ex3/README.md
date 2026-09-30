# Bài 3: Cài đặt Nginx và cấu hình Website tĩnh cơ bản (Basic Nginx Web Server)

| Thông tin | Nội dung |
|---|---|
| Môn học | DevOps |
| Session | 02 |
| Bài | 3 - Cài đặt Nginx và cấu hình Website tĩnh cơ bản |
| Ngày thực hiện | 2026-10-01 |
| Máy chủ | `halo` - Ubuntu Server 24.04.3 LTS - IP `103.116.104.228` |
| Người thao tác | User `devops` (có quyền `sudo`, tạo ở Bài 2) |
| Phần mềm | Nginx `1.24.0` (gói `1.24.0-2ubuntu7.5` từ repo mặc định của Ubuntu) |

## Mục lục

1. [Đề bài và mục tiêu](#1-đề-bài-và-mục-tiêu)
2. [Môi trường thực hiện](#2-môi-trường-thực-hiện)
3. [Kiến thức nền tảng](#3-kiến-thức-nền-tảng)
4. [Sơ đồ luồng xử lý request](#4-sơ-đồ-luồng-xử-lý-request)
5. [Các bước thực hiện](#5-các-bước-thực-hiện)
6. [Giải thích chi tiết Server Block `ptit-web.conf`](#6-giải-thích-chi-tiết-server-block-ptit-webconf)
7. [Xử lý sự cố thường gặp](#7-xử-lý-sự-cố-thường-gặp)
8. [Script tự động hóa `deploy.sh`](#8-script-tự-động-hóa-deploysh)
9. [Lưu ý bảo mật và hướng mở rộng](#9-lưu-ý-bảo-mật-và-hướng-mở-rộng)
10. [Đối chiếu yêu cầu đề bài](#10-đối-chiếu-yêu-cầu-đề-bài)
11. [Cấu trúc bài nộp](#11-cấu-trúc-bài-nộp)
12. [Tài liệu tham khảo](#12-tài-liệu-tham-khảo)

Các tệp đi kèm trong thư mục này:

| Tệp | Vai trò |
|---|---|
| [`ptit-web.conf`](ptit-web.conf) | Server Block của Nginx (nộp theo yêu cầu đề bài) |
| [`index.html`](index.html) | Trang web tĩnh (nộp theo yêu cầu đề bài) |
| [`deploy.sh`](deploy.sh) | Script Bash idempotent gom các lệnh triển khai |
| [`terminal_log.txt`](terminal_log.txt) | Toàn bộ log Terminal của phiên thực hiện |

---

## 1. Đề bài và mục tiêu

### 1.1. Đề bài

- **Mục tiêu:** Cài Nginx trên Ubuntu Server bằng `apt`; thiết lập Server Block tùy chỉnh lắng nghe cổng 80 để phục vụ một trang HTML tĩnh.
- **Bối cảnh:** Dựng website giới thiệu đơn giản cho PTIT chạy trên Droplet để người dùng truy cập qua địa chỉ IP.
- **Kiểm tra:** `sudo nginx -t` báo "syntax is ok"; `sudo systemctl reload nginx`; từ máy cá nhân mở `http://<IP>` thấy trang PTIT.
- **Gợi ý:** Luôn chạy `sudo nginx -t` trước khi reload.

### 1.2. Các ràng buộc phải đáp ứng

1. Cài Nginx mới nhất từ repo mặc định của Ubuntu.
2. Tạo thư mục `/var/www/ptit-web/html/` và tệp `index.html` hiển thị dòng chữ "Welcome to PTIT DevOps Course - Session 02".
3. Tạo Server Block riêng tại `/etc/nginx/sites-available/ptit-web.conf`, lắng nghe cổng 80, `root` trỏ về thư mục ở mục 2.
4. Kích hoạt bằng symlink sang `/etc/nginx/sites-enabled/`.
5. Xóa hoặc hủy kích hoạt cấu hình `default` để tránh xung đột cổng 80.

### 1.3. Kết quả đạt được

Nginx 1.24.0 chạy ổn định dưới dạng dịch vụ `systemd`, khởi động cùng hệ thống. Địa chỉ `http://103.116.104.228` trả về `HTTP/1.1 200 OK` và hiển thị trang "Welcome to PTIT DevOps Course - Session 02". Cấu hình `default` đã được hủy kích hoạt nhưng vẫn giữ tệp gốc trong `sites-available` để tham khảo.

---

## 2. Môi trường thực hiện

| Thành phần | Giá trị |
|---|---|
| Hệ điều hành máy chủ | Ubuntu Server 24.04.3 LTS (codename `noble`), kernel 6.8.0-71-generic |
| Hostname | `halo` |
| Địa chỉ IP công khai | `103.116.104.228` |
| User thao tác | `devops` (nhóm `sudo`, sudo hỏi mật khẩu) |
| Prompt máy chủ | `devops@halo:~$` |
| Máy cá nhân | Windows, Git Bash, prompt `$`, dùng `curl` và trình duyệt Chrome để kiểm tra |
| Múi giờ máy chủ | UTC |
| Nguồn gói | Repo mặc định Ubuntu: `noble`, `noble-updates`, `noble-security` |

Quy ước trình bày: dòng bắt đầu bằng `devops@halo:~$` là lệnh gõ trên máy chủ; dòng bắt đầu bằng `$` là lệnh gõ trên máy cá nhân (Git Bash); dòng bắt đầu bằng `> ` là dấu nhắc tiếp tục của Bash khi nhập heredoc. Các đoạn log dưới đây được trích từ [`terminal_log.txt`](terminal_log.txt) và có thể được rút gọn ở các đoạn đã ghi chú.

---

## 3. Kiến thức nền tảng

### 3.1. Nginx và vai trò web server

Nginx là phần mềm web server và reverse proxy hiệu năng cao, kiến trúc hướng sự kiện (event-driven). Một tiến trình `master` đọc cấu hình, mở cổng lắng nghe và quản lý các tiến trình `worker`; các `worker` (chạy bằng user `www-data` trên Ubuntu) xử lý kết nối của client. Với website tĩnh, Nginx chỉ cần ánh xạ URL sang tệp trên ổ đĩa rồi trả về nội dung kèm mã trạng thái HTTP thích hợp.

Theo yêu cầu đề bài, Nginx được cài từ repo mặc định của Ubuntu, tức là phiên bản do Ubuntu đóng gói và bảo trì (`1.24.0`). Ưu điểm: cài bằng một lệnh `apt`, nhận bản vá bảo mật qua kênh `noble-security`/`noble-updates`, tích hợp sẵn dịch vụ `systemd` và `logrotate`.

### 3.2. Cấu trúc thư mục cấu hình của Nginx trên Ubuntu

```text
/etc/nginx/
|-- nginx.conf              # cấu hình chính, có dòng: include /etc/nginx/sites-enabled/*;
|-- conf.d/                 # các tệp *.conf bổ sung (không dùng trong bài này)
|-- sites-available/        # nơi LƯU TRỮ mọi tệp cấu hình site (đã bật hoặc chưa)
|   |-- default             # site mặc định của Ubuntu (giữ lại để tham khảo)
|   `-- ptit-web.conf       # Server Block của bài này
|-- sites-enabled/          # nơi chứa symlink tới các site ĐANG ĐƯỢC BẬT
|   `-- ptit-web.conf -> /etc/nginx/sites-available/ptit-web.conf
|-- modules-enabled/        # module động được nạp khi khởi động
`-- mime.types              # ánh xạ đuôi tệp sang Content-Type
```

### 3.3. Cơ chế `sites-available` và `sites-enabled`

Đây là quy ước của Debian/Ubuntu (không phải của Nginx gốc):

- `sites-available/` là kho lưu trữ: tệp nằm ở đây **chưa** có hiệu lực.
- `sites-enabled/` là danh sách đang bật: `nginx.conf` chỉ nạp những gì có trong thư mục này.
- Bật một site bằng cách tạo symlink (`ln -s`), tắt site bằng cách xóa symlink (`rm`). Tệp gốc trong `sites-available` không bị mất, nên có thể bật lại bất kỳ lúc nào và dễ quản lý phiên bản.

### 3.4. Cách Nginx chọn Server Block cho một request

Nginx chọn server theo hai bước (xem tài liệu "How nginx processes a request"):

1. **Theo địa chỉ và cổng (`listen`):** Xác định request đến cặp IP:cổng nào, ví dụ `0.0.0.0:80`.
2. **Theo tên (`server_name`):** Trong các server block cùng lắng nghe IP:cổng đó, so khớp header `Host` của request với `server_name`. Nếu không khớp block nào thì dùng block mang cờ `default_server` của IP:cổng đó; nếu không block nào có cờ này thì dùng block **đầu tiên** được nạp.

Khi người dùng truy cập bằng địa chỉ IP, header `Host` là `103.116.104.228` và không khớp với `server_name` nào, nên việc chọn block phụ thuộc hoàn toàn vào `default_server`. Đây là lý do cấu hình của bài dùng `default_server` (phân tích kỹ ở mục 6.2).

---

## 4. Sơ đồ luồng xử lý request

```text
   Máy cá nhân (trình duyệt Chrome / curl)
        |
        |  (1) HTTP GET /   Host: 103.116.104.228
        v
   Internet  -->  103.116.104.228 : cổng 80 (TCP)
        |
        v
   +--------------------------------------------------------------+
   |  Nginx master + worker (www-data)                            |
   |  lắng nghe 0.0.0.0:80 và [::]:80                             |
   +--------------------------------------------------------------+
        |
        |  (2) Chọn Server Block: khớp IP:cổng, Host không khớp
        |      server_name nào  ->  dùng default_server
        v
   server { listen 80 default_server; server_name _; ... }
        |                          (ptit-web.conf)
        |  (3) location /  ->  try_files $uri $uri/ =404
        |      URI "/" là thư mục  ->  áp dụng directive index
        v
   root /var/www/ptit-web/html   +   index index.html
        |
        |  (4) Đọc /var/www/ptit-web/html/index.html (quyền đọc của www-data)
        v
   HTTP/1.1 200 OK  +  nội dung HTML
        |
        |  (5) Ghi 1 dòng vào /var/log/nginx/ptit-web.access.log
        v
   Trả kết quả về client  ->  trình duyệt hiển thị
   "Welcome to PTIT DevOps Course - Session 02"
```

Nếu tệp không tồn tại ở bước (3), `try_files` trả về `404 Not Found`. Nếu tệp tồn tại nhưng `www-data` không có quyền đọc ở bước (4), Nginx trả về `403 Forbidden` và ghi lỗi vào `ptit-web.error.log`.

---

## 5. Các bước thực hiện

### 5.0. Kết nối tới máy chủ

Đăng nhập bằng user `devops` (đã tạo ở Bài 2) và xác nhận môi trường.

```text
$ ssh devops@103.116.104.228
Welcome to Ubuntu 24.04.3 LTS (GNU/Linux 6.8.0-71-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

 System information as of Thu Oct  1 02:10:42 UTC 2026

  System load:  0.02              Processes:             112
  Usage of /:   9.8% of 47.35GB   Users logged in:       0
  Memory usage: 14%               IPv4 address for eth0: 103.116.104.228
  Swap usage:   0%

Expanded Security Maintenance for Applications is not enabled.

12 updates can be applied immediately.
To see these additional updates run: apt list --upgradable

Enable ESM Apps to receive additional future security updates.
See https://ubuntu.com/esm or run: sudo pro status

Last login: Wed Sep 30 14:05:19 2026 from 113.161.72.19
devops@halo:~$ whoami
devops
devops@halo:~$ hostnamectl | grep -E 'Static hostname|Operating System'
   Static hostname: halo
  Operating System: Ubuntu 24.04.3 LTS
devops@halo:~$ ip -4 -br addr show eth0
eth0             UP             103.116.104.228/24
```

### 5.1. Cài đặt Nginx từ repo mặc định

Lệnh cài đặt:

```bash
sudo apt update && sudo apt install -y nginx
```

- `apt update` làm mới danh sách gói từ các repo trong `/etc/apt/sources.list.d/`, bảo đảm `apt` cài đúng phiên bản mới nhất hiện có.
- `apt install -y nginx` cài gói `nginx` cùng các gói phụ thuộc (`nginx-common`, các module `libnginx-mod-*`, thư viện đồ họa cho module `image-filter`...). Cờ `-y` tự trả lời "yes" cho câu hỏi xác nhận.

Log (đã rút gọn ở phần giữa, toàn văn xem `terminal_log.txt`):

```text
devops@halo:~$ sudo apt update && sudo apt install -y nginx
[sudo] password for devops:
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
Get:2 http://archive.ubuntu.com/ubuntu noble-updates InRelease [126 kB]
Get:3 http://archive.ubuntu.com/ubuntu noble-backports InRelease [126 kB]
Get:4 http://security.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Get:5 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages [1,680 kB]
Get:6 http://archive.ubuntu.com/ubuntu noble-updates/main Translation-en [321 kB]
Get:7 http://archive.ubuntu.com/ubuntu noble-updates/universe amd64 Packages [1,426 kB]
Get:8 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages [1,402 kB]
Get:9 http://security.ubuntu.com/ubuntu noble-security/main Translation-en [246 kB]
Fetched 5,453 kB in 2s (2,874 kB/s)
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
12 packages can be upgraded. Run 'apt list --upgradable' to see them.
Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
The following additional packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0
  libjpeg-turbo8 libjpeg8 libmaxminddb0 libnginx-mod-http-geoip2
  libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff6 libwebp7 libxpm4
  libxslt1.1 nginx-common
Suggested packages:
  libgd-tools fcgiwrap nginx-doc ssl-cert
The following NEW packages will be installed:
  fontconfig-config fonts-dejavu-core libdeflate0 libfontconfig1 libgd3 libjbig0
  libjpeg-turbo8 libjpeg8 libmaxminddb0 libnginx-mod-http-geoip2
  libnginx-mod-http-image-filter libnginx-mod-http-xslt-filter libnginx-mod-mail
  libnginx-mod-stream libnginx-mod-stream-geoip2 libtiff6 libwebp7 libxpm4
  libxslt1.1 nginx nginx-common
0 upgraded, 21 newly installed, 0 to remove and 12 not upgraded.
Need to get 3,017 kB of archives.
After this operation, 9,437 kB of additional disk space will be used.
Get:1 http://archive.ubuntu.com/ubuntu noble/main amd64 fonts-dejavu-core all 2.37-8 [1,041 kB]
Get:2 http://archive.ubuntu.com/ubuntu noble/main amd64 fontconfig-config amd64 2.15.0-1.1ubuntu2 [37.3 kB]
... (rút gọn các dòng tải gói còn lại) ...
Get:21 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 nginx amd64 1.24.0-2ubuntu7.5 [535 kB]
Fetched 3,017 kB in 1s (3,310 kB/s)
... (rút gọn các bước Selecting / Preparing / Unpacking / Setting up của các thư viện phụ thuộc) ...
Setting up nginx-common (1.24.0-2ubuntu7.5) ...
Created symlink /etc/systemd/system/multi-user.target.wants/nginx.service → /usr/lib/systemd/system/nginx.service.
Setting up libnginx-mod-http-geoip2 (1.24.0-2ubuntu7.5) ...
Setting up libnginx-mod-http-image-filter (1.24.0-2ubuntu7.5) ...
Setting up libnginx-mod-http-xslt-filter (1.24.0-2ubuntu7.5) ...
Setting up libnginx-mod-mail (1.24.0-2ubuntu7.5) ...
Setting up libnginx-mod-stream (1.24.0-2ubuntu7.5) ...
Setting up libnginx-mod-stream-geoip2 (1.24.0-2ubuntu7.5) ...
Setting up nginx (1.24.0-2ubuntu7.5) ...
Processing triggers for ufw (0.36.2-6) ...
Processing triggers for man-db (2.12.0-4build2) ...
Processing triggers for libc-bin (2.39-0ubuntu8.6) ...
Scanning processes...
Scanning linux images...

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
```

Sau khi cài, gói `nginx` tự tạo symlink kích hoạt dịch vụ (dòng `Created symlink ... nginx.service`) và khởi động Nginx ngay.

#### Kiểm tra phiên bản, dịch vụ và cổng lắng nghe

```text
devops@halo:~$ nginx -v
nginx version: nginx/1.24.0 (Ubuntu)
devops@halo:~$ apt-cache policy nginx
nginx:
  Installed: 1.24.0-2ubuntu7.5
  Candidate: 1.24.0-2ubuntu7.5
  Version table:
 *** 1.24.0-2ubuntu7.5 500
        500 http://archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages
        500 http://security.ubuntu.com/ubuntu noble-security/main amd64 Packages
        100 /var/lib/dpkg/status
     1.24.0-2ubuntu7 500
        500 http://archive.ubuntu.com/ubuntu noble/main amd64 Packages
devops@halo:~$ systemctl status nginx --no-pager
* nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-10-01 02:13:21 UTC; 24s ago
       Docs: man:nginx(8)
    Process: 4127 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 4129 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 4130 (nginx)
      Tasks: 3 (limit: 2269)
     Memory: 2.4M (peak: 2.9M)
        CPU: 21ms
     CGroup: /system.slice/nginx.service
             ├─4130 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─4131 "nginx: worker process"
             └─4132 "nginx: worker process"

Oct 01 02:13:21 halo systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 01 02:13:21 halo systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
devops@halo:~$ sudo systemctl enable nginx
Synchronizing state of nginx.service with SysV service script with /usr/lib/systemd/systemd-sysv-install.
Executing: /usr/lib/systemd/systemd-sysv-install enable nginx
devops@halo:~$ systemctl is-enabled nginx
enabled
devops@halo:~$ systemctl is-active nginx
active
devops@halo:~$ sudo ss -tlnp | grep :80
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=4132,fd=5),("nginx",pid=4131,fd=5),("nginx",pid=4130,fd=5))
LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=4132,fd=6),("nginx",pid=4131,fd=6),("nginx",pid=4130,fd=6))
devops@halo:~$ sudo ufw status
Status: inactive
```

Nhận xét:

- `nginx/1.24.0 (Ubuntu)` và `apt-cache policy` cho thấy `Installed` trùng `Candidate`, tức đã cài phiên bản mới nhất trong repo mặc định (`1.24.0-2ubuntu7.5`, từ `noble-updates`/`noble-security`).
- `Active: active (running)` và `enabled`: dịch vụ đang chạy và tự khởi động cùng hệ thống. Lệnh `sudo systemctl enable nginx` được chạy lại để khẳng định trạng thái này (thông báo `Synchronizing state ... SysV` là bình thường vì gói Nginx có kèm init script).
- `ss -tlnp | grep :80` cho thấy tiến trình `nginx` (master PID 4130 và hai worker) lắng nghe `0.0.0.0:80` (IPv4) và `[::]:80` (IPv6). Tham số `-t` là TCP, `-l` là socket đang listen, `-n` hiển thị số thay vì tên, `-p` hiển thị tiến trình (cần `sudo`).
- `ufw status` là `inactive` tại thời điểm này nên chưa có tường lửa chặn cổng 80. Việc bật UFW và mở cổng được thực hiện ở Bài 4.

#### Kiểm tra trang mặc định từ máy cá nhân

Trước khi thay đổi gì, kiểm tra trang chào mừng mặc định của Nginx để chắc chắn đường truyền từ Internet tới cổng 80 đã thông.

```text
$ curl -I http://103.116.104.228
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 01 Oct 2026 02:15:34 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Mon, 16 Jun 2025 07:44:19 GMT
Connection: keep-alive
ETag: "684fcb53-267"
Accept-Ranges: bytes

```

`Content-Length: 615` là kích thước tệp `/var/www/html/index.nginx-debian.html` của gói Nginx. Sau bước 5.4, trang này sẽ được thay bằng trang PTIT.

### 5.2. Tạo thư mục gốc và tệp `index.html`

Quy ước đặt mã nguồn web trong `/var/www/<tên-site>/html`. Thư mục tách riêng theo site giúp dễ phân quyền và dễ nhân bản thêm site sau này.

Quan sát trạng thái cấu hình mặc định trước khi thay đổi:

```text
devops@halo:~$ ls -l /etc/nginx/sites-enabled/
total 0
lrwxrwxrwx 1 root root 34 Oct  1 02:13 default -> /etc/nginx/sites-available/default
devops@halo:~$ ls -l /etc/nginx/sites-available/
total 4
-rw-r--r-- 1 root root 2412 Oct  1 02:13 default
```

Tạo thư mục, ghi tệp bằng `sudo tee` với heredoc (dấu nháy đơn quanh `'EOF'` ngăn shell thay thế biến và ký tự đặc biệt trong nội dung), sau đó đặt chủ sở hữu và quyền:

```text
devops@halo:~$ sudo mkdir -p /var/www/ptit-web/html
devops@halo:~$ ls -la /var/www/
total 16
drwxr-xr-x  4 root root 4096 Oct  1 02:18 .
drwxr-xr-x 13 root root 4096 Oct  1 02:13 ..
drwxr-xr-x  2 root root 4096 Oct  1 02:13 html
drwxr-xr-x  3 root root 4096 Oct  1 02:18 ptit-web
devops@halo:~$ sudo tee /var/www/ptit-web/html/index.html > /dev/null << 'EOF'
> ... (nội dung tệp index.html, xem bên dưới) ...
> EOF
devops@halo:~$ sudo chown -R www-data:www-data /var/www/ptit-web
devops@halo:~$ sudo find /var/www/ptit-web -type d -exec chmod 755 {} \;
devops@halo:~$ sudo find /var/www/ptit-web -type f -exec chmod 644 {} \;
devops@halo:~$ ls -l /var/www/ptit-web/html/
total 4
-rw-r--r-- 1 www-data www-data 1681 Oct  1 02:19 index.html
devops@halo:~$ file /var/www/ptit-web/html/index.html
/var/www/ptit-web/html/index.html: HTML document, Unicode text, UTF-8 text
devops@halo:~$ namei -l /var/www/ptit-web/html/index.html
f: /var/www/ptit-web/html/index.html
drwxr-xr-x root     root     /
drwxr-xr-x root     root     var
drwxr-xr-x root     root     www
drwxr-xr-x www-data www-data ptit-web
drwxr-xr-x www-data www-data html
-rw-r--r-- www-data www-data index.html
```

Giải thích:

- `mkdir -p` tạo cả thư mục cha `ptit-web` lẫn `html` và không báo lỗi nếu đã tồn tại.
- `tee ... > /dev/null` ghi nội dung nhận từ heredoc vào tệp bằng quyền root (vì `>` thông thường chạy bằng quyền của user `devops`, không ghi được vào `/var/www`). Phần `> /dev/null` để khỏi in lại nội dung ra màn hình.
- `chown -R www-data:www-data` giao thư mục cho user chạy worker của Nginx; thư mục `755` và tệp `644` đủ để `www-data` đọc và duyệt thư mục mà không cấp thừa quyền ghi cho người khác.
- `namei -l` liệt kê quyền của từng cấp thư mục trên đường dẫn. Điều kiện cần để Nginx đọc được tệp: **mọi thư mục cha phải có quyền `x` (duyệt)** cho `www-data`, và tệp phải có quyền `r`. Kết quả trên đều thỏa mãn.
- `file` xác nhận tệp là HTML, mã hóa UTF-8 (đúng với thẻ `<meta charset="utf-8">` và tiếng Việt có dấu trong nội dung).

Nội dung tệp [`index.html`](index.html):

```html
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PTIT DevOps Course - Session 02</title>
  <style>
    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background-color: #f3f5f8;
      color: #1f2933;
    }
    .container {
      max-width: 720px;
      margin: 12vh auto 0;
      padding: 32px 40px;
      background-color: #ffffff;
      border-top: 6px solid #c8102e;
      border-radius: 6px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.12);
    }
    h1 {
      margin-top: 0;
      font-size: 1.8rem;
      color: #c8102e;
    }
    p {
      line-height: 1.7;
    }
    code {
      padding: 2px 6px;
      background-color: #eef1f5;
      border-radius: 3px;
      font-size: 0.95em;
    }
    footer {
      margin-top: 28px;
      padding-top: 12px;
      border-top: 1px solid #d9dee5;
      font-size: 0.85rem;
      color: #52606d;
    }
  </style>
</head>
<body>
  <main class="container">
    <h1>Welcome to PTIT DevOps Course - Session 02</h1>
    <p>
      Đây là trang web tĩnh được phục vụ bởi Nginx trên Ubuntu Server 24.04 LTS,
      là sản phẩm của Bài 3 thuộc Session 02 trong khóa học DevOps tại Học viện
      Công nghệ Bưu chính Viễn thông (PTIT).
    </p>
    <p>
      Nội dung trang nằm tại <code>/var/www/ptit-web/html/index.html</code> và được
      truy cập thông qua Server Block <code>ptit-web.conf</code> lắng nghe ở cổng 80.
    </p>
    <footer>Nginx trên Ubuntu Server &middot; Cổng 80 (HTTP) &middot; Website tĩnh</footer>
  </main>
</body>
</html>
```

Điểm chính: khai báo `<!DOCTYPE html>` (HTML5), `lang="vi"`, `<meta charset="utf-8">` để trình duyệt hiển thị đúng tiếng Việt, thẻ `<title>`, thẻ `<h1>` chứa đúng dòng "Welcome to PTIT DevOps Course - Session 02", đoạn mô tả bằng tiếng Việt và CSS nội tuyến (khối `<style>`) đơn giản, không phụ thuộc tệp ngoài nên không phát sinh request phụ.

### 5.3. Tạo Server Block `ptit-web.conf`

Tạo tệp trong `sites-available` (chưa có hiệu lực cho đến khi được liên kết sang `sites-enabled`):

```text
devops@halo:~$ sudo tee /etc/nginx/sites-available/ptit-web.conf > /dev/null << 'EOF'
> ... (nội dung tệp ptit-web.conf, xem bên dưới) ...
> EOF
devops@halo:~$ ls -l /etc/nginx/sites-available/
total 8
-rw-r--r-- 1 root root 2412 Oct  1 02:13 default
-rw-r--r-- 1 root root 2674 Oct  1 02:23 ptit-web.conf
```

Nội dung tệp [`ptit-web.conf`](ptit-web.conf):

```nginx
# =============================================================================
# Tệp        : /etc/nginx/sites-available/ptit-web.conf
# Mục đích   : Server Block phục vụ website tĩnh "PTIT DevOps Course - Session 02"
# Môi trường : Ubuntu Server 24.04.3 LTS, Nginx 1.24.0 (repo mặc định của Ubuntu)
# Cách dùng  : Tạo symlink sang /etc/nginx/sites-enabled/ để kích hoạt, sau đó
#              chạy "sudo nginx -t" và "sudo systemctl reload nginx".
# =============================================================================

server {
    # listen: cổng (và địa chỉ) mà Nginx nhận kết nối HTTP.
    #   - "80" là cổng HTTP mặc định, lắng nghe trên mọi địa chỉ IPv4 của máy chủ.
    #   - "default_server" biến khối này thành server mặc định của cổng 80: mọi
    #     request không khớp server_name nào khác (ví dụ truy cập trực tiếp bằng
    #     địa chỉ IP 103.116.104.228) đều được chuyển vào khối này.
    listen 80 default_server;

    # Tương tự dòng trên nhưng cho IPv6 ("[::]" nghĩa là mọi địa chỉ IPv6).
    listen [::]:80 default_server;

    # server_name: tên miền mà khối này phục vụ. Hiện chưa có tên miền nên dùng
    # "_" (tên không hợp lệ, không trùng với bất kỳ Host nào). Khi truy cập bằng
    # IP, header Host chứa IP nên Nginx chọn khối mang cờ default_server.
    server_name _;

    # root: thư mục gốc chứa mã nguồn website. URI "/foo.html" sẽ được ánh xạ
    # thành tệp "<root>/foo.html" trên ổ đĩa.
    root /var/www/ptit-web/html;

    # index: danh sách tệp được trả về khi người dùng truy cập một thư mục,
    # ví dụ truy cập "/" sẽ trả về tệp index.html nằm trong thư mục root.
    index index.html;

    # access_log: ghi mỗi request (IP client, thời gian, URL, mã trạng thái...).
    # error_log : ghi lỗi của khối này (mặc định từ mức "error" trở lên).
    # Dùng tệp riêng để dễ tra cứu, không lẫn với log của các site khác.
    access_log /var/log/nginx/ptit-web.access.log;
    error_log /var/log/nginx/ptit-web.error.log;

    # location /: khối xử lý cho mọi đường dẫn bắt đầu bằng "/".
    location / {
        # try_files: lần lượt thử (1) tệp đúng bằng URI, (2) thư mục đúng bằng
        # URI (kèm index), (3) nếu cả hai không tồn tại thì trả về 404 Not Found.
        # Đây là cấu hình chuẩn cho website tĩnh.
        try_files $uri $uri/ =404;
    }
}
```

Ý nghĩa từng directive được giải thích ở mục 6.

### 5.4. Kích hoạt site và hủy kích hoạt cấu hình `default`

Kích hoạt bằng symlink (đường dẫn nguồn phải là đường dẫn tuyệt đối, nếu dùng đường dẫn tương đối thì symlink sẽ bị "gãy"):

```bash
sudo ln -s /etc/nginx/sites-available/ptit-web.conf /etc/nginx/sites-enabled/
```

Thử kiểm tra cú pháp **khi chưa hủy `default`** để thấy lỗi xung đột, sau đó gỡ symlink `default` và kiểm tra lại:

```text
devops@halo:~$ sudo ln -s /etc/nginx/sites-available/ptit-web.conf /etc/nginx/sites-enabled/
devops@halo:~$ ls -l /etc/nginx/sites-enabled/
total 0
lrwxrwxrwx 1 root root 34 Oct  1 02:13 default -> /etc/nginx/sites-available/default
lrwxrwxrwx 1 root root 40 Oct  1 02:24 ptit-web.conf -> /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t
nginx: [emerg] a duplicate default server for 0.0.0.0:80 in /etc/nginx/sites-enabled/ptit-web.conf:15
nginx: configuration file /etc/nginx/nginx.conf test failed
devops@halo:~$ sudo rm /etc/nginx/sites-enabled/default
devops@halo:~$ ls -l /etc/nginx/sites-enabled/ /etc/nginx/sites-available/
/etc/nginx/sites-available/:
total 8
-rw-r--r-- 1 root root 2412 Oct  1 02:13 default
-rw-r--r-- 1 root root 2674 Oct  1 02:23 ptit-web.conf

/etc/nginx/sites-enabled/:
total 0
lrwxrwxrwx 1 root root 40 Oct  1 02:24 ptit-web.conf -> /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

#### Vì sao phải hủy kích hoạt `default`

Tệp `sites-available/default` do Ubuntu tạo sẵn chứa `listen 80 default_server;` và `listen [::]:80 default_server;`. Mỗi cặp IP:cổng chỉ được có **một** `default_server`. Khi cả `default` và `ptit-web.conf` cùng được nạp, Nginx gặp hai khai báo `default_server` cho `0.0.0.0:80` và từ chối cấu hình:

```text
nginx: [emerg] a duplicate default server for 0.0.0.0:80 in /etc/nginx/sites-enabled/ptit-web.conf:15
nginx: configuration file /etc/nginx/nginx.conf test failed
```

Thông báo chỉ vào `ptit-web.conf:15` vì các tệp trong `sites-enabled/` được nạp theo thứ tự bảng chữ cái: `default` được nạp trước và chiếm vị trí `default_server`; khai báo thứ hai (dòng 15 của `ptit-web.conf`) bị coi là trùng lặp. Nếu để nguyên lỗi này mà chạy `reload`, cấu hình mới **không** được áp dụng và Nginx tiếp tục chạy bằng cấu hình cũ (xem mục 7.5).

Cách xử lý của bài: `sudo rm /etc/nginx/sites-enabled/default`. Lệnh này chỉ xóa **symlink**, tệp gốc `/etc/nginx/sites-available/default` vẫn còn để tham khảo hoặc bật lại khi cần (`ln -s` lại và bỏ `default_server` khỏi một trong hai tệp).

### 5.5. Kiểm tra cú pháp và reload

Luôn kiểm tra cú pháp trước khi reload:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

- `nginx -t` đọc toàn bộ cấu hình, kiểm tra cú pháp và thử mở các tệp/cổng cần thiết mà **không** áp dụng thay đổi. Cần `sudo` vì lệnh phải mở tệp log và tệp PID thuộc quyền root. Kết quả mong đợi gồm hai dòng: `syntax is ok` và `test is successful`.
- `systemctl reload nginx` gửi tín hiệu `SIGHUP` cho master: master nạp cấu hình mới, khởi động worker mới, rồi cho worker cũ kết thúc êm sau khi xử lý xong các kết nối đang mở. Nhờ vậy website **không bị gián đoạn**, khác với `restart` (dừng hẳn rồi chạy lại).

```text
devops@halo:~$ sudo systemctl reload nginx
devops@halo:~$ sudo systemctl status nginx --no-pager
* nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: enabled)
     Active: active (running) since Thu 2026-10-01 02:13:21 UTC; 12min ago
       Docs: man:nginx(8)
    Process: 4127 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 4129 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 4442 ExecReload=/usr/sbin/nginx -g daemon on; master_process on; -s reload (code=exited, status=0/SUCCESS)
   Main PID: 4130 (nginx)
      Tasks: 3 (limit: 2269)
     Memory: 2.7M (peak: 3.4M)
        CPU: 38ms
     CGroup: /system.slice/nginx.service
             ├─4130 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"
             ├─4443 "nginx: worker process"
             └─4444 "nginx: worker process"

Oct 01 02:13:21 halo systemd[1]: Starting nginx.service - A high performance web server and a reverse proxy server...
Oct 01 02:13:21 halo systemd[1]: Started nginx.service - A high performance web server and a reverse proxy server.
Oct 01 02:26:05 halo systemd[1]: Reloading nginx.service - A high performance web server and a reverse proxy server...
Oct 01 02:26:05 halo systemd[1]: Reloaded nginx.service - A high performance web server and a reverse proxy server.
devops@halo:~$ sudo nginx -T 2>/dev/null | grep -E '^\s*(listen|server_name|root)'
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/ptit-web/html;
```

Kết quả: master vẫn giữ PID 4130 (không restart), hai worker mới có PID 4443 và 4444, nhật ký `systemd` có dòng `Reloaded nginx.service`. Lệnh `nginx -T` (chữ T hoa) in cấu hình đầy đủ đang hiệu lực; lọc bằng `grep` cho thấy chỉ còn duy nhất một server block là `ptit-web`.

### 5.6. Kiểm tra kết quả

#### 5.6.1. Kiểm tra từ máy cá nhân bằng `curl`

```text
$ curl -I http://103.116.104.228
HTTP/1.1 200 OK
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 01 Oct 2026 02:27:14 GMT
Content-Type: text/html
Content-Length: 1681
Last-Modified: Thu, 01 Oct 2026 02:19:47 GMT
Connection: keep-alive
ETag: "6abdc343-691"
Accept-Ranges: bytes

$ curl http://103.116.104.228
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>PTIT DevOps Course - Session 02</title>
  <style>
    body {
      margin: 0;
      font-family: Arial, Helvetica, sans-serif;
      background-color: #f3f5f8;
      color: #1f2933;
    }
    .container {
      max-width: 720px;
      margin: 12vh auto 0;
      padding: 32px 40px;
      background-color: #ffffff;
      border-top: 6px solid #c8102e;
      border-radius: 6px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.12);
    }
    h1 {
      margin-top: 0;
      font-size: 1.8rem;
      color: #c8102e;
    }
    p {
      line-height: 1.7;
    }
    code {
      padding: 2px 6px;
      background-color: #eef1f5;
      border-radius: 3px;
      font-size: 0.95em;
    }
    footer {
      margin-top: 28px;
      padding-top: 12px;
      border-top: 1px solid #d9dee5;
      font-size: 0.85rem;
      color: #52606d;
    }
  </style>
</head>
<body>
  <main class="container">
    <h1>Welcome to PTIT DevOps Course - Session 02</h1>
    <p>
      Đây là trang web tĩnh được phục vụ bởi Nginx trên Ubuntu Server 24.04 LTS,
      là sản phẩm của Bài 3 thuộc Session 02 trong khóa học DevOps tại Học viện
      Công nghệ Bưu chính Viễn thông (PTIT).
    </p>
    <p>
      Nội dung trang nằm tại <code>/var/www/ptit-web/html/index.html</code> và được
      truy cập thông qua Server Block <code>ptit-web.conf</code> lắng nghe ở cổng 80.
    </p>
    <footer>Nginx trên Ubuntu Server &middot; Cổng 80 (HTTP) &middot; Website tĩnh</footer>
  </main>
</body>
</html>
```

Các điểm cần đối chiếu:

- `HTTP/1.1 200 OK`: request thành công.
- `Server: nginx/1.24.0 (Ubuntu)`: đúng phần mềm và phiên bản đã cài.
- `Content-Type: text/html`: Nginx suy ra từ đuôi `.html` theo `mime.types`.
- `Content-Length: 1681`: bằng đúng kích thước tệp `index.html` (1681 byte) ở bước 5.2, phân biệt với trang mặc định 615 byte.
- `Last-Modified` và `ETag` là thời điểm tạo tệp `index.html` (02:19:47 UTC), dùng cho cơ chế cache.
- Lệnh `curl http://103.116.104.228` in ra nguyên văn mã HTML của trang PTIT.

#### 5.6.2. Kiểm tra trên trình duyệt

Mở Chrome trên máy cá nhân và truy cập `http://103.116.104.228`. Kết quả quan sát được:

- Thanh địa chỉ hiển thị `103.116.104.228` kèm nhãn "Not secure" (Không bảo mật) vì đang dùng HTTP thuần, chưa có HTTPS; đây là hành vi bình thường ở giai đoạn này.
- Tab trình duyệt có tiêu đề "PTIT DevOps Course - Session 02".
- Nội dung là một thẻ trắng bo góc, viền trên màu đỏ, nền xám nhạt; tiêu đề lớn màu đỏ "Welcome to PTIT DevOps Course - Session 02"; hai đoạn mô tả tiếng Việt hiển thị đầy đủ dấu; chân trang nhỏ ghi "Nginx trên Ubuntu Server - Cổng 80 (HTTP) - Website tĩnh".
- Không còn trang "Welcome to nginx!" mặc định, chứng tỏ Server Block `ptit-web` đã thay thế cấu hình `default`.

#### 5.6.3. Kiểm tra nhật ký truy cập

```text
devops@halo:~$ sudo tail -n 3 /var/log/nginx/ptit-web.access.log
113.161.72.19 - - [01/Oct/2026:02:27:31 +0000] "GET / HTTP/1.1" 200 1681 "-" "curl/8.15.0"
113.161.72.19 - - [01/Oct/2026:02:28:49 +0000] "GET / HTTP/1.1" 200 1681 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
113.161.72.19 - - [01/Oct/2026:02:28:49 +0000] "GET /favicon.ico HTTP/1.1" 404 162 "http://103.116.104.228/" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/153.0.0.0 Safari/537.36"
devops@halo:~$ sudo ls -l /var/log/nginx/
total 8
-rw-r----- 1 www-data adm  89 Oct  1 02:15 access.log
-rw-r----- 1 www-data adm   0 Oct  1 02:13 error.log
-rw-r----- 1 www-data adm 594 Oct  1 02:28 ptit-web.access.log
-rw-r----- 1 www-data adm   0 Oct  1 02:25 ptit-web.error.log
devops@halo:~$ tail -n 1 /var/log/nginx/ptit-web.access.log
tail: cannot open '/var/log/nginx/ptit-web.access.log' for reading: Permission denied
```

Phân tích:

- Ba dòng cuối của `ptit-web.access.log` là: request `GET /` của `curl`, request `GET /` của Chrome (`200 1681`) và request `GET /favicon.ico` của Chrome (`404 162`). Trình duyệt luôn tự xin biểu tượng tab `favicon.ico`; trang không có nên Nginx trả 404 (162 byte là kích thước trang lỗi mặc định). Đây không phải lỗi của website.
- Các dòng log nằm trong `ptit-web.access.log` chứ không phải `access.log` nghĩa là request đã đi vào đúng Server Block. `access.log` chỉ còn một dòng cũ (lần kiểm tra trang mặc định ở 5.1).
- File log có quyền `640`, chủ sở hữu `www-data`, nhóm `adm`, nên user `devops` (không thuộc nhóm `adm`) phải dùng `sudo` mới đọc được; lệnh `tail` không có `sudo` báo `Permission denied`.
- `ptit-web.error.log` dài 0 byte: chưa có lỗi nào phát sinh.

---

## 6. Giải thích chi tiết Server Block `ptit-web.conf`

### 6.1. Bảng directive

| Directive | Giá trị | Ý nghĩa |
|---|---|---|
| `listen` | `80 default_server` | Nhận kết nối HTTP trên cổng 80 (mọi IPv4 của máy chủ); đánh dấu đây là server mặc định của cổng 80 |
| `listen` | `[::]:80 default_server` | Tương tự cho IPv6. Nếu thiếu dòng này thì truy cập bằng IPv6 sẽ không vào đúng block |
| `server_name` | `_` | Tên giữ chỗ không hợp lệ, không khớp bất kỳ `Host` nào; block được chọn nhờ `default_server` |
| `root` | `/var/www/ptit-web/html` | Thư mục gốc; URI `/a.html` ánh xạ thành `/var/www/ptit-web/html/a.html` |
| `index` | `index.html` | Tệp trả về khi URI trỏ tới thư mục, ví dụ `/` |
| `access_log` | `/var/log/nginx/ptit-web.access.log` | Nhật ký mỗi request của riêng site này |
| `error_log` | `/var/log/nginx/ptit-web.error.log` | Nhật ký lỗi của riêng site này (mức mặc định `error`) |
| `location /` | khối | Áp dụng cho mọi URI bắt đầu bằng `/` |
| `try_files` | `$uri $uri/ =404` | Thử tệp đúng bằng URI, rồi thư mục đúng bằng URI, nếu không có thì trả 404 |

Lưu ý: mọi câu lệnh cấu hình Nginx phải kết thúc bằng dấu chấm phẩy `;`, thiếu dấu này `nginx -t` sẽ báo lỗi cú pháp. Nội dung `ptit-web.conf` có chú thích tiếng Việt cho từng directive, bắt đầu bằng ký tự `#`.

### 6.2. Vì sao dùng `default_server` và `server_name _` khi truy cập bằng IP

1. **Truy cập bằng IP không có tên miền để so khớp.** Trình duyệt gửi `Host: 103.116.104.228`. Chưa có tên miền nên không có `server_name` nào trùng với giá trị này. Nginx khi đó rơi vào quy tắc "không khớp thì dùng server mặc định" của cặp IP:cổng.
2. **`default_server` chỉ định tường minh server mặc định.** Nếu không khai báo, Nginx dùng server *đầu tiên* được nạp làm mặc định. Vì `sites-enabled/*` được nạp theo thứ tự chữ cái, chỉ cần sau này có thêm một site tên `aaa.conf` thì site đó sẽ âm thầm "cướp" vai trò mặc định và trang PTIT biến mất khỏi địa chỉ IP. Khai báo `default_server` làm hành vi ổn định, không phụ thuộc thứ tự tên tệp.
3. **`server_name _` chỉ là quy ước.** Dấu gạch dưới không có ý nghĩa đặc biệt với Nginx; nó chỉ là một chuỗi không bao giờ trùng `Host` thật, cho thấy block này không gắn với tên miền cụ thể. Bỏ dòng `server_name` cũng chạy được (khi đó tên là chuỗi rỗng), nhưng khai báo rõ ràng giúp người đọc hiểu ý đồ.
4. **Hệ quả về xung đột:** vì mỗi cặp IP:cổng chỉ có một `default_server`, cấu hình `default` của Ubuntu (cũng khai báo `default_server`) phải bị hủy kích hoạt, nếu không sẽ gặp lỗi `a duplicate default server for 0.0.0.0:80`.
5. **Khi có tên miền:** thêm một server block riêng với `server_name example.com www.example.com;` (không cần `default_server`); block `ptit-web` tiếp tục phục vụ các request truy cập bằng IP hoặc bằng tên miền lạ.

### 6.3. Vì sao dùng `try_files $uri $uri/ =404`

Website tĩnh chỉ cần ánh xạ URI sang tệp. `try_files` tường minh hóa hành vi "có tệp thì trả, không có thì 404" và tránh chuyển tiếp request nhầm sang ứng dụng khác. So với cấu hình rỗng, nó cho thông báo 404 nhất quán và dễ mở rộng (ví dụ thay `=404` bằng `/index.html` khi triển khai ứng dụng một trang SPA).

---

## 7. Xử lý sự cố thường gặp

Bảng tóm tắt, chi tiết từng trường hợp ở các mục con bên dưới:

| Triệu chứng | Nguyên nhân thường gặp | Kiểm tra nhanh | Cách khắc phục |
|---|---|---|---|
| `403 Forbidden` | `www-data` không có quyền đọc tệp hoặc duyệt thư mục cha; thiếu `index.html` trong thư mục | `namei -l <đường dẫn>`, `sudo tail /var/log/nginx/ptit-web.error.log` | `chmod 755` cho thư mục, `chmod 644` cho tệp; `chown -R www-data:www-data` |
| `404 Not Found` | `root` sai đường dẫn, sai tên tệp (phân biệt hoa thường), thiếu tệp | `sudo nginx -T \| grep root`, `ls` thư mục thực tế | Sửa `root`, `nginx -t`, reload |
| Nginx không khởi động, `Address already in use` | Tiến trình khác (Apache, Nginx cũ...) đang giữ cổng 80 | `sudo ss -tlnp \| grep :80` | Dừng hoặc gỡ dịch vụ chiếm cổng, hoặc đổi cổng |
| Trình duyệt treo rồi báo timeout | Tường lửa (UFW hoặc Cloud Firewall) chặn cổng 80 | `sudo ufw status`, kiểm tra firewall trên Droplet | Mở cổng 80 (nội dung Bài 4) |
| Sửa cấu hình nhưng website không đổi | Chưa `reload` | `sudo nginx -t` rồi `sudo systemctl reload nginx` | Reload sau mỗi lần sửa cấu hình |
| `reload` không báo lỗi nhưng không đổi gì | Cấu hình sai cú pháp; `reload` không hiển thị lỗi | `sudo tail /var/log/nginx/error.log` | Chạy `nginx -t` trước, sửa lỗi rồi reload |

Các đoạn log dưới đây lấy từ phiên thực hành ở `terminal_log.txt` (phần 12 đến 15), trong đó sự cố được cố ý tạo ra rồi khôi phục về trạng thái đúng.

### 7.1. Lỗi `403 Forbidden` (sai quyền thư mục)

Nguyên nhân: worker chạy bằng `www-data` nhưng thư mục hoặc tệp không cho phép `www-data` đọc/duyệt. Tình huống hay gặp là đặt mã nguồn trong thư mục cá nhân (`/home/devops/...`, mặc định `750` hoặc `700`) hoặc chạy `chmod` sai. Ngoài ra, nếu thư mục không có `index.html` và không bật `autoindex`, Nginx trả 403 kèm log `directory index of "..." is forbidden`.

Tái hiện bằng cách đặt quyền `000` cho thư mục `html`:

```text
devops@halo:~$ sudo chmod 000 /var/www/ptit-web/html
devops@halo:~$ curl -I http://127.0.0.1
HTTP/1.1 403 Forbidden
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 01 Oct 2026 02:33:40 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive

devops@halo:~$ sudo tail -n 1 /var/log/nginx/ptit-web.error.log
2026/10/01 02:33:40 [error] 4443#4443: *6 open() "/var/www/ptit-web/html/index.html" failed (13: Permission denied), client: 127.0.0.1, server: _, request: "HEAD / HTTP/1.1", host: "127.0.0.1"
devops@halo:~$ sudo chmod 755 /var/www/ptit-web/html
devops@halo:~$ curl -sI http://127.0.0.1 | head -n 1
HTTP/1.1 200 OK
```

Dòng lỗi có `(13: Permission denied)`, nghĩa là lỗi quyền của hệ điều hành (errno 13). Khắc phục:

```bash
sudo chown -R www-data:www-data /var/www/ptit-web
sudo find /var/www/ptit-web -type d -exec chmod 755 {} \;
sudo find /var/www/ptit-web -type f -exec chmod 644 {} \;
namei -l /var/www/ptit-web/html/index.html    # mọi cấp phải có quyền x (duyệt) cho www-data
```

### 7.2. Lỗi `404 Not Found` (sai `root`)

Nguyên nhân: đường dẫn `root` sai chính tả (ví dụ thiếu chữ `l` thành `htm`), thư mục chưa được tạo, hoặc tên tệp sai hoa/thường (Linux phân biệt hoa thường: `Index.html` khác `index.html`). Điểm đáng chú ý: `nginx -t` **vẫn báo thành công** vì nó chỉ kiểm tra cú pháp, không kiểm tra thư mục `root` có thật hay không.

```text
devops@halo:~$ sudo sed -i 's#root /var/www/ptit-web/html;#root /var/www/ptit-web/htm;#' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
devops@halo:~$ sudo systemctl reload nginx
devops@halo:~$ curl -I http://127.0.0.1
HTTP/1.1 404 Not Found
Server: nginx/1.24.0 (Ubuntu)
Date: Thu, 01 Oct 2026 02:36:12 GMT
Content-Type: text/html
Content-Length: 162
Connection: keep-alive

devops@halo:~$ sudo tail -n 1 /var/log/nginx/ptit-web.access.log
127.0.0.1 - - [01/Oct/2026:02:36:12 +0000] "HEAD / HTTP/1.1" 404 0 "-" "curl/8.5.0"
devops@halo:~$ sudo nginx -T 2>/dev/null | grep -E '^\s*root'
    root /var/www/ptit-web/htm;
devops@halo:~$ ls /var/www/ptit-web/
html
devops@halo:~$ sudo sed -i 's#root /var/www/ptit-web/htm;#root /var/www/ptit-web/html;#' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t && sudo systemctl reload nginx
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
devops@halo:~$ curl -sI http://127.0.0.1 | head -n 1
HTTP/1.1 200 OK
```

Với `try_files ... =404`, một request trượt tệp không tạo dòng lỗi trong `error.log`; dấu vết nằm ở `access.log` (mã `404`). Cách dò lỗi: đối chiếu đường dẫn `root` trong cấu hình đang hiệu lực (`nginx -T`) với thư mục thực tế (`ls`).

### 7.3. Cổng 80 bị tiến trình khác chiếm

Triệu chứng: `systemctl start nginx` hoặc `reload` thất bại, `journalctl` có dòng `bind() to 0.0.0.0:80 failed (98: Address already in use)`. Nguyên nhân thường là Apache (`apache2`) được cài sẵn trên image, hoặc một bản Nginx/ứng dụng khác đang chạy. Kiểm tra bằng:

```bash
sudo ss -tlnp | grep :80
```

Ví dụ minh họa kết quả khi Apache đang giữ cổng (tên tiến trình ở cột cuối cho biết thủ phạm):

```text
LISTEN 0      511                *:80              *:*    users:(("apache2",pid=5021,fd=4),("apache2",pid=5020,fd=4))
```

Khắc phục: dừng và tắt dịch vụ chiếm cổng (`sudo systemctl disable --now apache2`), hoặc gỡ gói không cần thiết, hoặc đổi cổng của một trong hai dịch vụ; sau đó `sudo systemctl start nginx`. Có thể dùng `sudo lsof -i :80` làm cách kiểm tra thay thế.

### 7.4. Tường lửa chặn cổng 80

Triệu chứng: `systemctl status nginx` vẫn `active (running)`, `curl http://127.0.0.1` trên máy chủ trả 200, nhưng từ máy cá nhân trình duyệt chờ rất lâu rồi báo hết thời gian. Phân biệt các lỗi từ `curl` phía máy cá nhân (ví dụ minh họa):

```text
$ curl -I --connect-timeout 10 http://103.116.104.228
curl: (28) Failed to connect to 103.116.104.228 port 80 after 10002 ms: Timeout was reached
```

- `Timeout` (gói tin bị bỏ qua): thường do tường lửa chặn, gồm UFW trên máy chủ hoặc Cloud Firewall của nhà cung cấp Droplet.
- `Connection refused`: đến được máy chủ nhưng không có dịch vụ nào lắng nghe cổng 80 (Nginx chưa chạy hoặc đang nghe cổng khác).

Kiểm tra `sudo ufw status` (trong bài này là `inactive` nên không chặn). Khi đã bật UFW, cần cho phép cổng 80, ví dụ `sudo ufw allow 'Nginx HTTP'` hoặc `sudo ufw allow 80/tcp` (gói Nginx đã cài sẵn profile `Nginx HTTP`, `Nginx HTTPS`, `Nginx Full`). Cấu hình tường lửa chi tiết được thực hiện ở Bài 4.

### 7.5. Quên `reload` hoặc `reload` khi cấu hình sai

Nginx chỉ đọc cấu hình lúc khởi động hoặc khi nhận tín hiệu reload. Sửa tệp `.conf` mà không reload thì worker vẫn chạy cấu hình cũ. Thử nghiệm: thêm header `X-Served-By`, kiểm tra cú pháp nhưng chưa reload:

```text
devops@halo:~$ sudo sed -i '/^    index index.html;/a\    add_header X-Served-By ptit-web always;' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
devops@halo:~$ curl -sI http://127.0.0.1 | grep -i x-served-by
devops@halo:~$ echo $?
1
devops@halo:~$ sudo systemctl reload nginx
devops@halo:~$ curl -sI http://127.0.0.1 | grep -i x-served-by
X-Served-By: ptit-web
devops@halo:~$ sudo sed -i '/X-Served-By/d' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t && sudo systemctl reload nginx
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
devops@halo:~$ curl -sI http://127.0.0.1 | grep -ci x-served-by
0
```

Trước `reload`, `curl` không thấy header (mã thoát 1 của `grep`); sau `reload` header xuất hiện. Lưu ý: thay đổi trong `index.html` có hiệu lực ngay (Nginx đọc tệp mỗi request), chỉ thay đổi cấu hình `.conf` mới cần reload.

Trường hợp nguy hiểm hơn: **`systemctl reload` không báo lỗi dù cấu hình sai**, vì lệnh chỉ gửi tín hiệu cho master rồi kết thúc (mã thoát 0). Master thử nạp cấu hình mới, thất bại và âm thầm giữ cấu hình cũ, lỗi chỉ xuất hiện trong `error.log`:

```text
devops@halo:~$ sudo sed -i 's/^        try_files/        try_file/' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t
nginx: [emerg] unknown directive "try_file" in /etc/nginx/sites-enabled/ptit-web.conf:44
nginx: configuration file /etc/nginx/nginx.conf test failed
devops@halo:~$ sudo systemctl reload nginx
devops@halo:~$ echo $?
0
devops@halo:~$ sudo tail -n 1 /var/log/nginx/error.log
2026/10/01 02:41:07 [emerg] 4130#4130: unknown directive "try_file" in /etc/nginx/sites-enabled/ptit-web.conf:44
devops@halo:~$ curl -sI http://127.0.0.1 | head -n 1
HTTP/1.1 200 OK
devops@halo:~$ sudo sed -i 's/^        try_file /        try_files /' /etc/nginx/sites-available/ptit-web.conf
devops@halo:~$ sudo nginx -t && sudo systemctl reload nginx
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```

Đây là lý do của gợi ý trong đề bài: **luôn chạy `sudo nginx -t` trước khi reload**. Có thể gộp an toàn thành một dòng `sudo nginx -t && sudo systemctl reload nginx` (toán tử `&&` chỉ reload khi `nginx -t` thành công).

---

## 8. Script tự động hóa `deploy.sh`

[`deploy.sh`](deploy.sh) gom các bước ở mục 5 thành một lần chạy. Tính chất:

- `set -euo pipefail`: dừng ngay khi có lệnh lỗi, biến chưa khai báo hoặc lỗi trong pipeline.
- **Idempotent** (chạy nhiều lần cho cùng kết quả): chỉ cài Nginx nếu chưa có (`dpkg -s`), `mkdir -p`, `install` ghi đè tệp, `ln -sfn` tạo hoặc thay symlink, `rm -f` không báo lỗi nếu symlink `default` đã bị xóa.
- Tự nâng quyền bằng `sudo` nếu không chạy bằng root.
- Luôn chạy `nginx -t` trước `systemctl reload nginx`; nếu kiểm tra thất bại thì dừng, không reload.
- Cuối script tự kiểm tra bằng `curl` tới `127.0.0.1`: in dòng trạng thái HTTP và xác nhận trang chứa đúng dòng "Welcome to PTIT DevOps Course - Session 02".

Cách dùng: sao chép ba tệp `deploy.sh`, `ptit-web.conf`, `index.html` vào cùng một thư mục trên máy chủ rồi chạy:

```bash
chmod +x deploy.sh
./deploy.sh
```

Kết quả tương đương các bước thủ công, nhưng có thể lặp lại khi dựng máy chủ mới. Bài nộp này thực hiện thủ công từng bước (mục 5) để thể hiện rõ từng khái niệm; script là phần bổ sung.

---

## 9. Lưu ý bảo mật và hướng mở rộng

- **Chỉ dùng HTTP:** dữ liệu truyền không mã hóa và trình duyệt gắn nhãn "Not secure". Với website giới thiệu tĩnh, rủi ro thấp; khi có tên miền nên cấp chứng chỉ (Let's Encrypt/Certbot) và chuyển sang HTTPS cổng 443.
- **Ẩn phiên bản Nginx:** header `Server: nginx/1.24.0 (Ubuntu)` tiết lộ phiên bản. Có thể đặt `server_tokens off;` trong khối `http` của `/etc/nginx/nginx.conf` để ẩn số phiên bản (chưa áp dụng vì bài yêu cầu đối chiếu header).
- **Charset:** trang đã khai báo `<meta charset="utf-8">`. Có thể bổ sung `charset utf-8;` trong Nginx để header `Content-Type` cũng khai báo UTF-8; bài giữ mặc định `text/html` để đúng với kết quả kiểm tra của đề.
- **Quyền tối thiểu:** thư mục `755`, tệp `644`, không cấp quyền ghi cho nhóm/người khác; không chạy Nginx worker bằng root.
- **Tường lửa:** chỉ mở các cổng cần thiết (22, 80, 443) - nội dung Bài 4.
- **Quản lý cấu hình:** giữ `ptit-web.conf` trong Git và dùng `deploy.sh` để triển khai lặp lại thay vì chỉnh tay trên máy chủ.

---

## 10. Đối chiếu yêu cầu đề bài

| Yêu cầu | Cách thực hiện | Bằng chứng |
|---|---|---|
| Cài Nginx mới nhất từ repo mặc định Ubuntu | `sudo apt update && sudo apt install -y nginx` | Mục 5.1: `nginx/1.24.0 (Ubuntu)`, `Installed` trùng `Candidate` |
| Dịch vụ chạy và tự khởi động | `systemctl status`, `systemctl enable nginx` | `active (running)`, `enabled` |
| Thư mục `/var/www/ptit-web/html/` | `sudo mkdir -p /var/www/ptit-web/html` | Mục 5.2 |
| `index.html` hiển thị "Welcome to PTIT DevOps Course - Session 02" | Tạo bằng `sudo tee`; thẻ `<h1>` | Mục 5.2 và kết quả `curl` ở 5.6.1 |
| Server Block `/etc/nginx/sites-available/ptit-web.conf`, cổng 80, `root` đúng | Mục 5.3 | Tệp `ptit-web.conf` |
| Kích hoạt bằng symlink sang `sites-enabled` | `sudo ln -s ...` | Mục 5.4: `ls -l sites-enabled` |
| Xóa/hủy kích hoạt `default` | `sudo rm /etc/nginx/sites-enabled/default` (giữ tệp gốc) | Mục 5.4, giải thích lỗi `duplicate default server` |
| `sudo nginx -t` báo syntax ok | Chạy trước khi reload | Mục 5.4 và 5.5: hai dòng `syntax is ok`, `test is successful` |
| `sudo systemctl reload nginx` | Reload không gián đoạn | Mục 5.5: master giữ nguyên PID |
| Mở `http://<IP>` thấy trang PTIT | `curl` và Chrome | Mục 5.6: `200 OK`, nội dung HTML, mô tả trình duyệt |
| Nộp `ptit-web.conf` và `index.html` tại `homework/session_02/ex3/` | Xem mục 11 | Thư mục bài nộp |

---

## 11. Cấu trúc bài nộp

```text
DevOps-Session2-bai3/
|-- README.md                               # tiêu đề, mô tả ngắn, mục lục
`-- homework/
    `-- session_02/
        `-- ex3/
            |-- README.md                   # báo cáo này
            |-- ptit-web.conf               # Server Block Nginx
            |-- index.html                  # trang web tĩnh
            |-- deploy.sh                   # script triển khai idempotent
            `-- terminal_log.txt            # toàn bộ log Terminal
```

Khi đẩy lên GitHub, đường dẫn nộp là `homework/session_02/ex3/`. Ví dụ các lệnh Git (thực hiện khi đã có kho chứa của môn học):

```bash
git add homework/session_02/ex3/
git commit -m "homework(session_02): ex3 - nginx static website"
git push origin main
```

Đối chiếu toàn vẹn: giá trị SHA-256 của hai tệp trên máy chủ (`/etc/nginx/sites-available/ptit-web.conf`, `/var/www/ptit-web/html/index.html`) trùng với tệp trong thư mục bài nộp (xem cuối `terminal_log.txt`):

```text
3b019b434fb92f881f852a90a215f4f9197945be910b6cea40a735bca3648c17  ptit-web.conf
477c82365cefc507f42158b755751603e8533a809e5a3b299c7ce9ec1bf0e8a0  index.html
```

---

## 12. Tài liệu tham khảo

- Nginx - How nginx processes a request: https://nginx.org/en/docs/http/request_processing.html
- Nginx - Server names: https://nginx.org/en/docs/http/server_names.html
- Nginx - Module ngx_http_core_module (`listen`, `root`, `try_files`, `location`): https://nginx.org/en/docs/http/ngx_http_core_module.html
- Nginx - Beginner's Guide: https://nginx.org/en/docs/beginners_guide.html
- Nginx - Controlling nginx (tín hiệu reload): https://nginx.org/en/docs/control.html
- Ubuntu Server documentation - Web servers: https://documentation.ubuntu.com/server/
