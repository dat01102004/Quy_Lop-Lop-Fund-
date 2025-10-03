
## 2) `quylop/README.md` (Flutter App)

```markdown
# Lop Fund – Flutter App

Ứng dụng Flutter quản lý quỹ lớp: hoá đơn, kỳ thu, nộp & duyệt phiếu, khoản chi, báo cáo…

## Yêu cầu
- Flutter 3.x
- Android Studio / Xcode (tuỳ nền tảng build)

## Cấu hình API
Sửa base URL trong file cấu hình (ví dụ `lib/services/env.dart`):

```dart
// ví dụ
const String apiBaseUrl = 'http://10.0.2.2:8000'; // Android emulator
// hoặc: const apiBaseUrl = 'http://127.0.0.1:8000'; // iOS simulator
// hoặc IP LAN/ngrok nếu cần
```
API chạy Laravel ở thư mục lopfund-api/ (xem README của backend).
- Cài đặt & chạy
```
flutter pub get
flutter run
```
build
```
# Android (apk debug)
flutter build apk

# iOS (yêu cầu macOS)
flutter build ios
```
- Tính năng chính:
  - Đăng ký / đăng nhập (Sanctum)
  - Tạo lớp, tham gia lớp bằng mã
  - Quản lý kỳ thu, phát hoá đơn cho thành viên
  - Nộp phiếu & upload ảnh chứng từ, duyệt phiếu
  - Danh sách đã duyệt (lọc theo kỳ)
  - Khoản chi, báo cáo kỳ thu, số dư lớp (summary)
- Lưu ý mạng
  - Android Emulator dùng http://10.0.2.2:<port> trỏ về máy host.
  - Dùng HTTP (không HTTPS) có thể cần:
    - android:usesCleartextTraffic="true" trong AndroidManifest.xml
- Troubleshoot
  - 401/403: thiếu header Authorization: Bearer <token> → kiểm tra chức năng đăng nhập/hydrate.
  - Không load được ảnh chứng từ: backend phải storage:link và trả URL public.
  - Timeout: kiểm tra apiBaseUrl đúng (localhost/10.0.2.2/IP/ngrok).
- Cấu trúc thư mục
```
lib/
├─ screens/        # UI trang: home, invoices, payments, fee report...
├─ repos/          # Repositories (dio)
├─ services/       # dioProvider, session, env...
└─ main.dart
```
- Đóng góp
  - Tạo nhánh từ main, mở Pull Request.
  - Không commit file build: build/, .dart_tool/, .idea/ (đã ignore).
