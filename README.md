# VinaKey

Bộ gõ tiếng Việt cho macOS của Vina Design Store, phát triển từ [OpenKey](https://github.com/tuyenvm/OpenKey). Engine macOS được chuyển sang Rust; giao diện dùng AppKit và các biểu mẫu SwiftUI gốc.

## Sử dụng

- Chọn **ABC**, **VNI**, **Telex**, **Simple Telex 1** hoặc **Simple Telex 2** trong thanh menu. ABC tạm ngừng xử lý tiếng Việt và giữ kiểu gõ gần nhất.
- Cài đặt gồm **Chung**, **Gõ tiếng Việt**, **Ứng dụng** và **Giới thiệu**. Các tùy chọn tương thích nằm trong Chung.
- Cho phép quyền Trợ năng khi ứng dụng yêu cầu. Dùng nguồn nhập ABC của macOS để tránh hai bộ gõ cùng xử lý.
- Chuyển mã văn bản đã sao chép qua menu **Chuyển mã văn bản…**.
- Gõ tắt dùng tính năng Thay thế văn bản của macOS; VinaKey không cung cấp trình quản lý riêng.

## Build

Cài Xcode và Rust qua rustup. Phiên bản Rust cùng hai kiến trúc được ghim trong `rust-toolchain.toml`.

```sh
xcodebuild -project Sources/OpenKey/macOS/OpenKey.xcodeproj -scheme OpenKey \
  -configuration Release -derivedDataPath /tmp/vinakey-build \
  CODE_SIGNING_ALLOWED=NO MACOSX_DEPLOYMENT_TARGET=12.0 build
```

Kết quả: `/tmp/vinakey-build/Build/Products/Release/VinaKey.app`. Tên scheme/thư mục nội bộ OpenKey được giữ để bảo toàn cấu trúc dự án. Bundle ID của ứng dụng là `com.vinadesignstore.vinakey`, tách biệt với OpenKey.

```sh
sh scripts/check-macos-input.sh
cargo test --locked --manifest-path Sources/OpenKey/engine-rust/Cargo.toml
python3 scripts/check-rust-engine.py
```

## Trạng thái

Bản xem trước mã nguồn, chưa phải bản phát hành ổn định. Build universal arm64/x86_64 đã được kiểm tra với Xcode 27.2 và deployment target macOS 12; hệ thống cũ hơn chưa được kiểm tra thực tế. Giao diện SwiftUI grouped form dùng từ macOS 13; hệ thống cũ dùng AppKit.

Các kiểm tra native không thay thế kiểm tra bàn phím thật. Hành vi khôi phục ngôn ngữ qua ứng dụng và menu thanh trạng thái vẫn cần kiểm tra trực tiếp. Chưa triển khai quy trình ký Developer ID, notarization và phát hành. Kiểm tra cập nhật mở trang Releases của VinaKey, không tải bộ cập nhật OpenKey. Mở cùng macOS dùng SMAppService từ macOS 13, không cần helper riêng. macOS 12 có thể thêm ứng dụng vào Mục đăng nhập thủ công. Xem [RELEASE.md](RELEASE.md) để build gói xem trước và chuẩn bị ký/notarize; chưa có bản phát hành công khai đã ký.

Mã Windows/Linux gốc được giữ trong lịch sử/cây nguồn và không được phát hành dưới tên VinaKey trong bản này.

## Nguồn gốc và giấy phép

VinaKey được phân phối theo [GNU GPL v3](LICENSE). Xem [NOTICE.md](NOTICE.md) để biết nguồn gốc, bản quyền và các thay đổi. Các thông báo bản quyền gốc trong mã nguồn được giữ nguyên.
