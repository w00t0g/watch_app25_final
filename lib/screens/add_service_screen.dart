import 'dart:io';

// Firebase + Flutter imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Screen for adding a service to a watch
class AddServiceScreen extends StatefulWidget {
  final String watchId; // ID of the watch

  const AddServiceScreen({super.key, required this.watchId});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  // form + controllers
  final _formKey = GlobalKey<FormState>();
  final _type = TextEditingController();
  final _notes = TextEditingController();
  final _cost = TextEditingController();
  DateTime _date = DateTime.now(); // default: today

  // optional receipt pdf
  File? _receiptFile;
  String? _receiptFileName;

  // saving flag for loading state
  bool _saving = false;

  @override
  void dispose() {
    // clean up controllers when leaving screen
    _type.dispose();
    _notes.dispose();
    _cost.dispose();
    super.dispose();
  }

  // let user pick a pdf file
  Future<void> _pickReceiptPdf() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: false,
    );
    if (res == null || res.files.isEmpty) return;

    final path = res.files.single.path;
    if (path == null) return;

    setState(() {
      _receiptFile = File(path);
      _receiptFileName = res.files.single.name;
    });
  }

  // upload receipt to Firebase Storage
  // returns download URL or null
  Future<String?> _uploadReceipt(String uid, String docId) async {
    if (_receiptFile == null) return null;

    final name = _receiptFileName ?? 'beleg.pdf';
    final storagePath = 'users/$uid/watches/${widget.watchId}/services/$docId/$name';

    final ref = FirebaseStorage.instance.ref(storagePath);

    await ref.putFile(
      _receiptFile!,
      SettableMetadata(contentType: 'application/pdf'),
    );

    return ref.getDownloadURL();
  }

  // save service data to Firestore
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final col = FirebaseFirestore.instance
          .collection('watches')
          .doc(widget.watchId)
          .collection('services');

      // first create Firestore doc (no receipt yet)
      final newDoc = await col.add({
        'type': _type.text.trim(),
        'date': Timestamp.fromDate(_date),
        'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        'cost': double.tryParse(_cost.text.trim()) ?? 0.0,
        'receiptUrl': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // then upload receipt and update doc with URL
      final url = await _uploadReceipt(uid, newDoc.id);
      if (url != null) {
        await newDoc.update({'receiptUrl': url});
      }

      if (!mounted) return;
      Navigator.pop(context); // go back after saving
    } catch (e) {
      // show error message if saving failed
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy'); // date format for display

    return Scaffold(
      appBar: AppBar(title: const Text('Service hinzufügen')),
      body: AbsorbPointer(
        absorbing: _saving, // disable input when saving
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // type of service (required)
                TextFormField(
                  controller: _type,
                  decoration: const InputDecoration(
                    labelText: 'Art des Service',
                  ),
                  validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pflichtfeld' : null,
                ),
                const SizedBox(height: 8),

                // optional cost input
                TextFormField(
                  controller: _cost,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kosten in CHF (optional)',
                  ),
                ),
                const SizedBox(height: 8),

                // date picker button
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text('Datum: ${df.format(_date)}'),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime(1970),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDate: _date,
                      );
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),

                // optional notes
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notizen (optional)',
                  ),
                ),
                const SizedBox(height: 16),

                // receipt pdf picker
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _pickReceiptPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Beleg (PDF) auswählen'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _receiptFileName == null
                            ? 'Kein Beleg gewählt'
                            : _receiptFileName!,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // save button (shows spinner if saving)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
