// persons_screen.dart — Manage authorized faces (Admin only for add/delete)
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/person_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class PersonsScreen extends ConsumerStatefulWidget {
  const PersonsScreen({super.key});

  @override
  ConsumerState<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends ConsumerState<PersonsScreen> {
  List<PersonModel> _persons = [];
  bool _loading = true;
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _persons = await _api.getPersons();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addPerson() async {
    final nameCtrl = TextEditingController();
    XFile? photo;

    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Authorized Person', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () async {
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                if (picked != null) setModal(() => photo = picked);
              },
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder, style: BorderStyle.solid),
                ),
                child: photo != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: kIsWeb
                            ? Image.network(photo!.path, fit: BoxFit.cover, width: double.infinity)
                            : Image.file(File(photo!.path), fit: BoxFit.cover, width: double.infinity))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('Tap to select face photo', style: TextStyle(color: AppColors.textMuted)),
                      ]),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || photo == null) return;
                Navigator.pop(ctx);
                try {
                  await _api.addPerson(nameCtrl.text.trim(), photo!);
                  _load();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Person added successfully'), backgroundColor: AppColors.success));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger));
                }
              },
              child: const Text('Add Person'),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _deletePerson(PersonModel p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('Remove ${p.name}?', style: const TextStyle(color: AppColors.textPrimary)),
        content: Text('${p.name} will no longer have access.', style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _api.deletePerson(p.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = ref.watch(authProvider).user?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Authorized Persons'),
        leading: const BackButton(),
        actions: [
          if (isAdmin) IconButton(icon: const Icon(Icons.person_add_rounded, color: AppColors.primary), onPressed: _addPerson),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary)))
          : _persons.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.group_off_rounded, size: 64, color: AppColors.textMuted),
                  SizedBox(height: 16),
                  Text('No authorized persons', style: TextStyle(color: AppColors.textSecondary)),
                ]))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: _persons.length,
                  itemBuilder: (_, i) {
                    final p = _persons[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: p.photoUrl != null
                                ? CachedNetworkImage(imageUrl: p.photoUrl!, fit: BoxFit.cover, width: double.infinity,
                                    placeholder: (_, __) => Container(color: AppColors.surface, child: const Icon(Icons.person, size: 60, color: AppColors.textMuted)),
                                    errorWidget: (_, __, ___) => Container(color: AppColors.surface, child: const Icon(Icons.person, size: 60, color: AppColors.textMuted)))
                                : Container(color: AppColors.surface, child: const Icon(Icons.person, size: 60, color: AppColors.textMuted)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(children: [
                            Expanded(child: Text(p.name, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            if (isAdmin) GestureDetector(
                              onTap: () => _deletePerson(p),
                              child: const Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 20),
                            ),
                          ]),
                        ),
                      ]),
                    );
                  },
                ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              onPressed: _addPerson,
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
              child: const Icon(Icons.person_add_rounded),
            )
          : null,
    );
  }
}
