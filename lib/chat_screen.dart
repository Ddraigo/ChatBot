import 'package:chatbot/services/deepinfra_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'services/gemini_service.dart';
import 'services/clipboard_service.dart';
import 'services/storage_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart'; // Added for RawKeyboardListener

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  //final GeminiService _chatService = GeminiService();
  final DeepInfraService _chatService = DeepInfraService();
  final StorageService _storageService = StorageService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();
  bool isProcessing = false; // Theo dõi trạng thái xử lý yêu cầu
  Map<String, List<Map<String, String>>> allChats = {};
  String currentChatId = '';
  int chatCounter = 0;
  bool canSendMessage = false;
  bool _isSidebarVisible = true;

  void _sendMessage() async {
    if (isProcessing || !canSendMessage) return;

    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty || currentChatId.isEmpty) return;

    bool isFirstMessage = allChats[currentChatId]!.isEmpty;

    // Xóa nội dung TextField ngay lập tức và cập nhật trạng thái
    setState(() {
      allChats[currentChatId]!.add({'role': 'user', 'content': userMessage});
      isProcessing = true;
      canSendMessage = false;
      _controller.clear(); // Xóa ngay tại đây
    });

    _scrollToBottom();
    _saveChats();

    try {
      _textFieldFocusNode.unfocus();
    } catch (e) {
      if (kDebugMode) {
        print("Focus error ignored: $e");
      }
    }

    // Nếu là tin nhắn đầu tiên, đổi tên đoạn chat
    if (isFirstMessage) {
      String newTitle = await _generateChatTitle(userMessage);
      setState(() {
        allChats[newTitle] = allChats[currentChatId]!;
        allChats.remove(currentChatId);
        currentChatId = newTitle;
      });
      _saveChats();
    }

    try {
      String botResponse = await _chatService.sendMessage(userMessage, context);

      setState(() {
        allChats[currentChatId]!.add({'role': 'bot', 'content': botResponse});
      });

      _saveChats();
    } catch (e) {
      if (kDebugMode) {
        print("Error sending message: $e");
      }
      setState(() {
        allChats[currentChatId]!.add({
          'role': 'bot',
          'content': 'Lỗi khi xử lý yêu cầu. Vui lòng thử lại.'
        });
      });
    } finally {
      setState(() {
        isProcessing = false;
        canSendMessage = _controller.text.trim().isNotEmpty;
      });
      _scrollToBottom();
      _textFieldFocusNode.requestFocus();
    }
  }

  Future<String> _generateChatTitle(String message) async {
    try {
      String prompt =
          'Tóm tắt câu hỏi sau thành một tiêu đề ngắn gọn (tối đa 30 ký tự, không dùng định dạng Markdown): "$message"';
      String summary = await _chatService.sendMessage(prompt, context);
      // Loại bỏ ký tự Markdown như ** hoặc * nếu có
      String cleanedSummary = summary.replaceAll(RegExp(r'[*_#]'), '').trim();
      // Cắt ngắn nếu vượt quá 30 ký tự
      if (cleanedSummary.length > 30) {
        cleanedSummary = '${cleanedSummary.substring(0, 27).trim()}...';
      }
      return cleanedSummary.isNotEmpty ? cleanedSummary : 'Chat $chatCounter';
    } catch (e) {
      if (kDebugMode) {
        print("Error generating title: $e");
      }
      // Fallback: Lấy 30 ký tự đầu
      const maxLength = 30;
      String trimmedMessage = message.trim();
      if (trimmedMessage.length <= maxLength) {
        return trimmedMessage.isNotEmpty ? trimmedMessage : 'Chat $chatCounter';
      }
      return '${trimmedMessage.substring(0, maxLength).trim()}...';
    }
  }

  void _createNewChat() {
    setState(() {
      chatCounter++;
      currentChatId = 'Chat $chatCounter';
      allChats[currentChatId] = [];
    });

    _saveChats();
  }

  Future<void> _saveChats() async {
    await _storageService.saveChats(allChats);
  }

  Future<void> _loadChats() async {
    final savedChats = await _storageService.loadChats();
    if (savedChats.isNotEmpty) {
      setState(() {
        allChats = savedChats;
        currentChatId = allChats.keys.last;
        chatCounter = allChats.keys.length;
      });
    } else {
      _createNewChat();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print("Scroll error ignored: $e");
        }
      }
    });
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadChats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _textFieldFocusNode.unfocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _textFieldFocusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool isDesktopMode(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }

  void _deleteChat(String chatId) {
  setState(() {
    allChats.remove(chatId);
    // Nếu đoạn chat bị xóa là đoạn chat hiện tại, chuyển về đoạn chat khác
    if (chatId == currentChatId) {
      if (allChats.isNotEmpty) {
        currentChatId = allChats.keys.last; // Chuyển về đoạn chat cuối cùng
      } else {
        chatCounter = 0; // Reset chatCounter nếu không còn đoạn chat
        _createNewChat(); // Tạo đoạn chat mới
      }
    }
  });

  _saveChats();

  // Tự động focus vào TextField sau khi xóa
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _textFieldFocusNode.requestFocus();
  });
}

  void _renameChat(String oldChatId, String newTitle) {
    if (newTitle.isEmpty || oldChatId == newTitle || allChats.containsKey(newTitle)) return;
    
    setState(() {
      // Lưu messages của chat cũ
      final messages = allChats[oldChatId]!;
      // Xóa chat cũ
      allChats.remove(oldChatId);
      // Tạo chat mới với tên mới
      allChats[newTitle] = messages;
      
      // Nếu đang ở chat được đổi tên, cập nhật currentChatId
      if (oldChatId == currentChatId) {
        currentChatId = newTitle;
      }
    });

    _saveChats();
  }

  void _showChatOptions(BuildContext context, String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          color: const Color(0xFF343541),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text('Đổi tên', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Hiển thị dialog đổi tên
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      String newTitle = chatId;
                      return AlertDialog(
                        backgroundColor: const Color(0xFF343541),
                        title: const Text('Đổi tên đoạn chat',
                            style: TextStyle(color: Colors.white)),
                        content: TextField(
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Nhập tên mới',
                            hintStyle: TextStyle(color: Colors.grey),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                          onChanged: (value) => newTitle = value,
                          controller: TextEditingController(text: chatId),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Hủy',
                                style: TextStyle(color: Colors.grey)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: const Text('Lưu',
                                style: TextStyle(color: Colors.white)),
                            onPressed: () {
                              _renameChat(chatId, newTitle.trim());
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Xóa', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(chatId);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color.fromARGB(220, 42, 37, 56),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                    color: Color.fromARGB(255, 53, 54, 60), width: 0.5),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.view_sidebar_outlined, color: Colors.white),
                  onPressed: _toggleSidebar,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "ChatMini",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_square, color: Colors.white),
                  tooltip: 'Đoạn chat mới',
                  onPressed: _createNewChat,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Danh sách đoạn chat',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...allChats.keys.toList().reversed.map((chatId) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: currentChatId == chatId
                            ? const Color(0xFF343541)
                            : Colors.transparent,
                      ),
                      child: ListTile(
                        leading: Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        title: Tooltip(
                          message: chatId,
                          child: Text(
                            chatId,
                            style: TextStyle(
                              color: Colors.grey.shade200,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.white70),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 8,
                          color: const Color(0xFF2D2B38),
                          onSelected: (value) {
                            if (value == 'rename') {
                              // Hiển thị dialog đổi tên
                              showDialog(
                                context: context,
                                builder: (context) {
                                  final TextEditingController controller = TextEditingController(text: chatId);
                                  return AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15.0),
                                    ),
                                    title: const Text('Đổi tên đoạn chat'),
                                    content: TextField(
                                      controller: controller,
                                      decoration: const InputDecoration(
                                        hintText: 'Nhập tên mới',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(Radius.circular(10)),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Hủy'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (controller.text.isNotEmpty) {
                                            setState(() {
                                              final messages = allChats[chatId];
                                              allChats.remove(chatId);
                                              allChats[controller.text] = messages!;
                                              if (currentChatId == chatId) {
                                                currentChatId = controller.text;
                                              }
                                              _saveChats();
                                            });
                                            Navigator.pop(context);
                                          }
                                        },
                                        child: const Text('Lưu'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            } else if (value == 'delete') {
                              // Hiển thị dialog xác nhận xóa
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15.0),
                                  ),
                                  title: const Text('Xóa đoạn chat'),
                                  content: const Text('Bạn có chắc chắn muốn xóa đoạn chat này không?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Hủy'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        _deleteChat(chatId);
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          itemBuilder: (BuildContext context) => [
                            const PopupMenuItem<String>(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, color: Colors.white70),
                                  SizedBox(width: 8),
                                  Text('Đổi tên', style: TextStyle(color: Colors.white)),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, color:  Color.fromARGB(179, 255, 93, 93)),
                                  SizedBox(width: 8),
                                  Text('Xóa', style: TextStyle(color: Color.fromARGB(179, 241, 80, 80))),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          setState(() {
                            currentChatId = chatId;
                          });
                          if (!isDesktopMode(context)) {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFF444654), width: 0.5),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade700,
                      child: const Text('SI',
                          style: TextStyle(color: Colors.white, fontSize: 14)),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cài đặt',
                      style: TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    final messages = allChats[currentChatId] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1A2B),
      appBar: AppBar(
        title: Text(currentChatId, style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: isDesktopMode(context) && !_isSidebarVisible
            ? IconButton(
                icon: Icon(Icons.view_sidebar_outlined, color: Colors.white),
                tooltip: 'Hiện sidebar',
                onPressed: _toggleSidebar,
              )
            : null,
        actions: [
          if (isDesktopMode(context) && !_isSidebarVisible)
            IconButton(
              icon: const Icon(
                Icons.edit_square,
                color: Colors.white,
              ),
              tooltip: 'Đoạn chat mới',
              onPressed: _createNewChat,
            ),
        ],
      ),
      body: _buildChatContent(messages),
    );
  }

  Widget _buildChatContent(List<Map<String, String>> messages) {
    return Column(
      children: [
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: true,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                scrollbarTheme: ScrollbarThemeData(
                  thumbColor: WidgetStateProperty.all(
                      const Color.fromARGB(255, 51, 47, 60)),
                  thickness: WidgetStateProperty.all(6.0),
                  radius: const Radius.circular(10.0),
                  thumbVisibility: WidgetStateProperty.all(true),
                ),
              ),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  itemCount: messages.length,
                  itemBuilder: (_, index) {
                    var msg = messages[index];
                    bool isUser = msg['role'] == 'user';

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: isUser
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser)
                            Padding(
                              padding:
                                  const EdgeInsets.only(right: 8.0, top: 0),
                              child: CircleAvatar(
                                radius: 16,
                                backgroundImage:
                                    AssetImage('lib/images/botchat.png'),
                                backgroundColor: Colors.transparent,
                              ),
                            ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isUser
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  constraints: isUser
                                      ? const BoxConstraints(maxWidth: 700)
                                      : null,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isUser
                                          ? [
                                              Color.fromARGB(255, 75, 73, 77),
                                              Color.fromARGB(255, 67, 67, 68)
                                            ]
                                          : [
                                              Color(0xFF1E1A2B),
                                              Color(0xFF1E1A2B)
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.only(
                                      bottomLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      topLeft: Radius.circular(isUser ? 18 : 0),
                                      bottomRight:
                                          Radius.circular(isUser ? 0 : 18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromARGB(
                                                255, 94, 78, 98)
                                            .withOpacity(0.15),
                                        blurRadius: 3,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: MarkdownBody(
                                    data: msg['content'] ?? '',
                                    styleSheet: MarkdownStyleSheet(
                                      p: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                      code: TextStyle(
                                        backgroundColor: Color(0xFF2B2B2B), // Dark background
                                        color: const Color.fromARGB(255, 228, 163, 135),
                                        fontFamily: 'Consolas',
                                        fontSize: 14,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: Color(0xFF2B2B2B), // Dark background
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      codeblockPadding: EdgeInsets.all(16),
                                     
                                      // Custom styles cho các loại token khác nhau
                                      a: TextStyle(color: Color(0xFF9876AA)), // Purple for identifiers
                                      em: TextStyle(color: Color(0xFFCC7832)), // Orange for keywords
                                      strong: TextStyle(color: Color(0xFF6897BB)), // Blue for numbers
                                      del: TextStyle(color: Color(0xFF629755)), // Green for strings
                                      blockquote: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        height: 1.5,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      blockquoteDecoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: Colors.grey.shade500,
                                            width: 4,
                                          ),
                                        ),
                                      ),
                                      blockquotePadding: const EdgeInsets.only(left: 16),
                                      listBullet: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      tableHead: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        backgroundColor: Colors.grey.shade800,
                                      ),
                                      tableBody: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      tableBorder: TableBorder.all(
                                        color: Colors.grey.shade600,
                                        width: 1,
                                      ),
                                      tableColumnWidth: const FlexColumnWidth(),
                                      tableCellsPadding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      tableCellsDecoration: BoxDecoration(
                                        color: const Color(0xFF2D2B38),
                                      ),
                                    ),
                                    selectable: true,
                                    softLineBreak: true,
                                    shrinkWrap: true,

                                  ),
                                ),
                                Container(
                                  alignment: isUser
                                      ? Alignment.centerRight
                                      : Alignment.centerLeft,
                                  margin: const EdgeInsets.only(top: 4),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(15),
                                      onTap: () {
                                        ClipboardService.copyToClipboard(
                                            context, msg['content'] ?? '');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.content_copy,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 50),
          padding:
              const EdgeInsets.only(right: 24, left: 24, top: 8, bottom: 16),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 51, 47, 60),
            border: Border.all(color: Colors.grey.shade600, width: 0.5),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color.fromARGB(255, 74, 73, 73).withOpacity(0.2),
                blurRadius: 2,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Builder(
                          builder: (context) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                scrollbarTheme: ScrollbarThemeData(
                                  thumbColor: WidgetStateProperty.all(
                                      const Color.fromARGB(255, 71, 69, 71)),
                                  thickness: WidgetStateProperty.all(8.0),
                                  radius: const Radius.circular(4.0),
                                  thumbVisibility:
                                      WidgetStateProperty.all(true),
                                  trackVisibility:
                                      WidgetStateProperty.all(true),
                                  trackColor: WidgetStateProperty.all(
                                      const Color.fromARGB(255, 58, 58, 58)
                                          .withOpacity(0.15)),
                                  crossAxisMargin: 2,
                                  mainAxisMargin: 2,
                                  interactive: true,
                                  minThumbLength: 50,
                                ),
                              ),
                              child: RawKeyboardListener(
                                focusNode: FocusNode(),
                                onKey: (RawKeyEvent event) {
                                  if (event is RawKeyDownEvent) {
                                    if (event.logicalKey ==
                                        LogicalKeyboardKey.enter) {
                                      if (event.isShiftPressed) {
                                        // Shift + Enter: Insert new line
                                        final text = _controller.text;
                                        final selection = _controller.selection;
                                        final newText =
                                            '${text.substring(0, selection.baseOffset)}${text.substring(selection.baseOffset)}';
                                        _controller.value = TextEditingValue(
                                          text: newText,
                                          selection: TextSelection.collapsed(
                                            offset: selection.baseOffset + 1,
                                          ),
                                        );
                                      } else {
                                        // Enter: Send message
                                        if (canSendMessage && !isProcessing) {
                                          _sendMessage();
                                        }
                                      }
                                    }
                                  }
                                },
                                child: TextField(
                                  controller: _controller,
                                  focusNode: _textFieldFocusNode,
                                  onChanged: (text) {
                                    setState(() {
                                      canSendMessage = text.trim().isNotEmpty;
                                    });
                                  },
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                  ),
                                  cursorColor: Colors.white,
                                  decoration: InputDecoration(
                                    hintText: isProcessing
                                        ? 'Đang xử lý...'
                                        : 'Hỏi bất kỳ điều gì',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4, vertical: 14),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                  minLines: 1,
                                  maxLines: 6,
                                  scrollPhysics: const ClampingScrollPhysics(),
                                  enabled:
                                      !isProcessing, // Vô hiệu hóa khi đang xử lý
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      // Chức năng nút thêm
                    },
                    icon: const Icon(Icons.add, color: Colors.grey, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  InkWell(
                    onTap:
                        (canSendMessage && !isProcessing) ? _sendMessage : null,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (canSendMessage && !isProcessing)
                            ? const Color.fromARGB(255, 192, 90, 229)
                            : const Color.fromARGB(255, 71, 59, 70),
                      ),
                      child: Icon(
                        isProcessing
                            ? Icons.hourglass_empty
                            : Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = isDesktopMode(context);

    if (isDesktop) {
      return Material(
        color: const Color(0xFF1E1A2B),
        child: Row(
          children: [
            if (_isSidebarVisible) _buildSidebar(),
            Expanded(
              child: _buildChatArea(),
            ),
          ],
        ),
      );
    } else {
      return Scaffold(
        backgroundColor: const Color(0xFF1E1A2B),
        drawer: Drawer(
          backgroundColor: const Color.fromARGB(220, 42, 37, 56),
          child: _buildSidebar(),
        ),
        appBar: AppBar(
          title: Text(currentChatId, style: TextStyle(color: Colors.white)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(
                Icons.view_sidebar_outlined,
                color: Colors.white,
              ),
              tooltip: 'Mở sidebar',
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE727ff), Color(0xFF7c2f77)],
                begin: Alignment.bottomLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(
                Icons.edit_square,
                color: Colors.white,
              ),
              tooltip: 'Đoạn chat mới',
              onPressed: _createNewChat,
            ),
          ],
        ),
        body: _buildChatContent(allChats[currentChatId] ?? []),
      );
    }
  }
}
