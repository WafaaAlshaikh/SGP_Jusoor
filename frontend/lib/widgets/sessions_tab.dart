// lib/widgets/sessions_tab.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/session.dart';
import '../models/child_model.dart';
import 'child_session_card.dart'; // ⬅️ استورد الكارد الجديد


class SessionsTab extends StatefulWidget {
  final Child child;
  final String token;

  const SessionsTab({super.key, required this.child, required this.token});

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  late Future<List<Session>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = ApiService.getChildSessions(widget.token, widget.child.id.toString());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Session>>(
      future: _sessionsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No sessions found.'));
        }

        final sessions = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sessions.length,
          itemBuilder: (context, idx) {
            final session = sessions[idx];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text('${session.sessionType} • ${session.date} ${session.time}'),
                subtitle: Text('Status: ${session.status}'),
              ),
            );
          },
        );
      },
    );
  }
}

