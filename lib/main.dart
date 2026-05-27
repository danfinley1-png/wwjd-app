import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

void main() {
  runApp(const WWJDApp());
}

class WWJDApp extends StatelessWidget {
  const WWJDApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WWJD – DI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFFF8F5F0),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF8B1E1E),
          foregroundColor: Colors.white,
          toolbarHeight: 160,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  final List<Map<String, dynamic>> _sharedTopics = [
    {'topic': 'How do I balance school and prayer life?', 'upvotes': 24, 'user': 'Anonymous'},
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ Copied')));
  }

  void _shareToCommunity(int index) {
    final reply = _messages[index]['content']!;
    setState(() {
      _sharedTopics.insert(0, {
        'topic': reply.length > 120 ? reply.substring(0, 120) + '...' : reply,
        'upvotes': 1,
        'user': 'Anonymous'
      });
    });
    _showWalkTogether();
  }

  Future<void> _delveDeeper(int index) async {
    final lastReply = _messages[index]['content']!;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://api.x.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 🔑 YOUR_XAI_API_KEY_HERE 🔑',
        },
        body: jsonEncode({
          "model": "grok-4-1-fast-reasoning",
          "messages": [
            {"role": "system", "content": "Provide deeper Catholic teaching with specific Scripture, Catechism references, and saints’ writings."},
            {"role": "user", "content": "Expand on this: $lastReply"}
          ],
          "temperature": 0.6,
          "max_tokens": 800,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final deeper = data['choices'][0]['message']['content'].trim();
        setState(() => _messages.add({'role': 'assistant', 'content': '🔎 Delve Deeper:\n\n$deeper'}));
      }
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'Unable to fetch deeper content right now.'}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage() async {
    final question = _controller.text.trim();
    if (question.isEmpty) return;

    setState(() {
      _messages.add({'role': 'user', 'content': question});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('https://api.x.ai/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 🔑 YOUR_XAI_API_KEY_HERE 🔑',
        },
        body: jsonEncode({
          "model": "grok-4-1-fast-reasoning",
          "messages": [
            {"role": "system", "content": "You are WWJD – DI, a faithful Catholic moral advisor. Always respond with mercy and hope using the Two Great Commandments. Structure every answer as: 1. Warm Welcome 2. Framing with the Two Great Commandments 3. What Would Jesus Do? 4. Mercy & Forgiveness 5. Practical Steps 6. Kingdom Challenge."},
            ..._messages.map((m) => {"role": m['role']!, "content": m['content']!})
          ],
          "temperature": 0.7,
          "max_tokens": 950,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data['choices'][0]['message']['content'].trim();
        setState(() => _messages.add({'role': 'assistant', 'content': reply}));
      }
    } catch (e) {
      setState(() => _messages.add({'role': 'assistant', 'content': 'Sorry, connection error. Please try again.'}));
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  void _showWalkTogether() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Walk Together'),
        content: SizedBox(
          width: double.maxFinite,
          height: 500,
          child: Column(
            children: [
              const Text('Shared Topics for Mutual Encouragement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _sharedTopics.length,
                  itemBuilder: (context, index) {
                    final topic = _sharedTopics[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        title: Text(topic['topic']),
                        subtitle: Text('Shared by ${topic['user']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.thumb_up),
                              onPressed: () {
                                setState(() => topic['upvotes']++);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upvoted!')));
                              },
                            ),
                            Text('${topic['upvotes']}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showReference(String ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ref),
        content: const SingleChildScrollView(child: Text("Full quote and explanation would appear here.")),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Widget _buildMessageText(String text) {
    final regExp = RegExp(r'(John|Matthew|Mt|Luke|Lk|Jn|Acts|Romans|Rom|1 Cor|CCC)\s*\d+[:,\-]\d*', caseSensitive: false);
    final matches = regExp.allMatches(text);
    if (matches.isEmpty) return SelectableText(text, style: const TextStyle(fontSize: 16, height: 1.5));

    List<TextSpan> spans = [];
    int lastEnd = 0;
    for (final match in matches) {
      if (match.start > lastEnd) spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      final ref = match.group(0)!;
      spans.add(TextSpan(
        text: ref,
        style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => _showReference(ref),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) spans.add(TextSpan(text: text.substring(lastEnd)));
    return RichText(text: TextSpan(children: spans, style: const TextStyle(fontSize: 16, height: 1.5, color: Colors.black)));
  }

  // Sidebar Dialogs
  void _showSeekingGodsWisdom() => _simpleDialog("Seeking God's Wisdom", "James 1:5 – If any of you lacks wisdom, ask God...");
  void _showUsingMyGifts() => _simpleDialog("Using My Gifts", "Each of us has received a gift to use for the Kingdom.");
  void _showMyMoralDilemmas() => _simpleDialog("My Moral Dilemmas", "This is the heart of the app – bring your questions here.");
  void _showMyHistory() => _simpleDialog("My History", "Coming soon – saved conversations.");
  void _showTermsAndPrivacy() => _simpleDialog("Terms & Privacy", "Full policy coming soon.");
  void _showMass() => _simpleDialog("Attend Mass", "The source and summit of our faith.");
  void _showConfession() => _simpleDialog("Go to Confession", "God's mercy is infinite.");
  void _showAdoration() => _simpleDialog("Eucharistic Adoration", "Jesus is truly present.");
  void _showExaminationOfConscience() => _simpleDialog("Examination of Conscience", "1. Gratitude\n2. Review the day\n3. Sorrow\n4. Resolve");

  void _simpleDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.church, size: 48),
            SizedBox(width: 16),
            Text('WWJD – DI', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(40),
          child: Padding(
            padding: EdgeInsets.only(bottom: 12, left: 16),
            child: Text(
              'Sharing the Divine Intelligence of Scripture and the Revelation of the Catholic Church',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          if (isWide)
            Container(
              width: 300,
              color: const Color(0xFFF0EDE6),
              child: Column(
                children: [
                  const Padding(padding: EdgeInsets.all(20), child: Text('Tools for the Journey', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                  ListTile(leading: const Icon(Icons.lightbulb), title: const Text("Seeking God's Wisdom"), onTap: _showSeekingGodsWisdom),
                  ListTile(leading: const Icon(Icons.card_giftcard), title: const Text('Using My Gifts for the Kingdom'), onTap: _showUsingMyGifts),
                  ListTile(leading: const Icon(Icons.history), title: const Text('My Moral Dilemmas'), onTap: _showMyMoralDilemmas),
                  ListTile(leading: const Icon(Icons.history_edu), title: const Text('My History'), onTap: _showMyHistory),
                  ListTile(leading: const Icon(Icons.people), title: const Text('Walk Together'), onTap: _showWalkTogether),
                  ListTile(leading: const Icon(Icons.description), title: const Text('Terms & Privacy'), onTap: _showTermsAndPrivacy),
                  const Divider(),
                  const Padding(padding: EdgeInsets.all(16), child: Text('Spiritual Nourishment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ListTile(leading: const Icon(Icons.church), title: const Text('Attend Mass'), onTap: _showMass),
                  ListTile(leading: const Icon(Icons.replay), title: const Text('Go to Confession'), onTap: _showConfession),
                  ListTile(leading: const Icon(Icons.favorite), title: const Text('Eucharistic Adoration'), onTap: _showAdoration),
                  ListTile(leading: const Icon(Icons.assignment), title: const Text('Examination of Conscience'), onTap: _showExaminationOfConscience),
                ],
              ),
            ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Peace be with you.\nWhat is weighing on your heart today?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 22),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['role'] == 'user';
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isUser ? Colors.blue.shade50 : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMessageText(msg['content']!),
                                    if (!isUser)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          TextButton.icon(icon: const Icon(Icons.expand_more), label: const Text("Delve Deeper"), onPressed: () => _delveDeeper(index)),
                                          IconButton(icon: const Icon(Icons.copy), onPressed: () => _copyToClipboard(msg['content']!)),
                                          IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share(msg['content']!)),
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                            icon: const Icon(Icons.people),
                                            label: const Text('Community Share'),
                                            onPressed: () => _shareToCommunity(index),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Describe your moral dilemma...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(30))),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        iconSize: 36,
                        icon: _isLoading ? const CircularProgressIndicator() : const Icon(Icons.send, color: Color(0xFF8B1E1E)),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ],
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