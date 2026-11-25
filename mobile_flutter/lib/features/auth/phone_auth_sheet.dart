import 'package:flutter/material.dart';
import '../../core/constants/syria_data.dart';
import '../../core/services/supabase_service.dart';

/// Opens a smooth bottom sheet requiring Phone + OTP only when a guest
/// tries to post, chat, comment, or save a favorite.
Future<bool> requireAuth(BuildContext context) async {
  if (SupabaseService.isLoggedIn) return true;
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PhoneAuthSheet(),
  );
  return result == true;
}

class _PhoneAuthSheet extends StatefulWidget {
  const _PhoneAuthSheet();

  @override
  State<_PhoneAuthSheet> createState() => _PhoneAuthSheetState();
}

class _PhoneAuthSheetState extends State<_PhoneAuthSheet> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _governorate = 'دمشق';
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  String get _e164Phone {
    final cleaned = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final trimmed = cleaned.startsWith('0') ? cleaned.substring(1) : cleaned;
    return '+963$trimmed';
  }

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.sendOtp(_e164Phone);
      setState(() => _otpSent = true);
    } catch (e) {
      setState(() => _error = 'تعذر إرسال الرمز، تحقق من الرقم والإنترنت');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.verifyOtpAndSaveProfile(
        phoneE164: _e164Phone,
        otpCode: _otpCtrl.text.trim(),
        fullName: _nameCtrl.text.isEmpty ? 'مستخدم بلدنا' : _nameCtrl.text,
        governorate: _governorate,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = 'رمز التحقق غير صحيح أو منتهي الصلاحية');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تسجيل الدخول برقم الجوال',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'التصفح مجاني للجميع. سجّل دخولك لنشر إعلان، المراسلة، أو إضافة تعليق.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          if (!_otpSent) ...[
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الجوال السوري',
                prefixText: '+963 ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _sendOtp,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال رمز التحقق OTP'),
            ),
          ] else ...[
            TextField(
              controller: _otpCtrl,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رمز التحقق (6 أرقام)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _governorate,
              decoration: const InputDecoration(
                labelText: 'المحافظة',
                border: OutlineInputBorder(),
              ),
              items: SyriaData.governorates
                  .where((g) => g != 'الكل')
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _governorate = v ?? 'دمشق'),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تأكيد وإكمال الدخول'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
