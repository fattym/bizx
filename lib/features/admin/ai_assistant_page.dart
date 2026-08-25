import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/colors.dart';
import '../../core/config/api_config.dart';
import '../database/database_service.dart';

class AiAssistantPage extends StatefulWidget {
  const AiAssistantPage({super.key});

  @override
  State<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends State<AiAssistantPage> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [];
  bool _isWaiting = false;
  int _currentUserRole = 5;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final role = await _dbService.getCurrentUserRole();
    if (!mounted) return;
    setState(() {
      _currentUserRole = role;
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isWaiting) return;

    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _isWaiting = true;
    });
    _controller.clear();

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.aiChatUrl()),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'messages': _messages.map((m) => {'role': m['role'], 'content': m['content']}).toList(),
          'context': null,
        }),
      );

      if (!mounted) return;
      setState(() => _isWaiting = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final assistantMessage = data['choices']?[0]?['message']?['content'] ?? 'Sorry, I could not generate a response.';
        setState(() {
          _messages.add({'role': 'assistant', 'content': assistantMessage});
        });
      } else {
        setState(() {
          _messages.add({'role': 'assistant', 'content': 'Error: ${response.statusCode}'});
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isWaiting = false;
        _messages.add({'role': 'assistant', 'content': 'Error: $e'});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _currentUserRole <= 2;
    if (!isManager) {
      return const Scaffold(
        body: Center(child: Text('Access restricted to Admin and Sales Manager roles.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.surfaceWhite,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Hello! How can I help you today?',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['role'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primaryDark : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            msg['content'] ?? '',
                            style: TextStyle(color: isUser ? Colors.white : Colors.black87),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isWaiting)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isWaiting ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
