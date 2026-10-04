# Mizuzaky System Inspector

Linh vật trên màn hình Windows, kiểm tra sức khỏe hệ thống định kỳ với mức tải thấp và chẩn đoán an toàn.

> **Bản thử nghiệm:** Dự án dùng một số quy tắc kiểm tra cố định. Đây chưa phải trợ lý AI và không thể chẩn đoán hoặc sửa an toàn mọi lỗi Windows.

## Tính năng

- Kiểm tra dung lượng ổ đĩa, phân giải DNS và kết nối Internet.
- Đọc lỗi gần đây trong nhật ký **System** và **Application** của Windows rồi đối chiếu với [`error-catalog.json`](./error-catalog.json).
- Tự chọn giao diện theo ngôn ngữ hiển thị Windows: tiếng Việt, tiếng Trung giản thể/phồn thể, Tây Ban Nha, Pháp, Đức, Nhật, Hàn, Bồ Đào Nha, Nga, Ả Rập, Hindi, Indonesia hoặc Thái; ngôn ngữ khác dùng English dự phòng. Tiếng Ả Rập hiển thị từ phải sang trái. Nội dung giao diện nằm trong [`locales.json`](./locales.json) để có thể bổ sung bản dịch.
- Nhận diện công cụ phổ biến có trên `PATH`: Python, Node.js (JavaScript/TypeScript), Java, .NET (bao gồm C#), Go, Rust, PHP, Ruby, Perl, Lua, R, Swift và bộ công cụ C/C++. Ứng dụng báo cáo sự kiện crash liên quan trong Windows, nhưng không chạy runtime, quét dự án hay đọc mã nguồn.
- Kiểm tra lần đầu khi khởi động ứng dụng, sau đó mỗi 3 giờ.
- Hoãn kiểm tra 15 phút nếu CPU từ 70% trở lên hoặc RAM trống dưới 1,5 GB.
- Chỉ đặt tiến trình của linh vật ở mức ưu tiên `BelowNormal`; không đóng hoặc thay đổi mức ưu tiên ứng dụng khác.
- Có thể tự chạy một sửa chữa rủi ro thấp nằm trong danh sách cho phép: làm mới bộ nhớ đệm DNS nếu DNS lỗi trong khi kết nối trực tiếp bằng IP vẫn hoạt động. Ứng dụng dùng lệnh Windows `ipconfig` có tài liệu chính thức, kiểm tra lại kết quả và ghi nguồn Microsoft vào báo cáo.
- Gửi báo cáo lỗi qua email khi đã cấu hình SMTP. Báo cáo chỉ chứa tóm tắt, không gửi nội dung đầy đủ của sự kiện Windows; lỗi không đổi sẽ không bị gửi lặp lại liên tục.
- Chỉ mở tìm kiếm Microsoft Learn khi người dùng bấm nút. Ứng dụng chỉ gửi mã sự kiện chung, không gửi nội dung nhật ký.
- Ghi nhật ký cục bộ tại `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

Kho lỗi là tập mẫu ban đầu có thể chỉnh sửa, không phải thư viện toàn diện. Hỗ trợ ngôn ngữ lập trình giới hạn ở các bộ công cụ đã liệt kê và sự kiện crash Windows ghi lại; không ứng dụng hữu hạn nào nhận diện được mọi ngôn ngữ lập trình. Linh vật không phải trình biên dịch, trình gỡ lỗi hay công cụ quét dự án. Giao diện hỗ trợ các ngôn ngữ đã liệt kê ở trên; ngôn ngữ Windows khác chuyển sang English. Ứng dụng không tải hoặc chạy kết quả tìm kiếm hay mã sửa lỗi từ Internet. Lỗi chưa biết, rủi ro cao hoặc có thể ảnh hưởng thành phần khác sẽ chỉ được báo cáo để chủ máy xem xét.

## Yêu cầu

- Windows có Windows PowerShell 5.1 và WPF.
- Tài khoản người dùng thông thường, không có quyền quản trị viên.
- Đặt `mizuzaky-system-inspector.ps1`, `error-catalog.json` và `locales.json` cùng một thư mục.

## Chạy

Mở PowerShell trong thư mục dự án và chạy:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1"
```

Chọn **Start with Windows** trong ứng dụng để thêm hoặc gỡ shortcut ở Startup của người dùng hiện tại. Ứng dụng chạy sau khi người dùng đăng nhập, không chạy trước màn hình đăng nhập.

## Báo cáo qua email

Để cấu hình email, chạy script trong PowerShell tương tác:

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\mizuzaky-system-inspector.ps1" -ConfigureEmail
```

Nhập tên máy chủ SMTP công khai của nhà cung cấp, cổng `587`, địa chỉ người gửi/người nhận và tên đăng nhập/mật khẩu ứng dụng SMTP. Ứng dụng từ chối địa chỉ IP, tên máy chủ nội bộ, cổng khác 587 và địa chỉ email kèm tên hiển thị. Ứng dụng dùng SMTP xác thực qua STARTTLS, yêu cầu TLS 1.2 và kiểm tra chứng thư máy chủ/tên máy chủ bằng xác thực chuẩn của Windows/.NET; chứng thư không hợp lệ hoặc tự ký sẽ bị từ chối. Nhà cung cấp không hỗ trợ STARTTLS cổng 587 sẽ không dùng được.

Mật khẩu SMTP được Windows DPAPI bảo vệ theo tài khoản hiện tại. Ứng dụng đặt ACL chỉ cho tài khoản hiện tại và SYSTEM trên thư mục dữ liệu, cấu hình email, thông tin xác thực, nhật ký và trạng thái chống gửi lặp; đồng thời từ chối tệp cấu hình là reparse point. Trạng thái chống gửi lặp cũng được DPAPI mã hóa; giới hạn tối đa một email mỗi giờ và không gửi lại cùng tóm tắt trong 24 giờ. Phần nội dung báo cáo chỉ gồm thời gian và số lượng vấn đề; không gồm tên máy, địa chỉ người nhận, nội dung sự kiện thô, đường dẫn tệp hay mã nguồn. Phần tiêu đề email vẫn hiển thị người gửi và người nhận đã cấu hình. Số lượng vấn đề theo ngôn ngữ giao diện Windows đã chọn.

Các bảo vệ này giúp hạn chế rủi ro từ tài khoản Windows khác và kết nối truyền tải không an toàn; chúng không thể bảo vệ bí mật trước mã độc đang chạy dưới chính tài khoản Windows của bạn, nhà cung cấp email bị xâm nhập hoặc hộp thư người nhận bị chiếm. Email cần mạng và SMTP xác thực hỗ trợ STARTTLS cổng 587. Nếu cấu hình hoặc xác minh chứng thư thất bại, ứng dụng từ chối gửi và báo lỗi cục bộ.

## An toàn và giới hạn

- Không tự động xóa tệp người dùng. Sửa chữa tự động duy nhất là làm mới bộ nhớ đệm DNS có nguồn chính thức như mô tả ở trên.
- Không sửa registry, đổi cài đặt bảo mật, cài/gỡ phần mềm, can thiệp tiến trình khác hoặc khởi động lại Windows.
- Thiếu dung lượng và đa số lỗi hệ thống, driver, bảo mật, phần cứng hay ứng dụng chỉ được báo cáo, không tự sửa.
- Mỗi nhật ký chỉ quét tối đa 100 sự kiện gần nhất và chỉ xét lỗi trong 24 giờ qua.
- Chạy bằng tài khoản thông thường. Ứng dụng từ chối khởi động nếu chạy với quyền quản trị viên.

See the [English README](./README.md) for the project overview in English.
