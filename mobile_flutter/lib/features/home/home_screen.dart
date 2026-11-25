import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/syria_data.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_theme.dart';
import '../ads/ad_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  const HomeScreen({super.key, required this.onToggleTheme});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _governorate = 'الكل';
  String? _selectedCategory;
  String? _conditionFilter;
  List<Map<String, dynamic>> _ads = [];
  bool _loading = true;
  bool _loadingMore = false;
  int _page = 0;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadAds(reset: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 250 &&
          !_loadingMore &&
          _hasMore) {
        _loadAds(reset: false);
      }
    });
  }

  Future<void> _loadAds({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _page = 0;
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final rows = await SupabaseService.fetchAds(
        governorate: _governorate,
        categoryId: _selectedCategory,
        condition: _conditionFilter,
        searchQuery: _searchCtrl.text,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        if (reset) {
          _ads = rows;
        } else {
          _ads.addAll(rows);
        }
        _hasMore = rows.length == 15;
        _page++;
      });
    } catch (_) {
      // Offline / network error gracefully handled via empty state
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('بلدنا'),
        actions: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _governorate,
              items: SyriaData.governorates
                  .map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13))))
                  .toList(),
              onChanged: (v) {
                setState(() => _governorate = v ?? 'الكل');
                _loadAds(reset: true);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.brightness_6_rounded),
            tooltip: 'تبديل الوضع الداكن',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadAds(reset: true),
        child: ListView(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(14),
          children: [
            // Search Bar
            TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _loadAds(reset: true),
              decoration: InputDecoration(
                hintText: 'ابحث عن سباك، شقة، سيارة، جوال...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 8 Categories Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: SyriaData.categories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.9,
              ),
              itemBuilder: (_, i) {
                final cat = SyriaData.categories[i];
                final active = _selectedCategory == cat.id;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    setState(() => _selectedCategory = active ? null : cat.id);
                    _loadAds(reset: true);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary.withAlpha(31) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: active ? AppTheme.primary : AppTheme.warmBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat.icon, color: AppTheme.primary, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          cat.nameAr,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Ads List / Skeleton / Empty State
            if (_loading)
              ...List.generate(4, (_) => _buildSkeletonCard())
            else if (_ads.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Column(
                  children: [
                    Icon(Icons.inbox_rounded, size: 52, color: Colors.grey),
                    SizedBox(height: 10),
                    Text('لا توجد إعلانات مطابقة حالياً', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              )
            else
              ..._ads.map(_buildAdCard),
            if (_loadingMore)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonCard() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: 106,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    final images = (ad['ad_images'] as List?) ?? [];
    final imageUrl = images.isNotEmpty ? images.first['image_url'] as String : null;
    final price = ad['price'] ?? 0;
    final currency = ad['currency'] == 'USD' ? '\$' : 'ل.س';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdDetailScreen(ad: ad)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 96,
                  height: 96,
                  child: imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 300,
                          placeholder: (_, __) => Container(color: Colors.grey.shade200),
                          errorWidget: (_, __, ___) => const Icon(Icons.image_not_supported),
                        )
                      : Container(
                          color: AppTheme.primary.withAlpha(26),
                          child: const Icon(Icons.photo_rounded, color: AppTheme.primary),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad['title'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$price $currency',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${ad['governorate'] ?? ''} - ${ad['area'] ?? ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
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
