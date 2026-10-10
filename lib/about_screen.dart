import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'brand.dart';
import 'responsive.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appPrimary,
        title: const Text('About'),
      ),
      body: ContentWidth(maxWidth: 1100, child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(BrandAssets.logoCircle, height: 104, width: 104),
              const SizedBox(height: 20),
              Semantics(
                label: BrandAssets.appName,
                child: Image.asset(BrandAssets.wordmarkDark, height: 36),
              ),
              const SizedBox(height: 6),
              const Text(
                BrandAssets.tagline,
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              const Text(
                'App Version 1.0.0',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              const Text(
                'Developed by Shivani Sharma',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      )),
    );
  }
}