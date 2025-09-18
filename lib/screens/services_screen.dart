import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'add_service_screen.dart';

// Screen to list and manage service records for one watch
class ServicesScreen extends StatelessWidget {
  final String watchId;
  final String watchTitle;

  const ServicesScreen({
    super.key,
    required this.watchId,
    required this.watchTitle,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.yyyy');

    // Firestore collection: services of this watch
    final col = FirebaseFirestore.instance
        .collection('watches')
        .doc(watchId)
        .collection('services')
        .orderBy('date', descending: true);

    // navigate to add service screen
    Future<void> _add() async {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddServiceScreen(watchId: watchId),
        ),
      );
    }

    // open PDF receipt in external app
    Future<void> _openPdf(String url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF konnte nicht geöffnet werden')),
        );
      }
    }

    // confirm and delete a service record
    Future<void> _delete(DocumentSnapshot doc) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Service löschen?'),
          content: const Text('Dieser Eintrag wird dauerhaft gelöscht.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Löschen'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      await doc.reference.delete();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Wartung • $watchTitle'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Service hinzufügen'),
      ),
      // listen for live updates from Firestore
      body: StreamBuilder<QuerySnapshot>(
        stream: col.snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Noch keine Service-Einträge.'));
          }

          // list of service items
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = docs[i].data() as Map<String, dynamic>;

              final type = (m['type'] ?? '').toString();
              final dateTs = m['date'] as Timestamp?;
              final dateStr = dateTs == null ? '-' : df.format(dateTs.toDate());
              final cost = (m['cost'] ?? 0).toString();
              final notes = (m['notes'] ?? '').toString();
              final pdfUrl = (m['receiptUrl'] ?? '').toString();

              // one service card
              return Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  // long press = delete
                  onLongPress: () => _delete(docs[i]),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.build_circle, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // service type
                              Text(
                                type.isEmpty ? 'Service' : type,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // date + cost as small chips
                              Wrap(
                                spacing: 12,
                                runSpacing: 4,
                                children: [
                                  _Chip('Datum', dateStr),
                                  _Chip(
                                    'Kosten',
                                    cost == '0' ? '-' : 'CHF $cost',
                                  ),
                                ],
                              ),

                              // optional notes
                              if (notes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(notes),
                              ],

                              // optional receipt PDF button
                              if (pdfUrl.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _openPdf(pdfUrl),
                                  icon: const Icon(Icons.picture_as_pdf),
                                  label: const Text('Beleg öffnen'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Small helper widget for label:value chips
class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}
