import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WatchTile extends StatelessWidget {
  final DocumentSnapshot doc;
  final VoidCallback onDelete;
  const WatchTile({super.key, required this.doc, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final m = doc.data() as Map<String, dynamic>;
    final title = [
      (m['brand'] ?? '').toString().trim(),
      (m['model'] ?? '').toString().trim(),
    ].where((s) => s.isNotEmpty).join(' ');
    return ListTile(
      title: Text(title.isEmpty ? '(ohne Titel)' : title),
      subtitle: Text(doc.id),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
    );
  }
}
