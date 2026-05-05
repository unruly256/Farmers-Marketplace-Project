import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentPhone;
  final String contactPhone;
  final String contactName;

  const ChatScreen({
    super.key, 
    required this.currentPhone, 
    required this.contactPhone, 
    required this.contactName
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<dynamic> _messages = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Poll the database every 3 seconds for new messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _loadMessages());
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final msgs = await ApiService.fetchMessages(widget.currentPhone, widget.contactPhone);
    if (mounted) {
      setState(() => _messages = msgs);
      // Auto-scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent, 
            duration: const Duration(milliseconds: 300), 
            curve: Curves.easeOut
          );
        }
      });
    }
  }

  void _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    _msgController.clear();
    
    // Optimistically add to UI for instant feel
    setState(() {
      _messages.add({"sender": widget.currentPhone, "content": text, "time": "Now"});
    });

    await ApiService.sendMessage(widget.currentPhone, widget.contactPhone, text);
    _loadMessages();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(Icons.person, color: Colors.green.shade700)),
            const SizedBox(width: 12),
            Text(widget.contactName, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['sender'] == widget.currentPhone;

                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.green.shade600 : Colors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                      ),
                      border: isMe ? null : Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(msg['content'], style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(msg['time'], style: TextStyle(color: isMe ? Colors.white70 : Colors.grey.shade500, fontSize: 10)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // BOTTOM TEXT INPUT
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.green.shade700, shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
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