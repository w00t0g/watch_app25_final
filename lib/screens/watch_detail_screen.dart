import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'services_screen.dart';

// Screen to show details for one watch (specs + photo gallery)
class WatchDetailScreen extends StatefulWidget {
  final String watchId;
  final Map<String, dynamic> initialData;

  const WatchDetailScreen({
    super.key,
    required this.watchId,
    required this.initialData,
  });

  @override
  State<WatchDetailScreen> createState() => _WatchDetailScreenState();
}

class _WatchDetailScreenState extends State<WatchDetailScreen> {
  // cached user id + firestore document reference for this watch
  late final String uid;
  late final DocumentReference<Map<String, dynamic>> watchRef;

  // current data of the watch (kept in state)
  late Map<String, dynamic> data;

  // display date format
  final df = DateFormat('dd.MM.yyyy');

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    watchRef = FirebaseFirestore.instance.collection('watches').doc(widget.watchId);
    data = Map<String, dynamic>.from(widget.initialData);

    // listen for live updates and keep local "data" in sync
    watchRef.snapshots().listen((snap) {
      if (!mounted) return;
      if (snap.exists) setState(() => data = snap.data() ?? data);
    });
  }

  // build a title like "Brand Model" or fallback to "Uhr"
  String _titleFrom(Map<String, dynamic> m) {
    final brand = (m['brand'] ?? '').toString().trim();
    final model = (m['model'] ?? '').toString().trim();
    final title = [brand, model].where((s) => s.isNotEmpty).join(' ').trim();
    return title.isEmpty ? 'Uhr' : title;
  }

  // try to format a Firestore Timestamp into a human date string
  String? _fmtDate(dynamic tsOrNull) {
    if (tsOrNull is Timestamp) return df.format(tsOrNull.toDate());
    return null;
  }

  // pick a photo from gallery and add it to this watch's "photos" subcollection
  Future<void> _addGalleryPhoto() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;

      final file = File(picked.path);
      final storagePath =
          'users/$uid/watches/${widget.watchId}/gallery/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      await storageRef.putFile(file);
      final url = await storageRef.getDownloadURL();

      await watchRef.collection('photos').add({
        'url': url,
        'path': storagePath,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    }
  }

  // delete a photo document and its file from Firebase Storage
  Future<void> _deleteGalleryPhoto(DocumentSnapshot doc) async {
    final m = doc.data() as Map<String, dynamic>;
    final path = (m['path'] ?? '').toString();
    final url = (m['url'] ?? '').toString();

    // ask user before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Foto löschen?'),
        content: const Text('Dieses Foto wird aus der Galerie entfernt.'),
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
    if (confirm != true) return;

    try {
      await doc.reference.delete();
      // delete the file either by known storage path or by URL
      if (path.isNotEmpty) {
        await FirebaseStorage.instance.ref().child(path).delete();
      } else if (url.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(url).delete();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Löschen fehlgeschlagen: $e')),
      );
    }
  }

  /// open an image in a full-screen dialog with Hero + zoom
  void _openPhoto(String url, String heroTag) {
    if (url.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: heroTag,
              child: InteractiveViewer(
                maxScale: 5,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // read values from current "data" map
    final brand = (data['brand'] ?? '').toString().trim();
    final model = (data['model'] ?? '').toString().trim();
    final reference = (data['reference'] ?? '').toString().trim();
    final movement = (data['movement'] ?? '').toString().trim();
    final purchaseDate = _fmtDate(data['purchaseDate']);
    final title = _titleFrom(data);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // open services/history screen
          IconButton(
            tooltip: 'Wartung & Historie',
            icon: const Icon(Icons.build),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ServicesScreen(
                    watchId: widget.watchId,
                    watchTitle: title,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // add photo to gallery
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addGalleryPhoto,
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Foto hinzufügen'),
      ),

      // main content: specs section and photo grid
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ——— Specifications (compact card) ———
          _SectionCard(
            title: 'Spezifikationen',
            child: Column(
              children: [
                _SpecTile(label: 'Marke', value: brand),
                _SpecTile(label: 'Modell', value: model),
                _SpecTile(label: 'Referenz', value: reference, optional: true),
                _SpecTile(
                  label: 'Werk / Kaliber',
                  value: movement,
                  optional: true,
                ),
                _SpecTile(
                  label: 'Kaufdatum',
                  value: purchaseDate ?? '-',
                  optional: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ——— Gallery ———
          Text(
            'Galerie',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),

          // live photo grid from /photos subcollection
          StreamBuilder<QuerySnapshot>(
            stream: watchRef
                .collection('photos')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (_, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Fehler: ${snap.error}'),
                );
              }

              final photos = snap.data?.docs ?? [];
              if (photos.isEmpty) {
                // hint when gallery is empty
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Noch keine Galeriefotos. Tippe unten rechts auf „Foto hinzufügen“.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }

              // 3-column grid of thumbnails
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 4),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: photos.length,
                itemBuilder: (_, i) {
                  final doc = photos[i];
                  final m = doc.data() as Map<String, dynamic>;
                  final url = (m['url'] ?? '').toString();
                  final heroTag = doc.id; // stable hero tag per item

                  return GestureDetector(
                    onTap: () => _openPhoto(url, heroTag),
                    onLongPress: () => _deleteGalleryPhoto(doc),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: url.isEmpty
                          ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: const Icon(Icons.broken_image),
                      )
                          : Hero(
                        tag: heroTag,
                        child: Image.network(url, fit: BoxFit.cover),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Simple card-ish section wrapper with title + body
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// One row for a spec field (label left, value right)
class _SpecTile extends StatelessWidget {
  final String label;
  final String value;
  final bool optional;

  const _SpecTile({
    required this.label,
    required this.value,
    this.optional = false,
  });

  @override
  Widget build(BuildContext context) {
    // hide optional rows with empty values
    final isEmpty = value.trim().isEmpty || value == '-';
    if (optional && isEmpty) return const SizedBox.shrink();

    final styleLabel = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final styleValue = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 130, child: Text('$label:', style: styleLabel)),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: styleValue,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
