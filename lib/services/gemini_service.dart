import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyD7cddYXTNDfPiELvaeH0fE_Tr7TSynklw';
  bool _isOffline = false;

  // Kiểm tra kết nối mạng
  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Hiển thị thông báo offline
  void _showOfflineToast(BuildContext? context) {
    // Nếu chưa hiển thị thông báo offline
    if (!_isOffline) {
      _isOffline = true;
      Fluttertoast.showToast(
        msg: "Đang ở chế độ offline. Bạn vẫn có thể xem lại các cuộc trò chuyện cũ.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        timeInSecForIosWeb: 3,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0
      );
    }
  }

  Future<String> sendMessage(String message, [BuildContext? context]) async {
    // Kiểm tra kết nối mạng trước khi gửi request
    bool isConnected = await _checkConnectivity();
    
    if (!isConnected) {
      _showOfflineToast(context);
      return "⚠️ Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng và thử lại sau.";
    }

    // Đặt lại trạng thái offline nếu đã kết nối lại
    _isOffline = false;

    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': message}
              ]
            }
          ]
        }),
      ).timeout(const Duration(seconds: 30)); // Thêm timeout

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        return 'Lỗi từ API: ${response.body}';
      }
    } on SocketException catch (_) {
      _showOfflineToast(context);
      return "⚠️ Không thể kết nối đến server. Vui lòng kiểm tra kết nối mạng và thử lại sau.";
    } on TimeoutException catch (_) {
      return "⚠️ Kết nối đến server quá chậm. Vui lòng thử lại sau.";
    } catch (e) {
      return "⚠️ Có lỗi xảy ra: $e";
    }
  }
}
