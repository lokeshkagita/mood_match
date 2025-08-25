import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class ChatPage extends StatefulWidget {
  final String roomId;
  final int userId;

  ChatPage({required this.roomId, required this.userId});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late WebSocketChannel channel;
  final TextEditingController _controller = TextEditingController();
  List<String> messages = [];

  String _getWsUrl(String roomId, int userId) {
    if (kIsWeb) {
      // Running on Flutter Web → connect to localhost
      return "ws://127.0.0.1:8000/ws/$roomId/$userId";
    } else if (Platform.isAndroid) {
      // Android Emulator → connect via 10.0.2.2
      return "ws://10.0.2.2:8000/ws/$roomId/$userId";
    } else {
      // iOS simulator / desktop → localhost
      return "ws://127.0.0.1:8000/ws/$roomId/$userId";
    }
  }

  @override
  void initState() {
    super.initState();
    channel = WebSocketChannel.connect(
      Uri.parse(_getWsUrl(widget.roomId, widget.userId)),
    );

    channel.stream.listen((message) {
      setState(() {
        messages.add(message);
      });
    });
  }

  void _sendMessage() {
    if (_controller.text.isNotEmpty) {
      channel.sink.add(_controller.text);
      _controller.clear();
    }
  }

  void _leaveChat() {
    channel.sink.add("__leave__");
    channel.sink.close();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Room: ${widget.roomId}"),
        actions: [
          IconButton(
            icon: Icon(Icons.exit_to_app, color: Colors.red),
            onPressed: _leaveChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: messages.length,
              itemBuilder: (_, index) => ListTile(
                title: Text(messages[index]),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: _controller)),
              IconButton(icon: Icon(Icons.send), onPressed: _sendMessage),
            ],
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    channel.sink.close();
    super.dispose();
  }
}
