import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Text(
          'سياسة الخصوصية لتطبيق AR Music & Video:\n\n'
          '• التطبيق يحترم خصوصيتك بالكامل ويعمل بدون إنترنت (Offline).\n'
          '• لا يتم إرسال أو مشاركة ملفاتك الصوتية أو فيديوهاتك الخاصة مع أي خادم خارجي إطلاقاً.\n'
          '• يتم تخزين الإعدادات المفضلة والمواضع الأخيرة على جهازك محلياً عبر SharedPreferences.\n'
          '• عند تسجيل حساب، تُحفظ بيانات بريدك واسمك بأمان على Supabase مع سياسات RLS مشفرة.',
          style: TextStyle(fontSize: 15, height: 1.8),
        ),
      ),
    );
  }
}
