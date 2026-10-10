import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('drawer_privacy'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Text(
          context.tr('privacy_body'),
          style: const TextStyle(fontSize: 15, height: 1.9),
        ),
      ),
    );
  }
}
