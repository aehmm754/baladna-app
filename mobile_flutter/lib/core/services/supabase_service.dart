import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_compress_service.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;

  /// Send Phone OTP (+963...)
  static Future<void> sendOtp(String phoneE164) async {
    await client.auth.signInWithOtp(phone: phoneE164);
  }

  /// Verify OTP & upsert user profile (name + governorate)
  static Future<void> verifyOtpAndSaveProfile({
    required String phoneE164,
    required String otpCode,
    required String fullName,
    required String governorate,
  }) async {
    final res = await client.auth.verifyOTP(
      phone: phoneE164,
      token: otpCode,
      type: OtpType.sms,
    );
    final user = res.user;
    if (user != null) {
      await client.from('profiles').upsert({
        'id': user.id,
        'phone': phoneE164,
        'full_name': fullName.trim(),
        'governorate': governorate,
      });
    }
  }

  /// Fetch paginated approved ads (15 per page for weak internet)
  static Future<List<Map<String, dynamic>>> fetchAds({
    String? governorate,
    String? categoryId,
    String? condition,
    String? searchQuery,
    int page = 0,
    int pageSize = 15,
  }) async {
    var query = client
        .from('ads')
        .select('*, profiles(full_name, phone, is_verified, rating_avg, reviews_count), ad_images(image_url, sort_order)')
        .eq('status', 'approved');

    if (governorate != null && governorate != 'الكل') {
      query = query.eq('governorate', governorate);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (condition != null && condition.isNotEmpty) {
      query = query.eq('condition', condition);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      query = query.ilike('title', '%${searchQuery.trim()}%');
    }

    final from = page * pageSize;
    final to = from + pageSize - 1;
    final data = await query
        .order('is_featured', ascending: false)
        .order('created_at', ascending: false)
        .range(from, to);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Upload up to 8 compressed WebP images and create ad record
  static Future<String> publishAd({
    required Map<String, dynamic> adPayload,
    required List<File> images,
  }) async {
    final userId = currentUser!.id;
    final inserted = await client
        .from('ads')
        .insert({...adPayload, 'user_id': userId})
        .select('id')
        .single();
    final adId = inserted['id'] as String;

    for (var i = 0; i < images.length && i < 8; i++) {
      final compressed = await ImageCompressService.compressToWebp(images[i]);
      final path = '$userId/$adId/${i}_${DateTime.now().millisecondsSinceEpoch}.webp';
      await client.storage.from('ad-images').upload(path, compressed);
      final publicUrl = client.storage.from('ad-images').getPublicUrl(path);
      await client.from('ad_images').insert({
        'ad_id': adId,
        'image_url': publicUrl,
        'sort_order': i,
      });
    }
    return adId;
  }

  /// Create or get existing private conversation for an ad
  static Future<String> getOrCreateConversation({
    required String adId,
    required String sellerId,
  }) async {
    final buyerId = currentUser!.id;
    final existing = await client
        .from('conversations')
        .select('id')
        .eq('ad_id', adId)
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existing != null) return existing['id'] as String;

    final created = await client
        .from('conversations')
        .insert({'ad_id': adId, 'buyer_id': buyerId, 'seller_id': sellerId})
        .select('id')
        .single();
    return created['id'] as String;
  }

  /// Stream real-time messages for a conversation
  static Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  /// Send real-time message
  static Future<void> sendMessage(String conversationId, String content) async {
    await client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': currentUser!.id,
      'content': content.trim(),
    });
  }

  /// Add public comment or reply
  static Future<void> addComment({
    required String adId,
    required String content,
    String? parentId,
  }) async {
    await client.from('comments').insert({
      'ad_id': adId,
      'user_id': currentUser!.id,
      'parent_id': parentId,
      'content': content.trim(),
    });
  }
}
