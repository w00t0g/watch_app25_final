// Flutter UI + Firebase auth/firestore
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// App screens used for navigation
import 'new_entry_screen.dart';
import 'watch_detail_screen.dart';

// Home screen showing the user's watches in a grid
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // current signed-in user id (throws if not logged in)
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Firestore query: all watches that belong to this user, newest first
    final query = FirebaseFirestore.instance
        .collection('watches')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);

    // opens "NewEntryPage", waits for result, then creates a Firestore doc
    Future<void> _add() async {
      final result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(builder: (_) => const NewEntryPage()),
      );
      if (result == null) return;

      await FirebaseFirestore.instance.collection('watches').add({
        'brand': result['brand'],
        'model': result['model'],
        'reference': result['reference'],
        'movement': result['movement'],
        'purchaseDate': result['purchaseDate'],
        'mainImage': result['mainImage'], // main image URL from NewEntryPage
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    // A. helper: show confirm dialog, then delete the document if confirmed
    Future<void> _confirmAndDelete(
        BuildContext context, DocumentReference ref) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Eintrag löschen?'),
          content: const Text('Dieser Uhreintrag wird dauerhaft entfernt.'),
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

      if (ok == true) {
        await ref.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Eintrag gelöscht')),
          );
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meine Uhren'),
        actions: [
          // quick logout button in the app bar
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          )
        ],
      ),

      // live updates from Firestore via StreamBuilder
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (_, snap) {
          // loading state
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // error state
          if (snap.hasError) {
            return Center(child: Text('Fehler: ${snap.error}'));
          }
          // empty state
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Noch keine Uhren. Tippe auf +'));
          }

          // show a 2-column grid of watches
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0, // square tiles
            ),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              // extract document data
              final m = docs[i].data() as Map<String, dynamic>;
              final title = [
                (m['brand'] ?? '').toString().trim(),
                (m['model'] ?? '').toString().trim(),
              ].where((s) => s.isNotEmpty).join(' ');
              final mainImage = (m['mainImage'] ?? '').toString();

              return Material(
                elevation: 1,
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),

                  // open detail screen on tap
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WatchDetailScreen(
                          watchId: docs[i].id,
                          initialData: m,
                        ),
                      ),
                    );
                  },

                  // B. long-press to confirm and delete the item
                  onLongPress: () =>
                      _confirmAndDelete(context, docs[i].reference),

                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // show main image if present, otherwise a placeholder
                        if (mainImage.isNotEmpty)
                          Image.network(mainImage, fit: BoxFit.cover)
                        else
                          Container(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest, // placeholder bg
                            child: const Icon(Icons.watch, size: 56),
                          ),

                        // dark gradient at bottom so text is readable
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.55),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // title text at the bottom of the tile
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Text(
                            title.isEmpty ? '(ohne Titel)' : title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  blurRadius: 6,
                                  color: Colors.black54,
                                )
                              ],
                            ),
                          ),
                        ),

                        // optional delete button (top-right) as an alternative to long-press
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Material(
                            color: Colors.black45,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              tooltip: 'Löschen',
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                              onPressed: () =>
                                  _confirmAndDelete(context, docs[i].reference),
                              color: Colors.white,
                            ),
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

      // FAB to add a new watch
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}
