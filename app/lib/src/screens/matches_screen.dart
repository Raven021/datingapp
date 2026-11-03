import "dart:async";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/models.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class MatchesScreen extends ConsumerStatefulWidget {
  const MatchesScreen({super.key});

  @override
  ConsumerState<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends ConsumerState<MatchesScreen> {
  List<MatchPreview> _matches = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final matches = await ref.read(sessionProvider).api.matches();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || silent) return;
      setState(() => _loading = false);
      showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("گفتگوها")),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: rose))
          : _matches.isEmpty
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: Text("هنوز گفتگویی نداری. وقتی هر دو نفر پسندید، این‌جا می‌آید.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, height: 1.6))))
          : RefreshIndicator(
              color: rose,
              onRefresh: _load,
              child: ListView.separated(
                itemCount: _matches.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: line),
                itemBuilder: (context, index) {
                  final match = _matches[index];
                  final other = match.other;
                  final name = other?.displayName ?? "کاربر";
                  final subtitle = match.needsReply
                      ? "جواب بده تا گفتگو باز شود"
                      : match.waitingForReply
                      ? "منتظر جواب"
                      : match.lastMessage?.body ?? "هنوز پیامی نیست";
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: ClipOval(
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: other?.photoId == null
                            ? const ColoredBox(color: line, child: Icon(Icons.person, color: muted))
                            : AuthImage(photoId: other!.photoId!),
                      ),
                    ),
                    title: Text("$name${other == null ? "" : "  ${faDigits(other.age)}"}", style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () async {
                      await context.push("/thread/${match.id}?name=${Uri.encodeComponent(name)}");
                      if (mounted) _load(silent: true);
                    },
                  );
                },
              ),
            ),
    );
  }
}
