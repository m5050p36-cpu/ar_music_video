import 'package:flutter/material.dart';

class FileManagerScreen extends StatelessWidget {
  const FileManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مدير الملفات المحلي')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.5,
              child: Icon(Icons.folder_shared_outlined, size: 64),
            ),
            SizedBox(height: 12),
            Text('استعراض وتصنيف ملفات الصوت والفيديو في الذاكرة'),
          ],
        ),
      ),
    );
  }
}
