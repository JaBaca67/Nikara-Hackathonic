import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:nikara_app/features/business/data/business_post_service.dart';
import 'package:nikara_app/features/business/domain/models/business_model.dart';
import 'package:nikara_app/features/business/domain/models/business_post_model.dart';
import 'package:nikara_app/shared/widgets/app_confirm_dialog.dart';
import 'package:nikara_app/shared/widgets/app_loading.dart';
import 'package:nikara_app/shared/widgets/app_snackbar.dart';
import 'package:nikara_app/shared/widgets/circle_back_button.dart';
import 'package:nikara_app/shared/widgets/local_image.dart';
import 'package:nikara_app/theme/app_spacing.dart';
import 'package:nikara_app/theme/app_theme.dart';

/// Pantalla de gestión del dueño: publicar/borrar anuncios de un negocio.
/// La vista pública de solo lectura es `_AnnouncementsSection` en
/// `business_detail_screen.dart` — esta pantalla nunca se abre fuera del
/// flujo del dueño (ver `face_profile_screen.dart`).
class ManageBusinessPostsScreen extends StatefulWidget {
  const ManageBusinessPostsScreen({super.key, required this.business});

  final BusinessModel business;

  @override
  State<ManageBusinessPostsScreen> createState() =>
      _ManageBusinessPostsScreenState();
}

class _ManageBusinessPostsScreenState extends State<ManageBusinessPostsScreen> {
  final _bodyController = TextEditingController();
  XFile? _image;
  List<BusinessPostModel> _posts = const [];
  bool _loading = true;
  bool _publishing = false;

  /// Anuncio que se está eliminando: bloquea todos los botones de eliminar
  /// (no solo el suyo) y pone el spinner en su fila.
  String? _deletingPostId;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    setState(() => _loading = true);
    try {
      final posts = await BusinessPostService().getPostsForBusiness(
        widget.business.id,
      );
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } on BusinessPostServiceException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppSnackbar.showError(context, e.message);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = picked);
  }

  Future<void> _publish() async {
    if (_publishing) return;
    final body = _bodyController.text.trim();
    if (body.isEmpty) {
      AppSnackbar.showError(context, 'Escribe algo antes de publicar.');
      return;
    }
    setState(() => _publishing = true);
    try {
      await BusinessPostService().createPost(
        businessId: widget.business.id,
        body: body,
        image: _image,
      );
      if (!mounted) return;
      _bodyController.clear();
      setState(() {
        _image = null;
        _publishing = false;
      });
      await _loadPosts();
    } on BusinessPostServiceException catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      AppSnackbar.showError(context, e.message);
    }
  }

  Future<void> _delete(BusinessPostModel post) async {
    if (_deletingPostId != null) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'Eliminar anuncio',
      message: 'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _deletingPostId = post.id);
    try {
      await BusinessPostService().deletePost(post.id);
      if (!mounted) return;
      setState(() => _posts = _posts.where((p) => p.id != post.id).toList());
    } on BusinessPostServiceException catch (e) {
      if (!mounted) return;
      AppSnackbar.showError(context, e.message);
    } on Exception {
      if (!mounted) return;
      AppSnackbar.showError(
        context,
        'No se pudo eliminar el anuncio. Verifica tu internet e intenta de '
        'nuevo.',
      );
    } finally {
      if (mounted) setState(() => _deletingPostId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                0,
              ),
              child: Row(
                children: [
                  CircleBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Anuncios', style: AppTextStyles.wizardCardTitle),
                        Text(
                          widget.business.name,
                          style: AppTextStyles.wizardCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _posts.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Todavía no has publicado ningún anuncio.',
                          style: AppTextStyles.wizardCaption,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      itemCount: _posts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _PostRow(
                        post: _posts[index],
                        onDelete: _delete,
                        deletingPostId: _deletingPostId,
                      ),
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface100,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.mapControlBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_image != null) ...[
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: SizedBox(
                                height: 90,
                                width: double.infinity,
                                child: LocalImage(path: _image!.path),
                              ),
                            ),
                            Positioned(
                              right: 4,
                              top: 4,
                              child: GestureDetector(
                                onTap: () => setState(() => _image = null),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: _bodyController,
                        maxLines: 3,
                        minLines: 1,
                        style: AppTextStyles.wizardFieldValue,
                        decoration: const InputDecoration(
                          hintText: 'Escribe un anuncio para tu negocio…',
                          border: InputBorder.none,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _pickImage,
                            icon: const Icon(
                              Icons.image_outlined,
                              color: AppColors.settingsTextMuted,
                            ),
                          ),
                          const Spacer(),
                          FilledButton(
                            onPressed: _publishing ? null : _publish,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary500,
                            ),
                            child: Text(
                              _publishing ? 'Publicando…' : 'Publicar',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostRow extends StatelessWidget {
  const _PostRow({
    required this.post,
    required this.onDelete,
    required this.deletingPostId,
  });

  final BusinessPostModel post;
  final ValueChanged<BusinessPostModel> onDelete;
  final String? deletingPostId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface100,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.mapControlBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.relativeTime(),
                  style: AppTextStyles.wizardCaption.copyWith(
                    color: AppColors.settingsTextMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(post.body, style: AppTextStyles.detailDescriptionText),
                if (post.imageUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: LocalImage(path: post.imageUrl),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: deletingPostId != null ? null : () => onDelete(post),
            tooltip: 'Eliminar anuncio',
            icon: deletingPostId == post.id
                ? const AppSpinner(color: AppColors.destructive)
                : const Icon(
                    Icons.delete_outline,
                    color: AppColors.destructive,
                  ),
          ),
        ],
      ),
    );
  }
}
