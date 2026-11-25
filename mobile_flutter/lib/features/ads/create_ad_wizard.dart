import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/syria_data.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';

/// 9-Step Guided Ad & Service Publishing Wizard
class CreateAdWizard extends StatefulWidget {
  const CreateAdWizard({super.key});

  @override
  State<CreateAdWizard> createState() => _CreateAdWizardState();
}

class _CreateAdWizardState extends State<CreateAdWizard> {
  int _step = 0; // 0..8 (9 steps)
  String _categoryId = 'services';
  String _subcategory = 'سباك';
  final List<File> _photos = [];
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  String _currency = 'SYP';
  bool _negotiable = true;
  String _condition = 'used';
  String _adType = 'sell';
  String _governorate = 'دمشق';
  LatLng _location = const LatLng(33.5138, 36.2765);
  bool _submitting = false;

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() {
        for (final x in picked) {
          if (_photos.length < 8) _photos.add(File(x.path));
        }
      });
    }
  }

  Future<void> _publish() async {
    setState(() => _submitting = true);
    try {
      await SupabaseService.publishAd(
        adPayload: {
          'category_id': _categoryId,
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim()) ?? 0,
          'currency': _currency,
          'is_negotiable': _negotiable,
          'condition': _condition,
          'ad_type': _adType,
          'governorate': _governorate,
          'area': _areaCtrl.text.trim(),
          'latitude': _location.latitude,
          'longitude': _location.longitude,
        },
        images: _photos,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم نشر إعلانك بنجاح!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء النشر: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = SyriaData.categories.firstWhere((c) => c.id == _categoryId);
    final user = SupabaseService.currentUser;

    return Scaffold(
      appBar: AppBar(title: Text('نشر إعلان (خطوة ${_step + 1} من 9)')),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_step + 1) / 9,
            color: AppTheme.primary,
            minHeight: 5,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildStepBody(cat, user?.phone ?? ''),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      child: const Text('السابق'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            if (_step < 8) {
                              setState(() => _step++);
                            } else {
                              _publish();
                            }
                          },
                    child: _submitting
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(_step < 8 ? 'التالي' : 'نشر الإعلان الآن'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepBody(CategoryMeta cat, String userPhone) {
    switch (_step) {
      case 0: // 1. Category & Subcategory
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. اختر القسم والصنف الفرعي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'القسم الرئيسي', border: OutlineInputBorder()),
              items: SyriaData.categories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameAr)))
                  .toList(),
              onChanged: (v) {
                final next = SyriaData.categories.firstWhere((c) => c.id == v);
                setState(() {
                  _categoryId = next.id;
                  _subcategory = next.subcategories.first;
                });
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: cat.subcategories
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _subcategory == s,
                        onSelected: (_) => setState(() => _subcategory = s),
                      ))
                  .toList(),
            ),
          ],
        );
      case 1: // 2. Images (up to 8 with auto-compression)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('2. أضف صور الإعلان (حتى 8 صور)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('يتم ضغط الصور تلقائياً لتعمل بسرعة مع الإنترنت الضعيف.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: Text('اختيار صور (${_photos.length}/8)'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _photos
                  .map((f) => ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(f, width: 88, height: 88, fit: BoxFit.cover),
                      ))
                  .toList(),
            ),
          ],
        );
      case 2: // 3. Title & Description
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3. العنوان والوصف', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'عنوان الإعلان', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'الوصف التفصيلي', border: OutlineInputBorder()),
            ),
          ],
        );
      case 3: // 4. Price & Currency
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('4. السعر والعملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'SYP', child: Text('ل.س')),
                      DropdownMenuItem(value: 'USD', child: Text('دولار \$')),
                    ],
                    onChanged: (v) => setState(() => _currency = v ?? 'SYP'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SwitchListTile(
              title: const Text('السعر قابل للتفاوض'),
              value: _negotiable,
              onChanged: (v) => setState(() => _negotiable = v),
            ),
          ],
        );
      case 4: // 5. Condition & Ad Type
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('5. الحالة ونوع الإعلان', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'new', label: Text('جديد')),
                ButtonSegment(value: 'used', label: Text('مستعمل')),
              ],
              selected: {_condition},
              onSelectionChanged: (s) => setState(() => _condition = s.first),
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'sell', label: Text('بيع')),
                ButtonSegment(value: 'rent', label: Text('إيجار')),
                ButtonSegment(value: 'service', label: Text('خدمة')),
              ],
              selected: {_adType},
              onSelectionChanged: (s) => setState(() => _adType = s.first),
            ),
          ],
        );
      case 5: // 6. Governorate & Area
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('6. المحافظة والمنطقة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _governorate,
              decoration: const InputDecoration(labelText: 'المحافظة', border: OutlineInputBorder()),
              items: SyriaData.governorates
                  .where((g) => g != 'الكل')
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) {
                final gov = v ?? 'دمشق';
                final coords = SyriaData.governorateCoords[gov] ?? [33.5138, 36.2765];
                setState(() {
                  _governorate = gov;
                  _location = LatLng(coords[0], coords[1]);
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _areaCtrl,
              decoration: const InputDecoration(labelText: 'المنطقة / الحي', border: OutlineInputBorder()),
            ),
          ],
        );
      case 6: // 7. OpenStreetMap Location Picker (Works reliably inside Syria)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('7. حدد الموقع على الخريطة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('اضغط على الخريطة لوضع الدبوس (OpenStreetMap).', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: _location,
                    initialZoom: 13,
                    onTap: (_, latLng) => setState(() => _location = latLng),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'sy.baladna.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _location,
                          width: 44,
                          height: 44,
                          child: const Icon(Icons.location_pin, color: AppTheme.accent, size: 42),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      case 7: // 8. Auto Account Info
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('8. بيانات التواصل (تلقائي من حسابك)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text('رقم الجوال: $userPhone'),
                Text('المحافظة: $_governorate'),
              ],
            ),
          ),
        );
      default: // 9. Preview & Publish
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('9. معاينة قبل النشر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Divider(),
                Text(_titleCtrl.text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${_priceCtrl.text} ${_currency == 'USD' ? '\$' : 'ل.س'} ${_negotiable ? '(قابل للتفاوض)' : ''}',
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('${cat.nameAr} › $_subcategory • $_governorate - ${_areaCtrl.text}'),
                const SizedBox(height: 8),
                Text(_descCtrl.text),
              ],
            ),
          ),
        );
    }
  }
}
