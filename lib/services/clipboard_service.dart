import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Service để xử lý sao chép vào clipboard trên nhiều nền tảng
class ClipboardService {
  /// Sao chép nội dung vào clipboard
  static Future<bool> copyToClipboard(BuildContext context, String text) async {
    bool success = false;
    
    try {
      // Sử dụng Clipboard API chuẩn của Flutter (hoạt động trên hầu hết các nền tảng)
      await Clipboard.setData(ClipboardData(text: text));
      success = true;
      
      // Hiển thị thông báo đã sao chép thành công
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã sao chép vào clipboard'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      // Xử lý lỗi nếu có
      final message = 'Không thể sao chép: $e';
      success = false;
      
      // Hiển thị lỗi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    return success;
  }
}