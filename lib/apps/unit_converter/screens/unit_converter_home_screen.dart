import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/app_settings_state.dart';
import '../../../core/theme.dart';
import '../models/unit_category.dart';

/// Category picker for Unit Converter — searchable, with a "Recent" row
/// and a grid of category cards that each preview a couple of their units
/// so the card means something at a glance instead of just an icon + name.
class UnitConverterHomeScreen extends StatefulWidget {
  const UnitConverterHomeScreen({super.key});

  @override
  State<UnitConverterHomeScreen> createState() =>
      _UnitConverterHomeScreenState();
}

class _UnitConverterHomeScreenState extends State<UnitConverterHomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UnitCategory> get _filtered {
    if (_searchQuery.trim().isEmpty) return unitCategories;
    final q = _searchQuery.trim().toLowerCase();
    return unitCategories
        .where((c) => c.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              sliver: SliverToBoxAdapter(child: _header(scheme)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverToBoxAdapter(child: _searchField(scheme)),
            ),
            ValueListenableBuilder<List<String>>(
              valueListenable: AppSettingsState.recentUnitCategoryIds,
              builder: (context, recentIds, _) {
                if (_searchQuery.isNotEmpty || recentIds.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                final recentCategories = recentIds
                    .map((id) {
                      try {
                        return unitCategories.firstWhere((c) => c.id == id);
                      } catch (_) {
                        return null;
                      }
                    })
                    .whereType<UnitCategory>()
                    .toList();
                if (recentCategories.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _recentSection(scheme, recentCategories),
                  ),
                );
              },
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _searchQuery.isEmpty ? 'All categories' : 'Results',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            _filtered.isEmpty
                ? SliverPadding(
                    padding: const EdgeInsets.only(top: 40),
                    sliver: SliverToBoxAdapter(child: _emptyState(scheme)),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) =>
                          _categoryCard(scheme, _filtered[index]),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unit Converter',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick a category to start converting',
            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _searchField(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
        style: TextStyle(color: scheme.onSurface),
        decoration: InputDecoration(
          hintText: 'Search categories',
          hintStyle: TextStyle(color: scheme.onSurfaceVariant),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search, size: 18, color: AppColors.orange),
            ),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _recentSection(ColorScheme scheme, List<UnitCategory> recent) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: recent.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final category = recent[index];
                final accent = category.accentColor;
                return Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => _openCategory(category),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.25),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(category.icon, size: 16, color: accent),
                          const SizedBox(width: 8),
                          Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(ColorScheme scheme, UnitCategory category) {
    final accent = category.accentColor;
    final preview = category.units.take(3).map((u) => u.symbol).join('  ·  ');

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCategory(category),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(category.icon, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ColorScheme scheme) {
    return Column(
      children: [
        Icon(
          Icons.search_off_rounded,
          size: 40,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(
          'No categories match "$_searchQuery"',
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  void _openCategory(UnitCategory category) {
    AppSettingsState.markUnitCategoryUsed(category.id);
    context.push('/unit-converter/${category.id}');
  }
}
