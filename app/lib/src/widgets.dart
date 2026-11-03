import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";

void showError(BuildContext context, Object error) {
  final message = error is ApiException ? error.message : "ارتباط با سرور برقرار نشد.";
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
          : Text(label),
    );
  }
}

class AuthImage extends ConsumerWidget {
  const AuthImage({super.key, required this.photoId, this.fit = BoxFit.cover});

  final String photoId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final token = session.tokens.access;
    return Image.network(
      session.api.mediaUrl(photoId),
      fit: fit,
      headers: token == null ? null : {"Authorization": "Bearer $token"},
      errorBuilder: (_, _, _) => const ColoredBox(color: line),
      loadingBuilder: (context, child, progress) => progress == null ? child : const ColoredBox(color: line),
    );
  }
}

class ChoiceWrap extends StatelessWidget {
  const ChoiceWrap({super.key, required this.values, required this.selected, required this.onTap});

  final List<String> values;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          FilterChip(
            label: Text(genderLabels[value] ?? value),
            selected: selected.contains(value),
            showCheckmark: false,
            selectedColor: rose.withValues(alpha: 0.16),
            labelStyle: TextStyle(
              fontFamily: "Vazirmatn",
              fontWeight: FontWeight.w600,
              color: selected.contains(value) ? rose : ink,
            ),
            side: BorderSide(color: selected.contains(value) ? rose : line),
            onSelected: (_) => onTap(value),
          ),
      ],
    );
  }
}

Future<void> confirmSafety(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  required VoidCallback onDone,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text("مسدود کردن"), onTap: () => Navigator.pop(context, "block")),
            ListTile(title: const Text("گزارش"), onTap: () => Navigator.pop(context, "report")),
          ],
        ),
      );
    },
  );
  if (action == null || !context.mounted) return;
  final api = ref.read(sessionProvider).api;
  try {
    if (action == "block") {
      await api.blockUser(userId);
    } else {
      final reason = await askReason(context, name);
      if (reason == null || !context.mounted) return;
      await api.report(userId, reason);
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("انجام شد. دیگر همدیگر را نمی‌بینید.")));
    onDone();
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

Future<String?> askReason(BuildContext context, String name) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text("گزارش $name"),
        content: TextField(controller: controller, maxLength: 300, decoration: const InputDecoration(hintText: "چه اتفاقی افتاد؟")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("انصراف")),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text("ثبت"),
          ),
        ],
      );
    },
  );
}
