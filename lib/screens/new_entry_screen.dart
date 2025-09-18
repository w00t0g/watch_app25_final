import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Page to create a new watch entry
class NewEntryPage extends StatefulWidget {
  const NewEntryPage({super.key});

  @override
  State<NewEntryPage> createState() => _NewEntryPageState();
}

class _NewEntryPageState extends State<NewEntryPage> {
  // form + controllers
  final _formKey = GlobalKey<FormState>();

  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _reference = TextEditingController();
  final _movement = TextEditingController();

  // optional purchase date
  DateTime? _purchaseDate;

  // selected main image file (optional)
  File? _imageFile;

  // saving state to disable UI
  bool _saving = false;

  @override
  void dispose() {
    // clean up controllers
    _brand.dispose();
    _model.dispose();
    _reference.dispose();
    _movement.dispose();
    super.dispose();
  }

  // let user pick a main image from gallery
  Future<void> _pickMainImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // compress a bit
      );
      if (picked != null) {
        setState(() => _imageFile = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      // show a simple error if picking failed
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Bildauswahl fehlgeschlagen: $e')));
    }
  }

  // upload selected image to Firebase Storage and return its URL (or null)
  Future<String?> _uploadMainImageIfAny() async {
    if (_imageFile == null) return null;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    // unique-ish filename based on timestamp
    final millis = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'users/$uid/watches/main_$millis.jpg';
    final ref = FirebaseStorage.instance.ref().child(storagePath);

    await ref.putFile(_imageFile!);
    return ref.getDownloadURL();
  }

  // validate form, upload image (if any), and return data back to caller
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      // upload image first to get URL
      final mainImageUrl = await _uploadMainImageIfAny();

      // pop and pass collected data to previous screen
      Navigator.pop<Map<String, dynamic>>(context, {
        'brand': _brand.text.trim(),
        'model': _model.text.trim(),
        'reference': _reference.text.trim().isEmpty ? null : _reference.text.trim(),
        'movement': _movement.text.trim().isEmpty ? null : _movement.text.trim(),
        'purchaseDate':
        _purchaseDate == null ? null : Timestamp.fromDate(_purchaseDate!),
        'mainImage': mainImageUrl, // used by HomeScreen
      });
    } catch (e) {
      if (!mounted) return;
      // show error if saving failed
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Speichern fehlgeschlagen: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // allow saving unless currently saving
    final canSave = !_saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Neue Uhr')),
      body: AbsorbPointer(
        absorbing: _saving, // block inputs while saving
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // main photo preview area
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _imageFile == null
                        ? const Center(child: Icon(Icons.watch, size: 64))
                        : Image.file(_imageFile!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 8),

                // buttons to pick or remove the main photo
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: canSave ? _pickMainImage : null,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Hauptfoto wählen'),
                    ),
                    const SizedBox(width: 12),
                    if (_imageFile != null)
                      OutlinedButton.icon(
                        onPressed: canSave
                            ? () => setState(() => _imageFile = null)
                            : null,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Foto entfernen'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // required fields
                TextFormField(
                  controller: _brand,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Marke *'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                ),
                TextFormField(
                  controller: _model,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Modell *'),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                ),

                // optional fields
                TextFormField(
                  controller: _reference,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Referenz (optional)'),
                ),
                TextFormField(
                  controller: _movement,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Werk / Kaliber (optional)'),
                ),

                const SizedBox(height: 8),

                // purchase date picker (optional)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _purchaseDate == null
                          ? 'Kaufdatum wählen (optional)'
                          : 'Kaufdatum: ${_purchaseDate!.toLocal().toString().split(' ').first}',
                    ),
                    onPressed: canSave
                        ? () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDate: _purchaseDate ?? DateTime.now(),
                      );
                      if (d != null) setState(() => _purchaseDate = d);
                    }
                        : null,
                  ),
                ),

                const SizedBox(height: 16),

                // save button (shows spinner while saving)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canSave ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check),
                    label: Text(_saving ? 'Speichern...' : 'Speichern'),
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
