import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Premium glassmorphic industrial info sheet.
/// Triggered on device shake.
class IndustrialInfoSheet extends StatelessWidget {
  const IndustrialInfoSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const IndustrialInfoSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        border: Border.all(color: const Color(0xFF00E5A0).withOpacity(0.2)),
      ),
      child: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings_suggest, color: Color(0xFF00E5A0)),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SOVEREIGN INFO',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Industrial Launcher v${info?.version ?? "1.0.0"}',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _InfoRow(label: 'APP PACKAGE', value: info?.packageName ?? 'dev.oore.oore_go'),
              _InfoRow(label: 'BUILD NUMBER', value: info?.buildNumber ?? '1'),
              _InfoRow(label: 'DART SDK', value: Platform.version.split('(').first),
              _InfoRow(label: 'FLUTTER SDK', value: '3.41.7 (Stable)'),
              _InfoRow(label: 'OLP PROTOCOL', value: 'v1.5 (Sovereign)'),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'COMPATIBILITY: This launcher supports bytecode targeting Flutter 3.41.x. '
                  'Backward compatibility is maintained for OLP v1.x protocols.',
                  style: TextStyle(color: Colors.grey, fontSize: 11, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5A0),
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('DISMISS', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, letterSpacing: 1)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace')),
        ],
      ),
    );
  }
}
