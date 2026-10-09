import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حول التطبيق')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.music_video_rounded, size: 72, color: Colors.indigoAccent),
              const SizedBox(height: 16),
              const Text('AR Music & Video', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('الإصدار: 1.0.0 (ARM64 Optimized)', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              const Text(
                'مشغل وسائط عالي الأداء مبني بواسطة Flutter و Supabase و Kotlin لنظام Android مع دعم التشغيل في الخلفية وميزة PiP.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
