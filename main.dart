import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ====== CONFIG ======
// Replace with your backend base URL
const String backendBase = String.fromEnvironment('BACKEND_BASE', defaultValue: 'http://localhost:8000');

void main() {
  runApp(const MoodMatchApp());
}

class MoodMatchApp extends StatelessWidget {
  const MoodMatchApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MoodMatch',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _location = TextEditingController();
  String _gender = 'Male';
  bool _loading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final resp = await http.post(
        Uri.parse('$backendBase/register_user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _username.text.trim(),
          'gender': _gender,
          'location': _location.text.trim(),
        }),
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', data['id']);
        await prefs.setString('username', data['username']);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${resp.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login / Onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'Male', child: Text('Male')),
                  DropdownMenuItem(value: 'Female', child: Text('Female')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _gender = v ?? 'Male'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: const Icon(Icons.login),
                  label: Text(_loading ? 'Please wait...' : 'Continue'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _pages = const [
    MoodPage(),
    MatchPage(),
    PlaceholderPage(title: 'Material'),
    PlaceholderPage(title: 'Maps'),
    PlaceholderPage(title: 'Mission'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MoodMatch')),
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.mood), label: 'Mood'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Match'),
          NavigationDestination(icon: Icon(Icons.layers), label: 'Material'),
          NavigationDestination(icon: Icon(Icons.map), label: 'Maps'),
          NavigationDestination(icon: Icon(Icons.flag), label: 'Mission'),
        ],
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  const PlaceholderPage({super.key, required this.title});
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title (coming soon)'));
  }
}

class MoodPage extends StatefulWidget {
  const MoodPage({super.key});
  @override
  State<MoodPage> createState() => _MoodPageState();
}

class _MoodPageState extends State<MoodPage> {
  int? _userId;
  String _selectedMood = '';
  final _aiController = TextEditingController();
  final List<Map<String, String>> _messages = []; // {'who':'me/ai', 'text': '...'}

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getInt('user_id'));
  }

  Future<void> _pickMood(String mood) async {
    if (_userId == null) return;
    setState(() => _selectedMood = mood);
    await http.post(
      Uri.parse('$backendBase/mood'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': _userId, 'mood': mood}),
    );
  }

  Future<void> _sendToAI() async {
    if (_selectedMood.isEmpty || _aiController.text.trim().isEmpty) return;
    final userMsg = _aiController.text.trim();
    setState(() {
      _messages.add({'who': 'me', 'text': userMsg});
      _aiController.clear();
    });
    final resp = await http.post(
      Uri.parse('$backendBase/ai/talk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mood': _selectedMood, 'message': userMsg}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      setState(() {
        _messages.add({'who': 'ai', 'text': data['reply']});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final moods = [
      {'label': 'anger', 'emoji': '😡'},
      {'label': 'depression', 'emoji': '😞'},
      {'label': 'sad', 'emoji': '😢'},
      {'label': 'happy', 'emoji': '😄'},
      {'label': 'tired', 'emoji': '🥱'},
    ];
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select your mood:'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            children: moods.map((m) {
              final selected = _selectedMood == m['label'];
              return ChoiceChip(
                label: Text("${m['emoji']} ${m['label']}"),
                selected: selected,
                onSelected: (_) => _pickMood(m['label']!),
              );
            }).toList(),
          ),
          const Divider(height: 32),
          const Text('Chat with AI friend:'),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isMe = msg['who'] == 'me';
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.teal.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg['text'] ?? ''),
                  ),
                );
              },
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _aiController,
                  decoration: const InputDecoration(hintText: 'Type a message...'),
                ),
              ),
              IconButton(
                onPressed: _sendToAI,
                icon: const Icon(Icons.send),
              )
            ],
          )
        ],
      ),
    );
  }
}

class MatchPage extends StatefulWidget {
  const MatchPage({super.key});
  @override
  State<MatchPage> createState() => _MatchPageState();
}

class _MatchPageState extends State<MatchPage> {
  int? _userId;
  String? _roomId;
  WebSocketChannel? _channel;
  final _chatCtrl = TextEditingController();
  final List<String> _chat = [];
  String _status = 'Tap "Find Match" to look for someone.';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _userId = prefs.getInt('user_id'));
  }

  Future<void> _findMatch() async {
    if (_userId == null) return;
    setState(() {
      _status = 'Searching...';
      _roomId = null;
      _chat.clear();
      _channel?.sink.close();
      _channel = null;
    });
    final resp = await http.post(
      Uri.parse('$backendBase/match/find'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': _userId}),
    );
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data['match'] == null) {
        setState(() => _status = 'No match found yet. Ask a friend to join!');
        return;
      }
      final roomId = data['match']['room_id'];
      setState(() {
        _roomId = roomId;
        _status = 'Matched with ${data['match']['username']} (mood: ${data['match']['shared_mood']}).';
      });
      _connectWebSocket(roomId);
    } else {
      setState(() => _status = 'Error finding match.');
    }
  }

  void _connectWebSocket(String roomId) {
    // Convert http:// to ws:// (and https->wss)
    var wsUrl = backendBase.replaceFirst('http', 'ws') + '/ws/chat/$roomId';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen((event) {
      setState(() => _chat.add(event.toString()));
    }, onError: (e) {
      setState(() => _status = 'WebSocket error: $e');
    });
  }

  void _sendMsg() {
    if (_channel == null || _chatCtrl.text.trim().isEmpty) return;
    _channel!.sink.add(_chatCtrl.text.trim());
    _chatCtrl.clear();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _findMatch,
                icon: const Icon(Icons.search),
                label: const Text('Find Match'),
              ),
              const SizedBox(width: 12),
              Text(_status),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: ListView.builder(
              itemCount: _chat.length,
              itemBuilder: (ctx, i) => ListTile(
                title: Text(_chat[i]),
              ),
            ),
          ),
          if (_roomId != null) Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatCtrl,
                  decoration: const InputDecoration(hintText: 'Type message...'),
                ),
              ),
              IconButton(onPressed: _sendMsg, icon: const Icon(Icons.send)),
            ],
          )
        ],
      ),
    );
  }
}