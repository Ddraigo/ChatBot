import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'services/gemini_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter/gestures.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final GeminiService _chatService = GeminiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocusNode = FocusNode();

  Map<String, List<Map<String, String>>> allChats = {};
  String currentChatId = '';
  int chatCounter = 0;

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

    String botResponse = await _chatService.sendMessage(userMessage);

    setState(() {
      allChats[currentChatId]!.add({'role': 'bot', 'content': botResponse});
    });
    _scrollToBottom();
  }

  void _createNewChat() {
    setState(() {
      chatCounter++;
      currentChatId = 'Chat #$chatCounter';
      allChats[currentChatId] = [];
    });
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createNewChat();
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

  @override
  Widget build(BuildContext context) {
    final messages = allChats[currentChatId] ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1A2B),
      appBar: AppBar(
        title: Text(currentChatId),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE727ff), Color(0xFF7c2f77)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_comment_outlined,
              color: Color.fromARGB(255, 174, 173, 173),
            ),
            tooltip: 'Đoạn chat mới',
            onPressed: _createNewChat,
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration:
                  BoxDecoration(color: Color.fromARGB(255, 164, 73, 200)),
              child: Text('Danh sách đoạn chat',
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
            ...allChats.keys.map((chatId) => ListTile(
                  title: Text(chatId),
                  onTap: () {
                    setState(() {
                      currentChatId = chatId;
                    });
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
      body: Column(
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

                      // Phần code hiển thị tin nhắn của bạn giữ nguyên
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: Row(
                          mainAxisAlignment: isUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isUser)
                              CircleAvatar(
                                radius: 20,
                                backgroundImage:
                                    AssetImage('lib/images/botchat.png'),
                                backgroundColor: Colors.transparent,
                              ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isUser
                                        ? [
                                            Color.fromARGB(255, 211, 207, 214),
                                            Color.fromARGB(255, 113, 91, 156)
                                          ]
                                        : [Colors.white, Colors.white],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(18),
                                    topRight: const Radius.circular(18),
                                    bottomLeft:
                                        Radius.circular(isUser ? 18 : 0),
                                    bottomRight:
                                        Radius.circular(isUser ? 0 : 18),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: MarkdownBody(
                                  data: msg['content'] ?? '',
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(
                                        color: Colors.black, fontSize: 16),
                                  ),
                                ),
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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  // decoration: BoxDecoration(
                  //   color: const Color.fromARGB(255, 51, 47, 60),
                  //   borderRadius: BorderRadius.circular(24),
                  //   border: Border.all(color: Colors.grey.shade600, width: 0.5),
                  // ),
                  child: Row(
                    children: [
                      // TextField chính
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Builder(
                            builder: (context) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  scrollbarTheme: ScrollbarThemeData(
                                    thumbColor: WidgetStateProperty.all(
                                        const Color.fromARGB(255, 71, 69, 71)),
                                    thickness: WidgetStateProperty.all(8.0),
                                    radius: const Radius.circular(4.0),
                                    thumbVisibility: WidgetStateProperty.all(true),
                                    trackVisibility: WidgetStateProperty.all(true),
                                    trackColor: WidgetStateProperty.all(const Color.fromARGB(255, 58, 58, 58).withOpacity(0.15)),
                                    crossAxisMargin: 2,
                                    mainAxisMargin: 2,
                                    interactive: true,
                                    minThumbLength: 50,
                                  ),
                                ),
                                child: ScrollConfiguration(
                                  behavior: ScrollConfiguration.of(context).copyWith(
                                    dragDevices: {
                                      PointerDeviceKind.touch,
                                      PointerDeviceKind.mouse,
                                    },
                                  ),
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _textFieldFocusNode,
                                    onSubmitted: (_) => _sendMessage(),
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
                                ),
                              );
                            }
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
                          color: _controller.text.trim().isNotEmpty
                              ? const Color.fromARGB(255, 139, 88, 158)
                              : const Color.fromARGB(255, 207, 203, 203),
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
      ),
    );
  }
}
