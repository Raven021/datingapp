import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/models.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.matchId, required this.name});

  final String matchId;
  final String name;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  ThreadData? _thread;
  Timer? _timer;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final thread = await ref.read(sessionProvider).api.messages(widget.matchId);
      if (!mounted) return;
      final grew = (_thread?.messages.length ?? 0) != thread.messages.length;
      setState(() => _thread = thread);
      if (grew) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
        });
      }
    } catch (error) {
      if (!mounted || silent) return;
      showError(context, error);
    }
  }

  Future<void> _send() async {
    final thread = _thread;
    final body = _text.text.trim();
    if (thread == null || body.isEmpty || _sending) return;
    final mine = thread.messages.where((message) => message.mine).length;
    final theirs = thread.messages.length - mine;
    if (mine > 0 && theirs == 0) return;
    if (mine == 0 && theirs == 0 && !isValidOpener(body)) {
      showError(context, ApiException("OPENER_TOO_SHORT", "پیام اول باید حداقل دو کلمه باشد."));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(sessionProvider).api.sendMessage(widget.matchId, body);
      _text.clear();
      await _load(silent: true);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _menu(String action) async {
    final thread = _thread;
    if (thread == null) return;
    final api = ref.read(sessionProvider).api;
    try {
      if (action == "unmatch") {
        await api.unmatch(widget.matchId);
        if (mounted) Navigator.of(context).pop();
        return;
      }
      if (action == "block") {
        await api.blockUser(thread.otherId);
      } else if (action == "report") {
        final reason = await askReason(context, widget.name);
        if (reason == null || !mounted) return;
        await api.report(thread.otherId, reason);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = _thread;
    final mine = thread?.messages.where((message) => message.mine).length ?? 0;
    final theirs = (thread?.messages.length ?? 0) - mine;
    final locked = mine > 0 && theirs == 0;
    final opener = mine == 0 && theirs == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (context) => const [
              PopupMenuItem(value: "unmatch", child: Text("قطع ارتباط")),
              PopupMenuItem(value: "block", child: Text("مسدود کردن")),
              PopupMenuItem(value: "report", child: Text("گزارش")),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: thread == null
                ? const Center(child: CircularProgressIndicator(color: rose))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    itemCount: thread.messages.length,
                    itemBuilder: (context, index) {
                      final message = thread.messages[index];
                      return Align(
                        alignment: message.mine ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          decoration: BoxDecoration(
                            color: message.mine ? rose : paper,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(message.body, style: TextStyle(color: message.mine ? Colors.white : ink, height: 1.4)),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: locked
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text("تا وقتی جواب ندهد پیام دیگری نمی‌توانی بفرستی.", textAlign: TextAlign.center, style: TextStyle(color: muted)),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(hintText: opener ? "حداقل دو کلمه" : "پیام"),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: rose),
                          onPressed: _sending ? null : _send,
                          icon: const Icon(Icons.send),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
