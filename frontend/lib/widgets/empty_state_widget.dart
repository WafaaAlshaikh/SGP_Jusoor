// lib/screens/manage_children/widgets/empty_state_widget.dart
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final VoidCallback onAdd;
  const EmptyStateWidget({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_alt_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No children found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('You don\'t have any children added yet. Click below to add a child.'),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add your first child')),
          ],
        ),
      ),
    );
  }
}
