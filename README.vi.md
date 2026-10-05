# Mizuzaky System Inspector

Linh vật trên màn hình Windows, kiểm tra sức khỏe hệ thống định kỳ với mức tải thấp và chẩn đoán an toàn.

> **Bản thử nghiệm:** Dự án dùng một số quy tắc kiểm tra cố định. Đây chưa phải trợ lý AI và không thể chẩn đoán hoặc sửa an toàn mọi lỗi Windows.

## Đọc README bằng ngôn ngữ của bạn

[English](./README.md) · **Tiếng Việt** · [简体中文](https://translate.google.com/translate?sl=auto&tl=zh-CN&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [繁體中文](https://translate.google.com/translate?sl=auto&tl=zh-TW&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Español](https://translate.google.com/translate?sl=auto&tl=es&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Français](https://translate.google.com/translate?sl=auto&tl=fr&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Deutsch](https://translate.google.com/translate?sl=auto&tl=de&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [日本語](https://translate.google.com/translate?sl=auto&tl=ja&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [한국어](https://translate.google.com/translate?sl=auto&tl=ko&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Português](https://translate.google.com/translate?sl=auto&tl=pt&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Русский](https://translate.google.com/translate?sl=auto&tl=ru&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [العربية](https://translate.google.com/translate?sl=auto&tl=ar&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [हिन्दी](https://translate.google.com/translate?sl=auto&tl=hi&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [Bahasa Indonesia](https://translate.google.com/translate?sl=auto&tl=id&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector) · [ไทย](https://translate.google.com/translate?sl=auto&tl=th&u=https%3A%2F%2Fgithub.com%2Foiky8%2Fmizuzaky-system-inspector)

GitHub hiển thị README dưới dạng Markdown tĩnh nên không tự chọn bản dịch theo ngôn ngữ trình duyệt. Hãy chọn ngôn ngữ ở trên hoặc dùng chức năng **Dịch trang** tích hợp trong trình duyệt để tự dịch theo ngôn ngữ bạn dùng. Nếu bấm liên kết Google Translate, dịch vụ này sẽ nhận URL repository công khai.

## Tính năng

- Kiểm tra dung lượng ổ đĩa, phân giải DNS và kết nối Internet.
- Đọc lỗi gần đây trong nhật ký **System** và **Application** của Windows rồi đối chiếu với [`error-catalog.json`](./error-catalog.json).
- Tự chọn giao diện theo ngôn ngữ hiển thị Windows: tiếng Việt, tiếng Trung giản thể/phồn thể, Tây Ban Nha, Pháp, Đức, Nhật, Hàn, Bồ Đào Nha, Nga, Ả Rập, Hindi, Indonesia hoặc Thái; ngôn ngữ khác dùng English dự phòng. Tiếng Ả Rập hiển thị từ phải sang trái. Nội dung giao diện nằm trong [`locales.json`](./locales.json) để có thể bổ sung bản dịch.
- Nhận diện công cụ phổ biến có trên `PATH`: Python, Node.js (JavaScript/TypeScript), Java, .NET (bao gồm C#), Go, Rust, PHP, Ruby, Perl, Lua, R, Swift và bộ công cụ C/C++. Ứng dụng báo cáo sự kiện crash liên quan trong Windows nhưng không chạy runtime.
- Theo dõi thay đổi chỉ trong `Downloads`, `Desktop` và `Documents` của người dùng hiện tại trên ổ NTFS nội bộ. Chỉ xếp hàng các loại tệp mã nguồn, tệp thực thi và ZIP được hỗ trợ; bỏ qua thư mục phụ thuộc/build/cache như `.git`, `node_modules`, `vendor`, `bin`, `obj`. Tệp có dấu Windows tải từ Internet được kiểm tra dấu nguồn; tệp thực thi được hỗ trợ sẽ được kiểm tra trạng thái chữ ký Authenticode. Mã nguồn thay đổi trong Git working tree nằm trong các thư mục này được dò một danh sách ngắn mẫu mã rủi ro. Với ZIP có dấu tải Internet, ứng dụng đọc một số mục mã nguồn nhỏ trực tiếp mà không giải nén. Chỉ báo dấu hiệu theo heuristic; không sửa, chạy, cách ly hay tải tệp/mã nguồn lên mạng.
- Kiểm tra lần đầu khi khởi động ứng dụng, sau đó mỗi 3 giờ.
- Hoãn kiểm tra 15 phút nếu CPU từ 70% trở lên hoặc RAM trống dưới 1,5 GB.
- Chỉ đặt tiến trình của linh vật ở mức ưu tiên `BelowNormal`; không đóng hoặc thay đổi mức ưu tiên ứng dụng khác.
- Có thể tự chạy một sửa chữa rủi ro thấp nằm trong danh sách cho phép: làm mới bộ nhớ đệm DNS nếu DNS lỗi trong khi kết nối trực tiếp bằng IP vẫn hoạt động. Ứng dụng dùng lệnh Windows `ipconfig` có tài liệu chính thức, kiểm tra lại kết quả và ghi nguồn Microsoft vào báo cáo.
- Gửi báo cáo lỗi qua email khi đã cấu hình SMTP. Báo cáo chỉ chứa tóm tắt, không gửi nội dung đầy đủ của sự kiện Windows; lỗi không đổi sẽ không bị gửi lặp lại liên tục.
- Chỉ mở tìm kiếm web khi người dùng bấm nút. Từ khóa chỉ là nhóm lỗi chung hoặc mã sự kiện Windows; không gồm mã nguồn, đường dẫn tệp hay nội dung sự kiện thô. Nhà cung cấp tìm kiếm vẫn nhận từ khóa và metadata kết nối thông thường. Kết quả tìm kiếm là thông tin chưa được xác minh; hãy kiểm tra nguồn và đừng chạy script/lệnh tải về chỉ vì trang web đề xuất.
- Ghi nhật ký cục bộ tại `%LOCALAPPDATA%\MizuzakySystemInspector\assistant.log`.

Kho lỗi là tập mẫu ban đầu có thể chỉnh sửa, không phải thư viện toàn diện. Kiểm tra tệp chỉ là heuristic tĩnh nhẹ, không thay thế antivirus, không phải kiểm toán bảo mật đầy đủ và không chứng minh tệp an toàn; vẫn cần Windows Defender hoặc antivirus đáng tin cậy khác. Chữ ký Authenticode hợp lệ không chứng minh phần mềm an toàn; phần mềm không ký cũng không tự động là mã độc. Theo dõi chỉ bắt đầu khi ứng dụng chạy và chỉ bao phủ `Downloads`, `Desktop`, `Documents` của người dùng hiện tại trên ổ NTFS nội bộ. Không bao gồm tệp ở nơi khác (kể cả Git repo ngoài các thư mục này), ổ mạng/di động/không phải NTFS, tệp đã có trước lúc khởi động hoặc tệp tải về không có dấu Internet Zone của Windows. Mã nguồn Git chỉ được xem xét khi ứng dụng nhận được sự kiện thay đổi; tải hệ thống cao hoặc tràn bộ đệm thông báo có thể làm chậm/bỏ lỡ kiểm tra. Không đọc mã nguồn lớn hơn 256 KB, không kiểm tra chữ ký tệp thực thi lớn hơn 100 MB và không kiểm tra ZIP lớn hơn 50 MB; trong ZIP chỉ xem tối đa 50 mục mã nhỏ. API tải dữ liệu mạng và API thực thi mã động được báo riêng như dấu hiệu yếu; chỉ riêng sự hiện diện của chúng không chứng minh hành vi độc hại. Email không chứa mã nguồn và chỉ báo số lượng. Nhận diện runtime chỉ giới hạn ở các bộ công cụ đã liệt kê và sự kiện crash Windows ghi nhận. Kết quả heuristic có thể báo nhầm hoặc bỏ sót. Tìm kiếm web chỉ mở khi người dùng bấm nút và chỉ dùng nhóm lỗi/mã sự kiện chung, không gửi mã nguồn hay đường dẫn cục bộ. Kết quả tìm kiếm chưa được xác minh, không tự tải hoặc chạy để sửa lỗi. Lỗi chưa biết, rủi ro cao hoặc có thể ảnh hưởng thành phần khác sẽ chỉ được báo cáo để chủ máy xem xét.

## Yêu cầu

- Windows có Windows PowerShell 5.1 và WPF.
- Tài khoản người dùng thông thường, không có quyền quản trị viên.
- Đặt `mizuzaky-system-inspector.ps1`, `error-catalog.json` và `locales.json` cùng một thư mục.

## Chạy

Mở PowerShell trong thư mục dự án và chạy:

```powershell
powershell.exe -NoProfile -STA -File ".\mizuzaky-system-inspector.ps1"
```

Chọn **Start with Windows** trong ứng dụng để thêm hoặc gỡ shortcut ở Startup của người dùng hiện tại. Ứng dụng chạy sau khi người dùng đăng nhập, không chạy trước màn hình đăng nhập.

Ứng dụng không bỏ qua Execution Policy của PowerShell. Nếu chính sách chặn script, hãy dùng bản đã ký được phê duyệt hoặc hỏi quản trị viên; không tự làm yếu chính sách do tổ chức quản lý.

## Báo cáo qua email

Để cấu hình email, chạy script trong PowerShell tương tác:

```powershell
powershell.exe -NoProfile -STA -File ".\mizuzaky-system-inspector.ps1" -ConfigureEmail
```

Nhập tên máy chủ SMTP công khai của nhà cung cấp, cổng `587`, địa chỉ người gửi/người nhận và tên đăng nhập/mật khẩu ứng dụng SMTP. Ứng dụng từ chối địa chỉ IP, tên máy chủ nội bộ, cổng khác 587 và địa chỉ email kèm tên hiển thị. Ứng dụng dùng SMTP xác thực qua STARTTLS, yêu cầu TLS 1.2 và kiểm tra chứng thư máy chủ/tên máy chủ bằng xác thực chuẩn của Windows/.NET; chứng thư không hợp lệ hoặc tự ký sẽ bị từ chối. Nhà cung cấp không hỗ trợ STARTTLS cổng 587 sẽ không dùng được.

Mật khẩu SMTP được Windows DPAPI bảo vệ theo tài khoản hiện tại. Ứng dụng đặt ACL chỉ cho tài khoản hiện tại và SYSTEM trên thư mục dữ liệu, cấu hình email, thông tin xác thực, nhật ký và trạng thái chống gửi lặp; đồng thời từ chối tệp cấu hình là reparse point. Trạng thái chống gửi lặp cũng được DPAPI mã hóa; giới hạn tối đa một email mỗi giờ và không gửi lại cùng tóm tắt trong 24 giờ. Phần nội dung báo cáo chỉ gồm thời gian và số lượng vấn đề; không gồm tên máy, địa chỉ người nhận, nội dung sự kiện thô, đường dẫn tệp hay mã nguồn. Phần tiêu đề email vẫn hiển thị người gửi và người nhận đã cấu hình. Số lượng vấn đề theo ngôn ngữ giao diện Windows đã chọn.

Các bảo vệ này giúp hạn chế rủi ro từ tài khoản Windows khác và kết nối truyền tải không an toàn; chúng không thể bảo vệ bí mật trước mã độc đang chạy dưới chính tài khoản Windows của bạn, nhà cung cấp email bị xâm nhập hoặc hộp thư người nhận bị chiếm. Email cần mạng và SMTP xác thực hỗ trợ STARTTLS cổng 587. Nếu cấu hình hoặc xác minh chứng thư thất bại, ứng dụng từ chối gửi và báo lỗi cục bộ.

## An toàn và giới hạn

- Không tự động xóa tệp người dùng. Sửa chữa tự động duy nhất là làm mới bộ nhớ đệm DNS có nguồn chính thức như mô tả ở trên.
- Theo dõi tệp chỉ đọc metadata cục bộ và mã nguồn được hỗ trợ để dò heuristic; không chạy, xóa, cách ly hay tải mã nguồn lên mạng. Có thể có cảnh báo nhầm hoặc bỏ sót.
- Không sửa registry, đổi cài đặt bảo mật, cài/gỡ phần mềm, can thiệp tiến trình khác hoặc khởi động lại Windows.
- Thiếu dung lượng và đa số lỗi hệ thống, driver, bảo mật, phần cứng hay ứng dụng chỉ được báo cáo, không tự sửa.
- Mỗi nhật ký chỉ quét tối đa 100 sự kiện gần nhất và chỉ xét lỗi trong 24 giờ qua.
- Chạy bằng tài khoản thông thường. Ứng dụng từ chối khởi động nếu chạy với quyền quản trị viên.

See the [English README](./README.md) for the project overview in English.
