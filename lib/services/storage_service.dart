import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Service quản lý lưu trữ các cuộc trò chuyện
class StorageService {
  static const String _chatStorageKey = 'chat_data';
  static const String _lastUpdateKey = 'last_update';

  /// Lưu tất cả cuộc trò chuyện vào bộ nhớ cục bộ
  Future<bool> saveChats(Map<String, List<Map<String, String>>> allChats) async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // Chuyển đổi dữ liệu thành JSON để lưu trữ
      final Map<String, dynamic> chatData = {};
      allChats.forEach((chatId, messages) {
        chatData[chatId] = messages;
      });
      
      final String chatJson = jsonEncode(chatData);
      final bool success = await prefs.setString(_chatStorageKey, chatJson);
      
      // Lưu thời gian cập nhật cuối cùng
      if (success) {
        await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      }
      
      return success;
    } catch (e) {
      print('Lỗi khi lưu cuộc trò chuyện: $e');
      return false;
    }
  }

  /// Tải tất cả cuộc trò chuyện từ bộ nhớ cục bộ
  Future<Map<String, List<Map<String, String>>>> loadChats() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? chatJson = prefs.getString(_chatStorageKey);
      
      if (chatJson == null) {
        return {};
      }
      
      final Map<String, dynamic> chatData = jsonDecode(chatJson);
      final Map<String, List<Map<String, String>>> result = {};
      
      chatData.forEach((chatId, messages) {
        final List<Map<String, String>> chatMessages = [];
        
        // Chuyển đổi dynamic list thành List<Map<String, String>>
        for (var message in (messages as List)) {
          chatMessages.add({
            'role': message['role'] as String,
            'content': message['content'] as String,
          });
        }
        
        result[chatId] = chatMessages;
      });
      
      return result;
    } catch (e) {
      print('Lỗi khi tải cuộc trò chuyện: $e');
      return {};
    }
  }

  /// Xóa tất cả cuộc trò chuyện khỏi bộ nhớ
  Future<bool> clearAllChats() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatStorageKey);
      await prefs.remove(_lastUpdateKey);
      return true;
    } catch (e) {
      print('Lỗi khi xóa cuộc trò chuyện: $e');
      return false;
    }
  }

  /// Kiểm tra xem có lưu trữ cuộc trò chuyện nào không
  Future<bool> hasSavedChats() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_chatStorageKey);
    } catch (e) {
      print('Lỗi khi kiểm tra cuộc trò chuyện: $e');
      return false;
    }
  }

  /// Lấy thời gian cập nhật cuối cùng
  Future<DateTime?> getLastUpdateTime() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? lastUpdate = prefs.getString(_lastUpdateKey);
      
      if (lastUpdate != null) {
        return DateTime.parse(lastUpdate);
      }
      return null;
    } catch (e) {
      print('Lỗi khi lấy thời gian cập nhật: $e');
      return null;
    }
  }
}