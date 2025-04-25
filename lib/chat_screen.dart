import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/gemini_service.dart';
import 'services/clipboard_service.dart';
import 'services/storage_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/gestures.dart';


class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final GeminiService _chatService = GeminiService();
  final StorageService _storageService = StorageService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();

  Map<String, List<Map<String, String>>> allChats = {};
  String currentChatId = '';
  int chatCounter = 0;
  bool canSendMessage = false;
  // Biến để kiểm soát trạng thái hiển thị của sidebar
  bool _isSidebarVisible = true;

  void _sendMessage() async {
    String userMessage = _controller.text.trim();
    if (userMessage.isEmpty || currentChatId.isEmpty) return;

    setState(() {
      allChats[currentChatId]!.add({'role': 'user', 'content': userMessage});
    });
    _controller.clear();
    _scrollToBottom();

    // Sử dụng try-catch để xử lý lỗi khi unfocus
    try {
      _textFieldFocusNode.unfocus();
    } catch (e) {
      // Bỏ qua lỗi focus
      if (kDebugMode) {
        print("Focus error ignored: $e");
      }
    }
    setState(() {
      canSendMessage = false;
    });

    // Lưu trạng thái sau khi thêm tin nhắn người dùng
    _saveChats();

    String botResponse = await _chatService.sendMessage(userMessage);

    setState(() {
      allChats[currentChatId]!.add({'role': 'bot', 'content': botResponse});
    });
    
    // Lưu trạng thái sau khi nhận tin nhắn từ bot
    _saveChats();
    
    _scrollToBottom();
  }

  void _createNewChat() {
    setState(() {
      chatCounter++;
      currentChatId = 'Chat $chatCounter';
      allChats[currentChatId] = [];
    });
    
    // Lưu trạng thái sau khi tạo chat mới
    _saveChats();
  }

  // Phương thức lưu cuộc trò chuyện
  Future<void> _saveChats() async {
    await _storageService.saveChats(allChats);
  }

  // Phương thức tải cuộc trò chuyện
  Future<void> _loadChats() async {
    final savedChats = await _storageService.loadChats();
    if (savedChats.isNotEmpty) {
      setState(() {
        allChats = savedChats;
        // Lấy ID chat cuối cùng
        currentChatId = allChats.keys.last;
        // Cập nhật chatCounter để giá trị mới không bị trùng
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
        // Bỏ qua lỗi khi scroll
        if (kDebugMode) {
          print("Scroll error ignored: $e");
        }
      }
    });
  }

  // Hàm đóng/mở sidebar
  void _toggleSidebar() {
    setState(() {
      _isSidebarVisible = !_isSidebarVisible;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tải lại dữ liệu chat từ bộ nhớ cục bộ
    _loadChats();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Xử lý khi ứng dụng thay đổi trạng thái
    if (state == AppLifecycleState.resumed) {
      // Ứng dụng được tiếp tục
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

  // Kiểm tra nếu đang ở chế độ màn hình lớn (desktop)
  bool isDesktopMode(BuildContext context) {
    return MediaQuery.of(context).size.width > 900;
  }

  // Widget hiển thị sidebar
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
                bottom: BorderSide(color: Color.fromARGB(255, 53, 54, 60), width: 0.5),
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
                ...allChats.keys.map((chatId) => Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                        title: Text(
                          chatId,
                          style: TextStyle(
                            color: Colors.grey.shade200,
                            fontSize: 15,
                          ),
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

  // Widget hiển thị content chat với AppBar
  Widget _buildChatArea() {
    final messages = allChats[currentChatId] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1A2B),
      appBar: AppBar(
        title: Text(currentChatId, style: TextStyle(color: Colors.white),),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        // flexibleSpace: Container(
        //   decoration: const BoxDecoration(
        //     gradient: LinearGradient(
        //       colors: [Color(0xFFE727ff), Color(0xFF7c2f77)],
        //       begin: Alignment.bottomLeft,
        //       end: Alignment.bottomRight,
        //     ),
        //   ),
        // ),
        leading: isDesktopMode(context) && !_isSidebarVisible 
          ? IconButton(
              icon: Icon(Icons.view_sidebar_outlined, color: Colors.white),
              tooltip: 'Hiện sidebar',
              onPressed: _toggleSidebar,
            )
          : null,
        // Hiển thị icon edit_square ở góc phải khi sidebar đóng trong chế độ desktop
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

  // Widget chỉ hiển thị nội dung chat (không bao gồm AppBar)
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
                                      code: const TextStyle(
                                        color: Colors.white,
                                        backgroundColor: Color(0xFF2D2B38),
                                        fontSize: 14,
                                      ),
                                      codeblockDecoration: BoxDecoration(
                                        color: const Color(0xFF2D2B38),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      blockquote: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                      listBullet: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    selectable: true,
                                    softLineBreak: true,
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
                                        // Sử dụng ClipboardService để xử lý đa nền tảng
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
                    // TextField chính
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
                              child: TextField(
                                controller: _controller,
                                focusNode: _textFieldFocusNode,
                                onSubmitted: (_) => _sendMessage(),
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
                                decoration: const InputDecoration(
                                  hintText: 'Hỏi bất kỳ điều gì',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                minLines: 1,
                                maxLines: 6,
                                scrollPhysics: const ClampingScrollPhysics(),
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
                  // Nút Thêm
                  IconButton(
                    onPressed: () {
                      // Chức năng nút thêm
                    },
                    icon: const Icon(Icons.add, color: Colors.grey, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),

                  // Nút gửi
                  InkWell(
                    onTap: _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: canSendMessage
                            ? const Color.fromARGB(255, 192, 90, 229)
                            : const Color.fromARGB(255, 71, 59, 70),
                      ),
                      child: const Icon(Icons.arrow_upward_rounded,
                          color: Colors.white, size: 18),
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

    // Trong chế độ desktop, sidebar và content ngang hàng nhau, AppBar chỉ ở phần content
    // Trong chế độ mobile, sử dụng Scaffold với drawer
    if (isDesktop) {
      return Material(
        color: const Color(0xFF1E1A2B),
        child: Row(
          children: [
            // Chỉ hiển thị sidebar nếu _isSidebarVisible = true
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
          title: Text(currentChatId),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          // Thêm icon view_sidebar_outlined vào leading
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