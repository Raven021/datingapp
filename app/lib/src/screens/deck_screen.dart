import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/models.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final List<DeckCard> _cards = [];
  final Set<String> _seen = {};
  Offset _drag = Offset.zero;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final cards = await ref.read(sessionProvider).api.deck();
      if (!mounted) return;
      setState(() {
        if (reset) {
          _cards.clear();
          _seen.clear();
        }
        for (final card in cards) {
          if (_seen.add(card.id)) _cards.add(card);
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error is ApiException ? error.message : "ارتباط با سرور برقرار نشد.";
      });
    }
  }

  Future<void> _act(String direction) async {
    if (_busy || _cards.isEmpty) return;
    setState(() => _busy = true);
    final card = _cards.first;
    try {
      final match = await ref.read(sessionProvider).api.swipe(card.id, direction);
      if (!mounted) return;
      setState(() {
        _cards.removeAt(0);
        _drag = Offset.zero;
        _busy = false;
      });
      if (match != null) await _showMatch(card, match.id);
      if (_cards.length < 4) _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _drag = Offset.zero;
        _busy = false;
      });
      showError(context, error);
    }
  }

  Future<void> _showMatch(DeckCard card, String matchId) {
    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("آشنا شدید"),
          content: Text("تو و ${card.displayName} همدیگر را پسندیدید. هر کدام می‌توانید پیام اول را بفرستید."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("ادامه")),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push("/thread/$matchId?name=${Uri.encodeComponent(card.displayName)}");
              },
              child: const Text("پیام"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("آشنا"),
        actions: [
          IconButton(onPressed: () => _load(reset: true), icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: _loading && _cards.isEmpty
            ? const Center(child: CircularProgressIndicator(color: rose))
            : _cards.isEmpty
            ? _EmptyDeck(message: _error ?? "الان کسی در این شهر برای تو نیست. کمی بعد دوباره سر بزن.", onRetry: () => _load(reset: true))
            : Column(
                children: [
                  Expanded(child: _stack()),
                  const SizedBox(height: 16),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RoundAction(icon: Icons.close, onTap: _busy ? null : () => _act("pass")),
                        const SizedBox(width: 28),
                        _RoundAction(icon: Icons.favorite, filled: true, onTap: _busy ? null : () => _act("like")),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _stack() {
    final top = _cards.first;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cards.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 0),
            child: _CardFace(card: _cards[1], dimmed: true),
          ),
        GestureDetector(
          onPanUpdate: (details) => setState(() => _drag += details.delta),
          onPanEnd: (_) {
            if (_drag.dx < -90) {
              _act("pass");
            } else if (_drag.dx > 90) {
              _act("like");
            } else {
              setState(() => _drag = Offset.zero);
            }
          },
          child: Transform.translate(
            offset: _drag,
            child: Transform.rotate(
              angle: _drag.dx / 700,
              child: _CardFace(
                card: top,
                onSafety: () => confirmSafety(
                  context,
                  ref,
                  userId: top.id,
                  name: top.displayName,
                  onDone: () {
                    setState(() => _cards.removeAt(0));
                    if (_cards.length < 4) _load();
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, this.dimmed = false, this.onSafety});

  final DeckCard card;
  final bool dimmed;
  final VoidCallback? onSafety;

  @override
  Widget build(BuildContext context) {
    final facts = [card.job, card.education].whereType<String>().where((item) => item.isNotEmpty).join(" · ");
    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: paper,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView(
                      children: [
                        for (final photo in card.photos) AuthImage(photoId: photo.id),
                      ],
                    ),
                    if (onSafety != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(backgroundColor: const Color(0x66241611)),
                          onPressed: onSafety,
                          icon: const Icon(Icons.more_horiz),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${card.displayName}  ${faDigits(card.age)}", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(placeLabel(distanceKm: card.distanceKm, cityName: card.cityName), style: const TextStyle(color: muted)),
                    if (facts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(facts),
                    ],
                    if (card.bio.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(card.bio, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.5)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, this.filled = false});

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? rose : paper,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Icon(icon, color: filled ? Colors.white : ink, size: 30),
        ),
      ),
    );
  }
}

class _EmptyDeck extends StatelessWidget {
  const _EmptyDeck({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, height: 1.6)),
            const SizedBox(height: 16),
            PrimaryButton(label: "دوباره", onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
