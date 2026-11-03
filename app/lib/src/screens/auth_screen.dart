import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class BootScreen extends StatelessWidget {
  const BootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text("آشنا", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({super.key});

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _phone = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider).requestOtp(_phone.text);
      if (!mounted) return;
      context.push("/auth/otp");
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("آشنا", style: TextStyle(fontSize: 48, fontWeight: FontWeight.w600, height: 1)),
              const SizedBox(height: 12),
              const Text("برای قرارهای داخل ایران. هر دو نفر باید همدیگر را پسندیده باشند.", style: TextStyle(fontSize: 16, height: 1.6, color: muted)),
              const Spacer(),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: "شماره موبایل", hintText: "۰۹۱۲۳۴۵۶۷۸۹"),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: "دریافت کد", busy: _busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider).verify(_code.text);
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devCode = ref.watch(sessionProvider).devCode;
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("کد ورود", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              devCode == null ? "کد را از پیامک وارد کن." : "کد آزمایشی: ${faDigits(devCode)}",
              style: const TextStyle(color: muted, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(counterText: "", hintText: "······"),
              onSubmitted: (_) => _submit(),
            ),
            const Spacer(),
            PrimaryButton(label: "ورود", busy: _busy, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}
