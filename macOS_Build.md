# Build VinaKey cho macOS

Xem [README.md](README.md#build) để build ứng dụng `VinaKey.app` bằng scheme nội bộ `OpenKey`. Rust toolchain và hai kiến trúc được chỉ định trong `rust-toolchain.toml`; Xcode tự build và liên kết Rust.

Chi tiết engine, lệnh kiểm tra và các giới hạn kiểm thử nằm tại [engine-rust/README.md](Sources/OpenKey/engine-rust/README.md).

Ứng dụng dùng bundle ID `com.vinadesignstore.vinakey`, có miền cài đặt và quyền Trợ năng riêng với OpenKey. Không tự sao chép cài đặt hoặc quyền từ ứng dụng cũ. Build cục bộ chưa ký Developer ID/notarize, không phải bản phát hành để phân phối rộng rãi.
