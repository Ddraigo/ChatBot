import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DeepInfraService {
  static const String _apiKey =
      'hsRbY93uPGEk9xRkuNiQqCx6oE4c7F9l'; // 👈 thay bằng key của bạn
  bool _isOffline = false;

  Future<bool> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void _showOfflineToast(BuildContext? context) {
    if (!_isOffline) {
      _isOffline = true;
      Fluttertoast.showToast(
        msg: "Mất kết nối mạng. Bạn đang ở chế độ offline.",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<String> sendMessage(String message, [BuildContext? context]) async {
    bool isConnected = await _checkConnectivity();

    if (!isConnected) {
      _showOfflineToast(context);
      return "⚠️ Không thể kết nối. Vui lòng kiểm tra lại mạng.";
    }

    _isOffline = false;

    try {
      const url = 'https://api.deepinfra.com/v1/openai/chat/completions';

      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              "model": "mistralai/Mistral-7B-Instruct-v0.1",
              "messages": [
                {"role": "user", "content": message}
              ],
              "temperature": 0.7,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'].toString();
      } else {
        return '❌ Lỗi từ server: ${response.body}';
      }
    } on SocketException {
      _showOfflineToast(context);
      return "⚠️ Không thể kết nối đến server.";
    } on TimeoutException {
      return "⚠️ Server phản hồi chậm. Thử lại sau.";
    } catch (e) {
      return "⚠️ Đã xảy ra lỗi: $e";
    }
  }
}
