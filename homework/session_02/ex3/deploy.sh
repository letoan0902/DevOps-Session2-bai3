#!/usr/bin/env bash
# =============================================================================
# deploy.sh - Triển khai website tĩnh PTIT trên Nginx (Bài 3, Session 02)
#
# Script gom toàn bộ các bước thủ công thành một lần chạy và có tính idempotent:
# chạy lại nhiều lần vẫn cho cùng một kết quả, không báo lỗi khi tài nguyên
# đã tồn tại.
#
# Cách dùng (đặt script cùng thư mục với ptit-web.conf và index.html):
#     chmod +x deploy.sh
#     ./deploy.sh
# Script tự nâng quyền bằng sudo nếu không chạy bằng root.
# =============================================================================

set -euo pipefail

# ----------------------------- Biến cấu hình ---------------------------------
SITE_NAME="ptit-web"
WEB_ROOT="/var/www/${SITE_NAME}/html"
SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
CONF_DST="${SITES_AVAILABLE}/${SITE_NAME}.conf"
EXPECTED_TEXT="Welcome to PTIT DevOps Course - Session 02"

# Thư mục chứa script, dùng để tìm ptit-web.conf và index.html đi kèm.
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ------------------------------ Hàm tiện ích ---------------------------------
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
fail() { printf '[LỖI] %s\n' "$*" >&2; exit 1; }

# ------------------------- Bước 0: kiểm tra điều kiện ------------------------
# Cần quyền root để cài gói và ghi vào /etc/nginx, /var/www.
if [[ ${EUID} -ne 0 ]]; then
    log "Không chạy bằng root, chạy lại script với sudo..."
    exec sudo -E bash "${BASH_SOURCE[0]}" "$@"
fi

[[ -f "${SRC_DIR}/${SITE_NAME}.conf" ]] || fail "Không tìm thấy ${SRC_DIR}/${SITE_NAME}.conf"
[[ -f "${SRC_DIR}/index.html" ]]        || fail "Không tìm thấy ${SRC_DIR}/index.html"

# ------------------------- Bước 1: cài đặt Nginx -----------------------------
if dpkg -s nginx >/dev/null 2>&1; then
    log "Nginx đã được cài đặt: $(nginx -v 2>&1)"
else
    log "Cài đặt Nginx từ repo mặc định của Ubuntu..."
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y nginx
fi

# Bật khởi động cùng hệ thống và đảm bảo dịch vụ đang chạy.
systemctl enable nginx >/dev/null 2>&1
systemctl is-active --quiet nginx || systemctl start nginx

# --------------------- Bước 2: thư mục gốc và index.html ---------------------
log "Tạo thư mục gốc ${WEB_ROOT}..."
mkdir -p "${WEB_ROOT}"

log "Triển khai index.html..."
install -m 644 -o www-data -g www-data "${SRC_DIR}/index.html" "${WEB_ROOT}/index.html"

# Thư mục 755, tệp 644 để user www-data (worker của Nginx) đọc được.
chown -R www-data:www-data "/var/www/${SITE_NAME}"
find "/var/www/${SITE_NAME}" -type d -exec chmod 755 {} +
find "/var/www/${SITE_NAME}" -type f -exec chmod 644 {} +

# ----------------------- Bước 3: cài đặt Server Block ------------------------
log "Cài đặt ${CONF_DST}..."
install -m 644 -o root -g root "${SRC_DIR}/${SITE_NAME}.conf" "${CONF_DST}"

# ------------------------- Bước 4: kích hoạt site ----------------------------
# ln -sfn: tạo mới hoặc ghi đè symlink, chạy lại không gây lỗi "File exists".
log "Kích hoạt site bằng symlink trong ${SITES_ENABLED}..."
ln -sfn "${CONF_DST}" "${SITES_ENABLED}/${SITE_NAME}.conf"

# Hủy kích hoạt cấu hình default để tránh xung đột default_server trên cổng 80.
# Chỉ xóa symlink, giữ nguyên tệp gốc trong sites-available để tham khảo.
if [[ -e "${SITES_ENABLED}/default" || -L "${SITES_ENABLED}/default" ]]; then
    log "Hủy kích hoạt cấu hình default..."
    rm -f "${SITES_ENABLED}/default"
fi

# ------------------------- Bước 5: kiểm tra và reload ------------------------
# Luôn kiểm tra cú pháp trước khi reload. Nếu lỗi, set -e dừng script và Nginx
# tiếp tục chạy với cấu hình cũ.
log "Kiểm tra cú pháp cấu hình (nginx -t)..."
nginx -t || fail "Cấu hình Nginx không hợp lệ, không reload."

log "Reload Nginx..."
systemctl reload nginx

# --------------------------- Bước 6: kiểm tra kết quả ------------------------
log "Kiểm tra phản hồi HTTP tại http://127.0.0.1 ..."
STATUS_LINE="$(curl -fsI http://127.0.0.1/ | head -n 1 | tr -d '\r')"
log "Dòng trạng thái: ${STATUS_LINE}"

# Lưu nội dung vào biến trước khi grep để tránh lỗi SIGPIPE khi bật pipefail.
PAGE_BODY="$(curl -fsS http://127.0.0.1/)"
if grep -q "${EXPECTED_TEXT}" <<< "${PAGE_BODY}"; then
    log "Thành công: trang web hiển thị đúng dòng \"${EXPECTED_TEXT}\"."
else
    fail "Trang web không chứa nội dung mong đợi \"${EXPECTED_TEXT}\"."
fi

log "Hoàn tất. Truy cập http://<IP-máy-chủ> từ máy cá nhân để kiểm tra."
