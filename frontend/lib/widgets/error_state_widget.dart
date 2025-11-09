// lib/screens/manage_children/widgets/error_state_widget.dart
import 'package:flutter/material.dart';

class ErrorStateWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const ErrorStateWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.redAccent),
          const SizedBox(height: 12),
          const Text('Failed to load children data.', style: TextStyle(color: Colors.red, fontSize: 16)),
          const SizedBox(height: 12),
          TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry'))
        ],
      ),
    );
  }
}
