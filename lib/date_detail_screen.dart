import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/date_variety.dart';

class DateDetailScreen extends StatelessWidget {
  final DateVariety variety;

  const DateDetailScreen({super.key, required this.variety});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container
        (
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
          child: Container(
            color: Colors.black.withOpacity(0.6),
            child: CustomScrollView(
              slivers: [
                // App bar with hero image - similar feel to home cards
                SliverAppBar(
                  expandedHeight: 260,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: variety.name,
                          child: Image.asset(
                            variety.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.black,
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.white.withOpacity(0.6),
                                    size: 60,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // dark gradient for readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.8),
                              ],
                            ),
                          ),
                        ),
                        // title & chips at bottom of image
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                variety.name,
                                style: GoogleFonts.playfair(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _SmallChip(
                                    icon: Icons.location_on,
                                    label: variety.origin,
                                  ),
                                  _SmallChip(
                                    icon: Icons.calendar_today,
                                    label: variety.season,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  leading: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),

                // Content sections – match home style (dark cards, white text)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _DetailSectionCard(
                        icon: Icons.auto_awesome,
                        title: 'Characteristics',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: variety.characteristics.map((char) {
                            return _TagChip(label: char);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _DetailSectionCard(
                        icon: Icons.info_outline,
                        title: 'About',
                        child: Text(
                          variety.fullDescription,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _DetailSectionCard(
                        icon: Icons.restaurant_menu,
                        title: 'Nutritional Information',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _NutritionChips(),
                            const SizedBox(height: 12),
                            Text(
                              variety.nutritionalInfo,
                              style: GoogleFonts.roboto(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      _DetailSectionCard(
                        icon: Icons.favorite,
                        title: 'Health Benefits',
                        child: _BulletTextList(text: variety.healthBenefits),
                      ),
                      const SizedBox(height: 16),

                      _DetailSectionCard(
                        icon: Icons.kitchen,
                        title: 'Culinary Uses',
                        child: _BulletTextList(text: variety.culinaryUses, icon: Icons.restaurant),
                      ),
                      const SizedBox(height: 16),

                      _DetailSectionCard(
                        icon: Icons.inventory_2,
                        title: 'Storage Tips',
                        child: Text(
                          variety.storageTips,
                          style: GoogleFonts.roboto(
                            fontSize: 15,
                            height: 1.6,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Simple dark card used for all sections – matches HomePage style
class _DetailSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _DetailSectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.playfair(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// Small chip for origin / season under the image
class _SmallChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }
}

// Tag-style chip for characteristics
class _TagChip extends StatelessWidget {
  final String label;

  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontSize: 13,
          color: Colors.white,
        ),
      ),
    );
  }
}

// Nutrition chips – uses Wrap (not GridView) so it cannot overflow vertically
class _NutritionChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nutrients = [
      {'icon': Icons.local_fire_department, 'label': 'Calories', 'value': '277 kcal'},
      {'icon': Icons.grain, 'label': 'Fiber', 'value': 'High'},
      {'icon': Icons.opacity, 'label': 'Potassium', 'value': 'Rich'},
      {'icon': Icons.bolt, 'label': 'Energy', 'value': 'Quick'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: nutrients.map((nutrient) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(nutrient['icon'] as IconData, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nutrient['label'] as String,
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.75),
                    ),
                  ),
                  Text(
                    nutrient['value'] as String,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// Generic bullet list used for health benefits and culinary uses
class _BulletTextList extends StatelessWidget {
  final String text;
  final IconData? icon;

  const _BulletTextList({
    required this.text,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final items = text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              icon == null
                  ? Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

