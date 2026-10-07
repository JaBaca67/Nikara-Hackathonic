import 'package:flutter/material.dart';
import 'package:nikara_app/core/services/passport_service.dart';
import 'package:nikara_app/features/business/utils/business_icons.dart';
import 'package:nikara_app/features/profile/domain/models/postcard_search.dart';
import 'package:nikara_app/features/profile/domain/models/travel_postcard.dart';
import 'package:nikara_app/features/profile/presentation/widgets/passport_tab.dart';
import 'package:nikara_app/features/profile/presentation/widgets/postcard_category_style.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

class PassportCollectionScreen extends StatefulWidget {
  const PassportCollectionScreen({super.key, required this.postcards});
  final List<TravelPostcard> postcards;

  @override
  State<PassportCollectionScreen> createState() =>
      _PassportCollectionScreenState();
}

class _PassportCollectionScreenState extends State<PassportCollectionScreen> {
  final _searchController = TextEditingController();
  late List<TravelPostcard> _postcards;
  String? _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    _postcards = searchPostcards(widget.postcards);
    PassportService.revision.addListener(_reload);
  }

  @override
  void dispose() {
    PassportService.revision.removeListener(_reload);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final collection = await PassportService().getCollection();
      if (!mounted) return;
      setState(() {
        _postcards = collection.postcards;
        _error = null;
        if (_category != null &&
            !_postcards.any(
              (card) =>
                  (businessCategoryPresetFor(card.category) ?? 'Otros') ==
                  _category,
            )) {
          _category = null;
        }
      });
    } on PassportServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _clearFilters() => setState(() {
    _searchController.clear();
    _category = null;
  });

  @override
  Widget build(BuildContext context) {
    final visible = searchPostcards(
      _postcards,
      query: _searchController.text,
      category: _category,
    );
    final categories =
        _postcards
            .map((card) => businessCategoryPresetFor(card.category) ?? 'Otros')
            .toSet()
            .toList()
          ..sort();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis postales'),
        backgroundColor: AppColors.background,
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Lugares que ya son parte de tu historia.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Buscar por nombre o categoría',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpiar búsqueda',
                                  onPressed: () =>
                                      setState(_searchController.clear),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.border,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: _category == null,
                              onSelected: (_) =>
                                  setState(() => _category = null),
                            ),
                            for (final category in categories) ...[
                              const SizedBox(width: AppSpacing.sm),
                              ChoiceChip(
                                label: Text(
                                  PostcardCategoryStyle
                                          .byCategory[category]
                                          ?.label ??
                                      'Otros',
                                ),
                                selected: _category == category,
                                onSelected: (selected) => setState(
                                  () => _category = selected ? category : null,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '${visible.length} de ${_postcards.length} ${_postcards.length == 1 ? 'postal' : 'postales'} · Más recientes primero',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.settingsTextMuted,
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _error!,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        TextButton(
                          onPressed: _reload,
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.collections_bookmark_outlined,
                          size: 40,
                          color: AppColors.oliveText,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          _postcards.isEmpty
                              ? 'Tu primera postal te espera'
                              : 'No encontramos postales',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.sectionTitle,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          _postcards.isEmpty
                              ? 'Completa un viaje y recibe tu postal con el sello Níkara.'
                              : 'Prueba otro nombre o cambia la categoría.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.settingsTextMuted,
                          ),
                        ),
                        if (_postcards.isNotEmpty)
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text('Limpiar filtros'),
                          ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  sliver: PostcardSliverGrid(
                    postcards: visible,
                    onSelected: (postcard) => showTravelPostcard(
                      context,
                      postcard,
                      onMapRequested: () {
                        Navigator.of(context).pop();
                        focusPostcardOnMap(postcard);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
