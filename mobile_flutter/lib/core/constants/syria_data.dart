import 'package:flutter/material.dart';

class SyriaData {
  static const List<String> governorates = [
    'الكل',
    'دمشق',
    'ريف دمشق',
    'حلب',
    'حمص',
    'حماة',
    'اللاذقية',
    'طرطوس',
    'إدلب',
    'درعا',
    'السويداء',
    'دير الزور',
    'الرقة',
    'الحسكة',
    'القنيطرة',
  ];

  static const Map<String, List<double>> governorateCoords = {
    'دمشق': [33.5138, 36.2765],
    'ريف دمشق': [33.5167, 36.4000],
    'حلب': [36.2021, 37.1343],
    'حمص': [34.7324, 36.7137],
    'حماة': [35.1318, 36.7578],
    'اللاذقية': [35.5317, 35.7901],
    'طرطوس': [34.8890, 35.8866],
    'إدلب': [35.9306, 36.6339],
    'درعا': [32.6189, 36.1021],
    'السويداء': [32.7089, 36.5695],
    'دير الزور': [35.3359, 40.1408],
    'الرقة': [35.9506, 39.0079],
    'الحسكة': [36.5072, 40.7485],
    'القنيطرة': [33.1259, 35.8246],
  };

  static const List<CategoryMeta> categories = [
    CategoryMeta(
      id: 'services',
      nameAr: 'الخدمات والحرفيين',
      icon: Icons.build_rounded,
      subcategories: [
        'سباك', 'كهربائي', 'ميكانيكي سيارات', 'نقليات', 'نجار', 'حداد',
        'دهان', 'تكييف وتبريد', 'ألمنيوم', 'بلاط', 'تنظيف', 'أخرى',
      ],
    ),
    CategoryMeta(
      id: 'used',
      nameAr: 'المستعمل',
      icon: Icons.chair_rounded,
      subcategories: ['أثاث', 'أدوات منزلية', 'أخرى'],
    ),
    CategoryMeta(
      id: 'new_tools',
      nameAr: 'الأدوات الجديدة',
      icon: Icons.handyman_rounded,
      subcategories: ['عدد يدوية', 'كهربائية', 'مواد بناء'],
    ),
    CategoryMeta(
      id: 'appliances',
      nameAr: 'الكهربائيات',
      icon: Icons.kitchen_rounded,
      subcategories: ['براد', 'غسالة', 'مكيف', 'تلفاز', 'أخرى'],
    ),
    CategoryMeta(
      id: 'electronics',
      nameAr: 'الإلكترونيات والجوالات',
      icon: Icons.smartphone_rounded,
      subcategories: ['جوالات', 'لابتوبات', 'إكسسوارات'],
    ),
    CategoryMeta(
      id: 'real_estate',
      nameAr: 'إيجار البيوت',
      icon: Icons.apartment_rounded,
      subcategories: ['شقق', 'محلات', 'مكاتب'],
    ),
    CategoryMeta(
      id: 'cars',
      nameAr: 'السيارات',
      icon: Icons.directions_car_rounded,
      subcategories: ['بيع', 'إيجار'],
    ),
    CategoryMeta(
      id: 'other',
      nameAr: 'أخرى',
      icon: Icons.grid_view_rounded,
      subcategories: ['أخرى'],
    ),
  ];
}

class CategoryMeta {
  final String id;
  final String nameAr;
  final IconData icon;
  final List<String> subcategories;

  const CategoryMeta({
    required this.id,
    required this.nameAr,
    required this.icon,
    required this.subcategories,
  });
}
