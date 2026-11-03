import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:geolocator/geolocator.dart";
import "package:image_picker/image_picker.dart";
import "package:ashna/src/api.dart";
import "package:ashna/src/format.dart";
import "package:ashna/src/jalali.dart";
import "package:ashna/src/models.dart";
import "package:ashna/src/session.dart";
import "package:ashna/src/theme.dart";
import "package:ashna/src/widgets.dart";

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _bio = TextEditingController();
  final _job = TextEditingController();
  final _education = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _picker = ImagePicker();

  List<CityOption> _cities = [];
  String? _cityId;
  String? _gender;
  final Set<String> _show = {};
  int _year = 1375;
  int _month = 1;
  int _day = 1;
  RangeValues _ages = const RangeValues(18, 40);
  double _distance = 50;
  bool _location = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fill(ref.read(sessionProvider).me?.profile);
    _loadCities();
  }

  void _fill(Profile? profile) {
    if (profile == null) return;
    _name.text = profile.displayName;
    _bio.text = profile.bio;
    _job.text = profile.job ?? "";
    _education.text = profile.education ?? "";
    _cityId = profile.cityId;
    _gender = profile.gender;
    _show
      ..clear()
      ..addAll(profile.showGenders);
    _ages = RangeValues(profile.ageMin.toDouble(), profile.ageMax.toDouble());
    _distance = profile.maxDistanceKm.toDouble();
    _location = profile.hasLocation;
    final parts = profile.birthDate.split("-");
    if (parts.length == 3) {
      final jalali = toJalaali(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      _year = jalali.year;
      _month = jalali.month;
      _day = jalali.day;
    }
  }

  Future<void> _loadCities() async {
    try {
      final cities = await ref.read(sessionProvider).api.cities();
      if (mounted) setState(() => _cities = cities);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    _job.dispose();
    _education.dispose();
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_gender == null || _cityId == null || _show.isEmpty) {
      showError(context, ApiException("VALIDATION", "اطلاعات پروفایل کامل نیست."));
      return;
    }
    if (!isValidJalali(_year, _month, _day) || !isAdultBirth(toGregorian(_year, _month, _day))) {
      showError(context, ApiException("UNDERAGE", "تاریخ تولد باید برای ۱۸ سال به بالا باشد."));
      return;
    }
    if (_ages.start > _ages.end) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider).api.saveProfile({
        "displayName": _name.text.trim(),
        "birthDate": toGregorian(_year, _month, _day).iso(),
        "gender": _gender,
        "showGenders": _show.toList(),
        "cityId": _cityId,
        "bio": _bio.text.trim(),
        "job": _job.text.trim(),
        "education": _education.text.trim(),
        "ageMin": _ages.start.round(),
        "ageMax": _ages.end.round(),
        "maxDistanceKm": _distance.round(),
      });
      await ref.read(sessionProvider).reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ذخیره شد.")));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleLocation(bool enabled) async {
    final api = ref.read(sessionProvider).api;
    try {
      if (!enabled) {
        await api.clearLocation();
        await ref.read(sessionProvider).reload();
        if (mounted) setState(() => _location = false);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) showError(context, ApiException("LOCATION", "اجازه موقعیت داده نشد. بدون آن فقط هم‌شهری‌ها را می‌بینی."));
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await api.setLocation(position.latitude, position.longitude);
      await ref.read(sessionProvider).reload();
      if (mounted) setState(() => _location = true);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _addPhoto() async {
    final profile = ref.read(sessionProvider).me?.profile;
    if (profile != null && profile.photos.length >= 6) {
      showError(context, ApiException("PHOTO_LIMIT", "بیشتر از ۶ عکس نمی‌توانی بگذاری."));
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    try {
      await ref.read(sessionProvider).api.uploadPhoto(file.path);
      await ref.read(sessionProvider).reload();
      if (mounted) setState(() => _fill(ref.read(sessionProvider).me?.profile));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _removePhoto(String id) async {
    final count = ref.read(sessionProvider).me?.profile?.photos.length ?? 0;
    if (count <= 2) {
      showError(context, ApiException("PHOTO_LIMIT", "حداقل دو عکس لازم است."));
      return;
    }
    try {
      await ref.read(sessionProvider).api.deletePhoto(id);
      await ref.read(sessionProvider).reload();
      if (mounted) setState(() => _fill(ref.read(sessionProvider).me?.profile));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _makeFirst(int index) async {
    final photos = ref.read(sessionProvider).me?.profile?.photos ?? [];
    final ids = photos.map((photo) => photo.id).toList();
    final id = ids.removeAt(index);
    ids.insert(0, id);
    try {
      await ref.read(sessionProvider).api.reorderPhotos(ids);
      await ref.read(sessionProvider).reload();
      if (mounted) setState(() => _fill(ref.read(sessionProvider).me?.profile));
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _blockPhone() async {
    try {
      await ref.read(sessionProvider).api.blockPhone(_phone.text);
      _phone.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("مسدود شد. خبری به آن شماره نمی‌رسد.")));
      }
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("حذف حساب"),
        content: const Text("عکس‌ها و گفتگوها بسته می‌شوند. با همین شماره می‌توانی دوباره ثبت‌نام کنی."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("انصراف")),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text("حذف")),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref.read(sessionProvider).api.deleteAccount();
      await ref.read(sessionProvider).clearLocal();
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(sessionProvider).me?.profile?.photos ?? const <PhotoRef>[];
    final days = daysInJalaliMonth(_year, _month);
    return Scaffold(
      appBar: AppBar(title: const Text("پروفایل")),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == photos.length) {
                  return InkWell(
                    onTap: _addPhoto,
                    child: Container(
                      width: 96,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(16), border: Border.all(color: line)),
                      child: const Icon(Icons.add),
                    ),
                  );
                }
                final photo = photos[index];
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(width: 96, height: 120, child: AuthImage(photoId: photo.id)),
                    ),
                    Positioned(
                      top: 2,
                      left: 2,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _removePhoto(photo.id),
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                      ),
                    ),
                    if (index > 0)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _makeFirst(index),
                          icon: const Icon(Icons.star, size: 16, color: Colors.white),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Text("ستاره، عکس را می‌آورد جلو.", style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 16),
          TextField(controller: _name, decoration: const InputDecoration(labelText: "اسم")),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _yearDrop()),
              const SizedBox(width: 8),
              Expanded(child: _monthDrop()),
              const SizedBox(width: 8),
              Expanded(child: _dayDrop(days)),
            ],
          ),
          const SizedBox(height: 16),
          const Text("جنسیت"),
          const SizedBox(height: 8),
          ChoiceWrap(
            values: genderOrder,
            selected: _gender == null ? {} : {_gender!},
            onTap: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          const Text("می‌خواهم ببینم"),
          const SizedBox(height: 8),
          ChoiceWrap(
            values: genderOrder,
            selected: _show,
            onTap: (value) => setState(() {
              if (!_show.add(value)) _show.remove(value);
            }),
          ),
          const SizedBox(height: 16),
          if (_cities.isNotEmpty)
            DropdownButtonFormField<String>(
              key: ValueKey(_cityId),
              initialValue: _cityId,
              decoration: const InputDecoration(labelText: "شهر"),
              items: [for (final city in _cities) DropdownMenuItem(value: city.id, child: Text(city.nameFa))],
              onChanged: (value) => setState(() => _cityId = value),
            ),
          const SizedBox(height: 12),
          TextField(controller: _job, decoration: const InputDecoration(labelText: "شغل")),
          const SizedBox(height: 12),
          TextField(controller: _education, decoration: const InputDecoration(labelText: "تحصیل")),
          const SizedBox(height: 12),
          TextField(controller: _bio, maxLength: 300, maxLines: 3, decoration: const InputDecoration(labelText: "بیو")),
          const SizedBox(height: 8),
          Text("سن ${faDigits(_ages.start.round())} تا ${faDigits(_ages.end.round())}"),
          RangeSlider(
            values: _ages,
            min: 18,
            max: 80,
            divisions: 62,
            activeColor: rose,
            onChanged: (values) => setState(() => _ages = values),
          ),
          Text("بیشترین فاصله ${faDigits(_distance.round())} کیلومتر"),
          Slider(
            value: _distance,
            min: 1,
            max: 150,
            divisions: 149,
            activeColor: rose,
            onChanged: (value) => setState(() => _distance = value),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("موقعیت تقریبی"),
            subtitle: const Text("فاصله را گرد نشان می‌دهد. مختصات ذخیره می‌شود و به کسی نشان داده نمی‌شود. اگر خاموش باشد فقط هم‌شهری‌ها را می‌بینی."),
            value: _location,
            activeThumbColor: rose,
            onChanged: _toggleLocation,
          ),
          const SizedBox(height: 8),
          PrimaryButton(label: "ذخیره", busy: _busy, onPressed: _save),
          const SizedBox(height: 28),
          const Text("مسدود کردن با شماره", style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text("حتی اگر آن شخص حسابش را پاک کند و دوباره بسازد، همدیگر را نمی‌بینید.", style: TextStyle(color: muted, height: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(hintText: "۰۹۱۲…"),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _blockPhone, child: const Text("مسدود کن")),
          const SizedBox(height: 24),
          TextButton(onPressed: () => ref.read(sessionProvider).logout(), child: const Text("خروج")),
          TextButton(onPressed: _delete, child: const Text("حذف حساب", style: TextStyle(color: rose))),
        ],
      ),
    );
  }

  Widget _yearDrop() {
    return DropdownButtonFormField<int>(
      key: ValueKey("y-$_year"),
      initialValue: _year,
      decoration: const InputDecoration(labelText: "سال"),
      items: [for (var year = 1387; year >= 1320; year--) DropdownMenuItem(value: year, child: Text(faDigits(year)))],
      onChanged: (value) {
        if (value != null) setState(() => _year = value);
      },
    );
  }

  Widget _monthDrop() {
    return DropdownButtonFormField<int>(
      key: ValueKey("m-$_month"),
      initialValue: _month,
      decoration: const InputDecoration(labelText: "ماه"),
      items: [for (var month = 1; month <= 12; month++) DropdownMenuItem(value: month, child: Text(jalaliMonths[month - 1]))],
      onChanged: (value) {
        if (value != null) setState(() => _month = value);
      },
    );
  }

  Widget _dayDrop(int days) {
    final day = _day > days ? days : _day;
    return DropdownButtonFormField<int>(
      key: ValueKey("d-$day-$days"),
      initialValue: day,
      decoration: const InputDecoration(labelText: "روز"),
      items: [for (var value = 1; value <= days; value++) DropdownMenuItem(value: value, child: Text(faDigits(value)))],
      onChanged: (value) {
        if (value != null) setState(() => _day = value);
      },
    );
  }
}
