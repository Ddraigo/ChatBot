# ChatMini

Ứng dụng ChatBot được phát triển bằng Flutter với khả năng trò chuyện, hiển thị Markdown và code highlighting.

## Thiết lập môi trường

### Yêu cầu hệ thống
- Flutter SDK (phiên bản 3.6.0 trở lên)
- Dart SDK (phiên bản 3.0.0 trở lên)
- Android Studio / Visual Studio Code
- JDK (phiên bản 11 trở lên - cho Android development)
- Xcode (nếu phát triển trên iOS)

### Cài đặt Flutter
1. Tải và cài đặt Flutter SDK từ [trang chính thức](https://flutter.dev/docs/get-started/install)
2. Thêm Flutter vào PATH của hệ thống
3. Chạy lệnh `flutter doctor` để kiểm tra và cài đặt các thành phần còn thiếu

### Cài đặt các công cụ phát triển
- Android Studio: [Tải tại đây](https://developer.android.com/studio)
- Visual Studio Code: [Tải tại đây](https://code.visualstudio.com/)
  - Cài đặt extension Flutter và Dart cho VS Code

## Khởi tạo dự án

### Tải mã nguồn
```bash
git clone <repository-url>
cd chatbot
```

### Cài đặt các dependencies
```bash
flutter pub get
```

## Cấu hình API Key

Dự án sử dụng Gemini API:

1. Tạo tài khoản tại [Gemini](https://ai.google.dev/)
2. Lấy API key
3. Tạo file `.env` tại thư mục gốc dự án với nội dung:
```
DEEPINFRA_API_KEY=your_api_key_here
```

## Chạy ứng dụng

### Khởi chạy trên thiết bị phát triển
```bash
flutter run
```

### Build cho các nền tảng

#### Android
```bash
flutter build apk --release
```
File APK sẽ được tạo tại `build/app/outputs/flutter-apk/app-release.apk`

#### iOS
```bash
flutter build ios --release
```
Mở file `ios/Runner.xcworkspace` và xuất bản thông qua Xcode

#### Web
```bash
flutter build web --release
```
Output sẽ nằm tại thư mục `build/web`

#### Windows
```bash
flutter build windows --release
```
Output sẽ nằm tại thư mục `build/windows/runner/Release`

## Các tính năng chính
- Giao diện trò chuyện thân thiện
- Hỗ trợ hiển thị Markdown với syntax highlighting
- Lưu và quản lý lịch sử trò chuyện
- Tùy chỉnh tên cuộc trò chuyện
- Giao diện responsive trên các thiết bị

## Cấu trúc dự án
- `lib/main.dart`: Entry point của ứng dụng
- `lib/chat_screen.dart`: Màn hình chính của ứng dụng
- `lib/services/`: Chứa các service tương tác với API và chức năng hỗ trợ
  - `deepinfra_service.dart`: Tương tác với DeepInfra API (đây là API dự trù do Gemini hiện đang bảo trì)
  - `gemini_service.dart` : Tương tác với Gemini API
  - `clipboard_service.dart`: Hỗ trợ sao chép nội dung
  - `storage_service.dart`: Quản lý lưu trữ cuộc trò chuyện

## Xử lý sự cố
- Nếu gặp lỗi "Failed to connect to DeepInfra API": Kiểm tra API key và kết nối internet
- Nếu gặp lỗi khi build: Chạy `flutter clean` và sau đó `flutter pub get`
- Nếu gặp sự cố với plugin: Thử chạy `flutter pub upgrade`

## Hướng dẫn sử dụng
- Tạo cuộc trò chuyện mới: Nhấn vào nút "+" ở sidebar
- Đổi tên cuộc trò chuyện: Nhấn vào dấu ":" và chọn "Đổi tên"
- Xóa cuộc trò chuyện: Nhấn vào dấu ":" và chọn "Xóa"
- Sao chép nội dung: Nhấn vào biểu tượng sao chép bên dưới tin nhắn
