import "dart:io";

import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:image_picker/image_picker.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/jalali.dart";
import "package:ashna/src/models.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _job = TextEditingController();
  final _education = TextEditingController();
  final _picker = ImagePicker();

  int _step = 0;
  int _year = 1375;
  int _month = 1;
  int _day = 1;
  String? _gender;
  final Set<String> _show = {};
  String? _cityId;
  List<CityOption> _cities = [];
  List<XFile> _localPhotos = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(sessionProvider).me?.profile;
    if (profile != null) {
      _name.text = profile.displayName;
      _bio.text = profile.bio;
      _job.text = profile.job ?? "";
      _education.text = profile.education ?? "";
      _gender = profile.gender;
      _show.addAll(profile.showGenders);
      _cityId = profile.cityId;
      final parts = profile.birthDate.split("-");
      if (parts.length == 3) {
        final jalali = toJalaali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        _year = jalali.year;
        _month = jalali.month;
        _day = jalali.day;
      }
    }
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final cities = await ref.read(sessionProvider).api.cities();
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _job.dispose();
    _education.dispose();
    super.dispose();
  }

  int get _existingPhotos => ref.read(sessionProvider).me?.profile?.photos.length ?? 0;

  String? _stepError() {
    switch (_step) {
      case 0:
        if (_name.text.trim().length < 2) return "اسم باید حداقل دو حرف باشد.";
      case 1:
        if (!isValidJalali(_year, _month, _day)) return "این تاریخ در تقویم شمسی نیست.";
        final birth = toGregorian(_year, _month, _day);
        if (!isAdultBirth(birth)) return "برای ساخت حساب باید حداقل ۱۸ سال داشته باشی.";
      case 2:
        if (_gender == null) return "جنسیت را انتخاب کن.";
      case 3:
        if (_show.isEmpty) return "بگو چه کسانی را می‌خواهی ببینی.";
      case 4:
        if (_cityId == null) return "شهر را انتخاب کن.";
      case 5:
        if (_bio.text.trim().length > 300) return "بیو بلند است.";
      case 6:
        final total = _existingPhotos + _localPhotos.length;
        if (total < 2) return "حداقل دو عکس لازم است.";
        if (total > 6) return "بیشتر از ۶ عکس نمی‌توانی بگذاری.";
    }
    return null;
  }

  Future<void> _next() async {
    final problem = _stepError();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_step < 6) {
      setState(() {
        _error = null;
        _step += 1;
      });
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(sessionProvider);
    try {
      await session.api.saveProfile({
        "displayName": _name.text.trim(),
        "birthDate": toGregorian(_year, _month, _day).iso(),
        "gender": _gender,
        "showGenders": _show.toList(),
        "cityId": _cityId,
        "bio": _bio.text.trim(),
        "job": _job.text.trim(),
        "education": _education.text.trim(),
      });
      for (final photo in _localPhotos) {
        await session.api.uploadPhoto(photo.path);
      }
      _localPhotos = [];
      await session.reload();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException ? error.message : "ارتباط با سرور برقرار نشد.");
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addPhotos() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (!mounted || picked.isEmpty) return;
    setState(() {
      final room = 6 - _existingPhotos - _localPhotos.length;
      _localPhotos = [..._localPhotos, ...picked.take(room)];
    });
  }

  @override
  Widget build(BuildContext context) {
    final titles = ["اسمت چیست؟", "تاریخ تولد", "جنسیت", "چه کسانی را می‌بینی؟", "کدام شهر؟", "کمی از خودت", "عکس‌ها"];
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(
                onPressed: _busy ? null : () => setState(() => _step -= 1),
                icon: const Icon(Icons.arrow_forward),
              ),
        title: Text("${faDigits(_step + 1)} از ۷"),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titles[_step], style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(_hint(), style: const TextStyle(color: muted, height: 1.5)),
            const SizedBox(height: 24),
            Expanded(child: _body()),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: rose)),
              const SizedBox(height: 12),
            ],
            PrimaryButton(label: _step == 6 ? "ورود به آشنا" : "بعدی", busy: _busy, onPressed: _next),
          ],
        ),
      ),
    );
  }

  String _hint() {
    return switch (_step) {
      1 => "سن از روی تاریخ تولد حساب می‌شود و سال تولد دقیق نشان داده نمی‌شود.",
      3 => "زن، مرد، یا هر دو. همین انتخاب برای همه است.",
      4 => "شماره موبایل شهر را معلوم نمی‌کند. خودت انتخاب می‌کنی.",
      6 => "حداقل دو عکس واضح. بدون تار کردن.",
      _ => "بعداً هم می‌توانی عوضش کنی.",
    };
  }

  Widget _body() {
    return switch (_step) {
      0 => TextField(controller: _name, textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: "مثلاً تینا")),
      1 => _birthFields(),
      2 => ChoiceWrap(
        values: genderOrder,
        selected: _gender == null ? {} : {_gender!},
        onTap: (value) => setState(() => _gender = value),
      ),
      3 => ChoiceWrap(
        values: genderOrder,
        selected: _show,
        onTap: (value) => setState(() {
          if (!_show.add(value)) _show.remove(value);
        }),
      ),
      4 => _cityPicker(),
      5 => ListView(
        children: [
          TextField(controller: _job, decoration: const InputDecoration(labelText: "شغل، اختیاری")),
          const SizedBox(height: 12),
          TextField(controller: _education, decoration: const InputDecoration(labelText: "تحصیل، اختیاری")),
          const SizedBox(height: 12),
          TextField(controller: _bio, maxLength: 300, maxLines: 4, decoration: const InputDecoration(labelText: "بیو، اختیاری")),
        ],
      ),
      _ => _photos(),
    };
  }

  Widget _birthFields() {
    final years = [for (var year = 1387; year >= 1320; year--) year];
    final days = daysInJalaliMonth(_year, _month);
    if (_day > days) _day = days;
    return Row(
      children: [
        Expanded(child: _drop("سال", _year, years, (value) => setState(() => _year = value))),
        const SizedBox(width: 8),
        Expanded(
          child: _drop("ماه", _month, [for (var month = 1; month <= 12; month++) month], (value) => setState(() => _month = value), labelOf: (value) => jalaliMonths[value - 1]),
        ),
        const SizedBox(width: 8),
        Expanded(child: _drop("روز", _day, [for (var day = 1; day <= days; day++) day], (value) => setState(() => _day = value))),
      ],
    );
  }

  Widget _drop(String label, int value, List<int> items, ValueChanged<int> onChanged, {String Function(int value)? labelOf}) {
    return DropdownButtonFormField<int>(
      key: ValueKey("$label-$value-${items.length}"),
      initialValue: items.contains(value) ? value : items.first,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in items)
          DropdownMenuItem(value: item, child: Text(labelOf?.call(item) ?? faDigits(item))),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    );
  }

  Widget _cityPicker() {
    if (_cities.isEmpty) return const Center(child: CircularProgressIndicator(color: rose));
    return DropdownButtonFormField<String>(
      initialValue: _cityId,
      decoration: const InputDecoration(labelText: "شهر"),
      items: [for (final city in _cities) DropdownMenuItem(value: city.id, child: Text(city.nameFa))],
      onChanged: (value) => setState(() => _cityId = value),
    );
  }

  Widget _photos() {
    final existing = ref.watch(sessionProvider).me?.profile?.photos ?? const <PhotoRef>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final photo in existing)
                ClipRRect(borderRadius: BorderRadius.circular(16), child: AuthImage(photoId: photo.id)),
              for (var index = 0; index < _localPhotos.length; index++)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(_localPhotos[index].path), fit: BoxFit.cover)),
                    Positioned(
                      top: 4,
                      left: 4,
                      child: IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: ink),
                        onPressed: () => setState(() => _localPhotos.removeAt(index)),
                        icon: const Icon(Icons.close, size: 16),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        OutlinedButton.icon(onPressed: _addPhotos, icon: const Icon(Icons.photo_outlined), label: const Text("انتخاب عکس")),
      ],
    );
  }
}
