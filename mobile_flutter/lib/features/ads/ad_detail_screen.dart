import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/phone_auth_sheet.dart';
import '../chat/chat_screen.dart';

class AdDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ad;
  const AdDetailScreen({super.key, required this.ad});

  @override
  State<AdDetailScreen> createState() => _AdDetailScreenState();
}

class _AdDetailScreenState extends State<AdDetailScreen> {
  final _commentCtrl = TextEditingController();
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final rows = await SupabaseService.client
        .from('comments')
        .select('*, profiles(full_name)')
        .eq('ad_id', widget.ad['id'])
        .order('created_at', ascending: true);
    if (mounted) setState(() => _comments = List<Map<String, dynamic>>.from(rows));
  }

  Future<void> _openMaps() async {
    final lat = widget.ad['latitude'];
    final lng = widget.ad['longitude'];
    if (lat == null || lng == null) return;
    final uri = Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(widget.ad['title'] ?? '')})');
    final webUri = Uri.parse('https://www.openstreetmap.org/?mlat=$lat&mlon=$lng#map=16/$lat/$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = widget.ad;
    final seller = (ad['profiles'] as Map<String, dynamic>?) ?? {};
    final phone = (seller['phone'] ?? '').toString();
    final price = '${ad['price']} ${ad['currency'] == 'USD' ? '\$' : 'ل.س'}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الإعلان'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: () => Share.share('${ad['title']} - $price عبر تطبيق بلدنا'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(ad['title'] ?? '', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.primary)),
          const SizedBox(height: 8),
          Text('${ad['governorate']} - ${ad['area']}'),
          const SizedBox(height: 16),

          // Seller Info + Verified Badge
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Row(
                children: [
                  Text(seller['full_name'] ?? 'معلن بلدنا', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (seller['is_verified'] == true) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 18),
                  ],
                ],
              ),
              subtitle: Text('التقييم: ${seller['rating_avg'] ?? 0} ★ (${seller['reviews_count'] ?? 0})'),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Call, WhatsApp, Chat
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                  icon: const Icon(Icons.phone_rounded, size: 18),
                  label: const Text('اتصال'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F9D55)),
                  onPressed: () => launchUrl(
                    Uri.parse('https://wa.me/${phone.replaceAll('+', '')}'),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('واتساب'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)),
                  onPressed: () async {
                    if (!await requireAuth(context)) return;
                    final convId = await SupabaseService.getOrCreateConversation(
                      adId: ad['id'],
                      sellerId: ad['user_id'],
                    );
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: convId,
                          peerName: seller['full_name'] ?? 'المعلن',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('دردشة'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Description
          Text(ad['description'] ?? '', style: const TextStyle(fontSize: 14, height: 1.6)),
          const SizedBox(height: 14),

          // Open in Maps button
          if (ad['latitude'] != null)
            OutlinedButton.icon(
              onPressed: _openMaps,
              icon: const Icon(Icons.map_rounded),
              label: const Text('فتح الموقع في الخرائط'),
            ),

          const Divider(height: 32),
          const Text('التعليقات العامة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ..._comments.map((c) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(c['profiles']?['full_name'] ?? 'مستخدم', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  subtitle: Text(c['content'] ?? ''),
                ),
              )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentCtrl,
                  decoration: const InputDecoration(
                    hintText: 'اكتب تعليقك هنا...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () async {
                  if (_commentCtrl.text.trim().isEmpty) return;
                  if (!await requireAuth(context)) return;
                  await SupabaseService.addComment(adId: ad['id'], content: _commentCtrl.text);
                  _commentCtrl.clear();
                  _loadComments();
                },
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
