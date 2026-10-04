# Linh vật quản lý máy Windows (bản thử nghiệm)

Đây là một ứng dụng PowerShell cục bộ có linh vật trên màn hình. Bản hiện tại dùng các quy tắc kiểm tra cố định, **chưa phải mô hình AI** và không gửi dữ liệu ra dịch vụ bên ngoài.

## Chạy

1. Lưu `linh-vat-may-tinh.ps1` vào một thư mục cố định trên máy Windows.
2. Mở PowerShell bằng tài khoản thông thường, không chọn “Run as administrator”.
3. Chạy:

   ```powershell
   powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\linh-vat-may-tinh.ps1"
   ```

4. Chọn **Start with Windows** trong cửa sổ linh vật để chạy tự động khi người dùng đăng nhập Windows. Ứng dụng không chạy trước màn hình đăng nhập.

## Bản này làm gì

- Kiểm tra dung lượng ổ đĩa và báo khi còn dưới 5 GB.
- Kiểm tra lần đầu sau khi cửa sổ hiện lên, sau đó chạy kiểm tra đầy đủ mỗi 3 giờ; khi CPU từ 70% trở lên hoặc RAM trống dưới 1.5 GB, hoãn kiểm tra 15 phút rồi đánh giá lại.
- Tự đặt tiến trình linh vật ở mức ưu tiên `BelowNormal`; không đổi mức ưu tiên hay đóng ứng dụng khác. Nút **Check now** cũng tuân theo điều kiện tải thấp.
- Chỉ đo mức tải hệ thống trước mỗi lần kiểm tra; nếu Windows không cung cấp được số đo, linh vật hoãn thay vì chạy kiểm tra nặng khi chưa biết trạng thái máy.
- Nếu DNS lỗi, thử xóa bộ nhớ đệm DNS (không xóa tệp người dùng) rồi kiểm tra lại.
- Đọc tối đa 100 sự kiện lỗi gần nhất trong nhật ký System và Application, chỉ xét 24 giờ vừa qua; so khớp với `error-catalog.json`.
- Nút **Search Microsoft docs** chỉ mở tra cứu khi được bấm và chỉ gửi mã nhật ký/sự kiện chung, không gửi nội dung nhật ký.
- Ghi nhật ký tại `%LOCALAPPDATA%\LinhVatMayTinh\assistant.log`.
- Không tự xóa tệp, sửa registry, thay đổi cài đặt bảo mật, cài/gỡ phần mềm hoặc khởi động lại máy. Việc gỡ shortcut khởi động cũng cần xác nhận.

`error-catalog.json` là kho mẫu ban đầu có thể mở rộng; nó chưa phải thư viện lớn/đầy đủ và không thể bao quát mọi cấu hình Windows. Tài liệu trực tuyến chỉ được tra cứu thủ công qua Microsoft Learn; ứng dụng không tải hay chạy mã sửa lỗi từ Internet.

Không thể tự động chẩn đoán và sửa an toàn mọi lỗi Windows. Các lỗi registry, bảo mật, driver và phần cứng hiện chỉ cần được xử lý sau khi có chẩn đoán cụ thể; không nên cấp quyền quản trị toàn phần cho một trình sửa lỗi tự động.
