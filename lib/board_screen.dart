import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'board_service.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({
    super.key,
    required this.board,
    required this.uid,
    required this.authorName,
  });

  final BoardService board;
  final String uid;
  final String authorName;

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final _message = TextEditingController();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _messages;

  bool _posting = false;
  bool _changingMessage = false;
  String? _pendingMessageId;
  String? _error;

  static const _testDuplicatePost =
      kDebugMode &&
      bool.fromEnvironment('USE_FIREBASE_EMULATORS') &&
      bool.fromEnvironment('TEST_DUPLICATE_POST');

  @override
  void initState() {
    super.initState();
    _messages = widget.board.messageBoard();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_posting) return;

    final text = _message.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a message first.');
      return;
    }

    setState(() {
      _posting = true;
      _error = null;
    });

    try {
      final messageId = _pendingMessageId ??= widget.board.newMessageId();

      Future<void> submit() {
        return widget.board.postMessage(
          messageId: messageId,
          authorUid: widget.uid,
          authorName: widget.authorName,
          text: text,
        );
      }

      await submit();

      if (_testDuplicatePost) {
        await submit();
        debugPrint('Duplicate test submitted the same message ID twice: $messageId');
      }

      _pendingMessageId = null;
      if (mounted) _message.clear();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == 'permission-denied'
            ? 'Firestore did not allow this post.'
            : 'Could not post your message. Try again.';
      });
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _edit(String messageId, String originalText) async {
    final formKey = GlobalKey<FormState>();
    var draft = originalText;

    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: Form(
            key: formKey,
            child: TextFormField(
              initialValue: originalText,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Message'),
              onChanged: (value) => draft = value,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a message.';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(dialogContext).pop(draft.trim());
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || newText == null || newText == originalText) return;

    await _changeMessage(
      () => widget.board.editMessage(messageId: messageId, newText: newText),
    );
  }

  Future<void> _delete(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete message?'),
          content: const Text('This will remove the message from the board.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) return;

    await _changeMessage(
      () => widget.board.deleteMessage(messageId: messageId),
    );
  }

  Future<void> _changeMessage(Future<void> Function() change) async {
    if (_changingMessage) return;
    setState(() => _changingMessage = true);

    try {
      await change();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = error.code == 'permission-denied'
          ? 'You can only change your own messages.'
          : 'Could not change this message. Try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _changingMessage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _messages,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load messages.'));
              }

              final messages = snapshot.data?.docs;
              if (messages == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (messages.isEmpty) {
                return const Center(child: Text('No messages yet.'));
              }

              return ListView.builder(
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final document = messages[index];
                  final message = document.data();
                  final text = message['text'] as String? ?? '';
                  final author = message['authorName'] as String? ?? '';
                  final isOwner = message['authorUid'] == widget.uid;

                  return ListTile(
                    title: Text(text),
                    subtitle: Text(author),
                    trailing: isOwner
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit message',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: _changingMessage
                                    ? null
                                    : () => _edit(document.id, text),
                              ),
                              IconButton(
                                tooltip: 'Delete message',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _changingMessage
                                    ? null
                                    : () => _delete(document.id),
                              ),
                            ],
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _message,
                  enabled: !_posting,
                  maxLength: 500,
                  onChanged: (_) => _pendingMessageId = null,
                  decoration: InputDecoration(
                    labelText: 'Message',
                    errorText: _error,
                  ),
                ),
                FilledButton(
                  onPressed: _posting ? null : _post,
                  child: Text(_posting ? 'Posting...' : 'Post'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}