import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GeminiService _chatService = GeminiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _createNewChat();
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
              colors: [Color(0xFFFF6FD8), Color(0xFF3813C2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_comment,
              color: Colors.white,
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
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 16),
              itemCount: messages.length,
              itemBuilder: (_, index) {
                var msg = messages[index];
                bool isUser = msg['role'] == 'user';
                print(msg['content']);

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: isUser
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!isUser)
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: AssetImage('lib/images/bot.jpg'),
                        ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isUser
                                  ? [Color(0xFF8E2DE2), Color(0xFF4A00E0)]
                                  : [Colors.white, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isUser ? 18 : 0),
                              bottomRight: Radius.circular(isUser ? 0 : 18),
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

                          // Text(
                          //   msg['content'] ?? '',
                          //   style: const TextStyle(
                          //       color: Colors.white, fontSize: 16),
                          // ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF2C2543),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      hintStyle: const TextStyle(color: Colors.white70),
                      filled: true,
                      fillColor: const Color(0xFF3A2F5C),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFF857A6), Color(0xFFFF5858)],
                      ),
                    ),
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
