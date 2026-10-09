import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/player_provider.dart';

class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final allTracks = player.playlist;

    final filteredTracks = allTracks.where((t) {
      return t.title.toLowerCase().contains(_query.toLowerCase()) ||
          t.artist.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ابحث عن أغنية، فنان، أو صوتية...',
            border: InputBorder.none,
          ),
          onChanged: (val) => setState(() => _query = val.trim()),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: 0.4,
                    child: Icon(Icons.search, size: 64),
                  ),
                  SizedBox(height: 12),
                  Text('اكتب في شريط البحث للعثور على أي مقطع صوتي'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (filteredTracks.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('الصوتيات المطابقة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  ...filteredTracks.map((t) => ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.music_note)),
                        title: Text(t.title),
                        subtitle: Text(t.artist),
                        onTap: () {
                          player.setPlaylist([t]);
                          Navigator.pop(context);
                        },
                      )),
                ],
                if (filteredTracks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('لا توجد نتائج مطابقة لبحثك')),
                  ),
              ],
            ),
    );
  }
}
