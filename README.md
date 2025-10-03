# Lop_Fund

Monorepo chứa cả **API (Laravel)** và **App (Flutter)**.

## Cấu trúc
Lop_Fund/
-  ├─ quylop/ # Flutter app
-  └─ lopfund-api/ # Laravel API
---

## Yêu cầu
- Flutter 3.x (kèm Dart SDK)
- PHP 8.2+, Composer 2.x
- MySQL/MariaDB
- (Tùy chọn) ngrok để expose API

---

## 1) Backend (Laravel)

```bash
cd lopfund-api
cp .env.example .env            # nếu chưa có .env.example thì tạo theo mẫu bên dưới
composer install
php artisan key:generate
# Tạo database trống rồi chỉnh các biến DB_* trong .env
php artisan migrate --seed
php artisan serve               # chạy ở http://127.0.0.1:8000
```
Lưu ý: API dùng Sanctum. Nếu gọi từ Android emulator, Flutter nên trỏ tới http://10.0.2.2:8000.

.env.example mẫu (nếu thiếu):
```
APP_NAME=LopFund
APP_ENV=local
APP_KEY=
APP_DEBUG=true
APP_URL=http://127.0.0.1:8000

LOG_CHANNEL=stack
LOG_LEVEL=debug

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=lopfund
DB_USERNAME=root
DB_PASSWORD=

BROADCAST_DRIVER=log
CACHE_DRIVER=file
FILESYSTEM_DISK=public
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

SANCTUM_STATEFUL_DOMAINS=localhost,127.0.0.1
```
2) Frontend (Flutter)

```bash
cd quylop
flutter pub get
# Sửa file cấu hình base URL (lib/services/env.dart hoặc tương đương) thành:
# const API_BASE_URL = 'http://10.0.2.2:8000';
flutter run
Ghi chú base URL:
Máy thật & API cùng LAN: dùng IP máy chạy API, ví dụ http://192.168.1.10:8000.
Android Emulator: dùng http://10.0.2.2:8000.
```
3) Expose API ra ngoài (tùy chọn, ngrok)
```
ngrok http 8000
Lấy URL ngrok (ví dụ https://abcd-xyz.ngrok-free.app) gán vào API_BASE_URL của app.

Thư mục quan trọng
lopfund-api/routes/api.php – Khai báo API.

lopfund-api/app/Http/Controllers – Controllers.

quylop/lib/ – mã nguồn Flutter.

quylop/lib/services – cấu hình Dio, session, env…
```
Lệnh nhanh
Laravel

```bash
php artisan migrate:fresh --seed
php artisan serve
Flutter
```
```bash
flutter clean
flutter pub get
flutter run
Đóng góp
Tạo nhánh từ main, mở Pull Request.
```
Đừng commit file bí mật: lopfund-api/.env, file build, thư mục vendor/, build/, ios/Pods/ (đã ignore).
