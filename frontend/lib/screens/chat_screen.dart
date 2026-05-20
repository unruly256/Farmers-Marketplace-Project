import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final String currentPhone;
  final String contactPhone;
  final String contactName;
  final int? orderId;
  final int? produceId;
  final String? title;
  final bool isBuyer;

  const ChatScreen({
    super.key,
    required this.currentPhone,
    required this.contactPhone,
    required this.contactName,
    this.orderId,
    this.produceId,
    this.title,
    required this.isBuyer,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<dynamic> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _showEmoji = false;
  String _presenceText = 'Last seen recently';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadChat();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _threadTitle() {
    final t = widget.title?.trim();
    return (t == null || t.isEmpty) ? 'Chat' : t;
  }

  Future<void> _loadChat() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await ApiService.markChatAsRead(widget.currentPhone, widget.contactPhone);
      final msgs = await ApiService.fetchMessages(
        widget.currentPhone,
        widget.contactPhone,
      );

      if (!mounted) return;
      setState(() {
        _messages = msgs;
        _isLoading = false;
      });

      _presenceText = 'Last seen recently';
      await Future.delayed(const Duration(milliseconds: 120));
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshSilently() async {
    if (!mounted) return;
    try {
      final msgs = await ApiService.fetchMessages(
        widget.currentPhone,
        widget.contactPhone,
      );
      if (!mounted) return;
      setState(() => _messages = msgs);
      _scrollToBottom();
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final res = await ApiService.sendMessage(
      widget.currentPhone,
      widget.contactPhone,
      text,
    );

    if (!mounted) return;
    setState(() => _isSending = false);

    final ok = res['status'] == 'success' || res['success'] == true;
    if (ok) {
      _textController.clear();
      await _loadChat();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message']?.toString() ?? 'Failed to send message.',
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  // ------------------------------------------------------------------
  // FIXED: Reads 'content' from FastAPI response (also fallback)
  // ------------------------------------------------------------------
  String _msgText(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    // ✅ Reads 'content' – the key sent by your FastAPI backend
    return (map['content'] ?? map['message'] ?? map['text'] ?? '').toString();
  }

  // ------------------------------------------------------------------
  // FIXED: Reads 'sender' from FastAPI response (also fallback)
  // ------------------------------------------------------------------
  String _msgSender(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    // ✅ Reads 'sender' – matches your backend's field name
    return (map['sender'] ?? map['sender_phone'] ?? map['senderPhone'] ?? map['from'] ?? '').toString();
  }

  bool _msgSeen(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    final v = map['seen'] ?? map['is_seen'] ?? map['read'] ?? map['is_read'] ?? false;
    return v == true || v.toString().toLowerCase() == 'true' || v.toString() == '1';
  }

  String _formatTime(dynamic m) {
    final map = Map<String, dynamic>.from(m as Map);
    final raw = (map['created_at'] ?? map['timestamp'] ?? map['time'] ?? '').toString();
    if (raw.isEmpty) return '';
    return raw;
  }

  Widget _messageBubble(dynamic m) {
    final sender = _msgSender(m);
    final text = _msgText(m);
    final mine = sender == widget.currentPhone;
    final seen = _msgSeen(m);
    final time = _formatTime(m);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: mine
              ? Colors.green.shade700
              : isDark
                  ? const Color(0xFF2A2A2A)
                  : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
          border: Border.all(
            color: mine ? Colors.transparent : Colors.black.withOpacity(0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.20 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                color: mine
                    ? Colors.white
                    : isDark
                        ? Colors.white
                        : const Color(0xFF111827),
                fontSize: 14.2,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: TextStyle(
                      color: mine ? Colors.white70 : Colors.grey.shade500,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (mine) ...[
                  const SizedBox(width: 6),
                  Icon(
                    seen ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 15,
                    color: seen ? Colors.lightBlueAccent : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emojiPanel() {
    const emojis = [
      '😀', '😁', '😂', '🤣', '😊', '😍', '🤝', '🙏',
      '👍', '👏', '🔥', '🌱', '🍅', '🥕', '🌾', '💚'
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
      ),
      child: GridView.builder(
        itemCount: emojis.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemBuilder: (_, i) => InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final e = emojis[i];
            _textController.text += e;
            _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length),
            );
            setState(() {});
          },
          child: Center(
            child: Text(emojis[i], style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => setState(() => _showEmoji = !_showEmoji),
              icon: const Icon(Icons.emoji_emotions_outlined),
              color: Colors.orange.shade700,
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.04)
                      : Colors.black.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isSending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.orange.shade700,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : const Color(0xFFF7F8FA);
    final title = _threadTitle();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0.6,
        centerTitle: false,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.green.shade700.withOpacity(0.15),
              child: Text(
                widget.contactName.isNotEmpty
                    ? widget.contactName[0].toUpperCase()
                    : 'C',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(
                    widget.contactName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadChat,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF171717) : Colors.white,
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _presenceText,
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  widget.isBuyer ? 'Buyer' : 'Farmer',
                  style: TextStyle(
                    color: Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadChat,
              color: Colors.orange.shade700,
              child: _isLoading
                  ? ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: 8,
                      itemBuilder: (_, __) => Container(
                        height: 56,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      itemCount: _messages.length,
                      itemBuilder: (_, index) => _messageBubble(_messages[index]),
                    ),
            ),
          ),
          if (_showEmoji) _emojiPanel(),
          _composer(),
        ],
      ),
    );
  }
}