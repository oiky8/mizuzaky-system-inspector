# Mizuzaky System Inspector

Linh vật trên màn hình Windows, kiểm tra sức khỏe hệ thống định kỳ với mức tải thấp và chẩn đoán an toàn.

> **Bản thử nghiệm:** Dự án dùng một số quy tắc kiểm tra cố định. Đây chưa phải trợ lý AI và không thể chẩn đoán hoặc sửa an toàn mọi lỗi Windows.

## Tính năng

- Kiểm tra dung lượng ổ đĩa, phân giải DNS và kết nối Internet.
- Đọc lỗi gần đây trong nhật ký **System** và **Application** của Windows rồi đối chiếu với [`error-catalog.json`](./error-catalog.json).
- Kiểm tra lần đầu khi khởi động ứng dụng, sau đó mỗi 3 giờ.
- Hoãn kiểm tra 15 phút nếu CPU từ 70% trở lên hoặc RAM trống dưới 1,5 GB.
- Chỉ đặt tiến trình của linh vật ở mức ưu tiên `BelowNormal`; không đóng hoặc thay đổi mức ưu tiên ứng dụng khác.
- Thử làm mới bộ nhớ đệm DNS nếu phân giải tên miền thất bại. Đây là thao tác sửa tự động duy nhất trong bản thử nghiệm.
- Chỉ mở tìm kiếm Microsoft Learn khi người dùng bấm nút. Ứng dụng chỉ gửi mã sự kiện chung, không gửi nội dung nhật ký.
- Ghi nhật ký cục bộ tại `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

Kho lỗi là tập mẫu ban đầu có thể chỉnh sửa, không phải thư viện toàn diện. Ứng dụng không tải hoặc chạy mã sửa lỗi từ kết quả trên mạng.

## Yêu cầu

- Windows có Windows PowerShell 5.1 và WPF.
- Tài khoản người dùng thông thường, không có quyền quản trị viên.
- Đặt `mizuzaky-system-inspector.ps1` và `error-catalog.json` cùng một thư mục.

## Chạy

Mở PowerShell trong thư mục dự án và chạy:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1"
```

Chọn **Start with Windows** trong ứng dụng để thêm hoặc gỡ shortcut ở Startup của người dùng hiện tại. Ứng dụng chạy sau khi người dùng đăng nhập, không chạy trước màn hình đăng nhập.

## An toàn và giới hạn

- Không tự động xóa tệp.
- Không sửa registry, đổi cài đặt bảo mật, cài/gỡ phần mềm, can thiệp tiến trình khác hoặc khởi động lại Windows.
- Thiếu dung lượng và đa số lỗi hệ thống, driver, bảo mật, phần cứng hay ứng dụng chỉ được báo cáo, không tự sửa.
- Mỗi nhật ký chỉ quét tối đa 100 sự kiện gần nhất và chỉ xét lỗi trong 24 giờ qua.
- Chạy bằng tài khoản thông thường. Ứng dụng từ chối khởi động nếu chạy với quyền quản trị viên.

See the [English README](./README.md) for the project overview in English.
