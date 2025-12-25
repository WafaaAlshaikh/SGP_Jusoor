import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/reports_service.dart';
import '../theme/app_colors.dart';

class ReportDetailsScreen extends StatefulWidget {
  final ReportsScope scope;
  final int reportId;

  const ReportDetailsScreen({
    super.key,
    required this.scope,
    required this.reportId,
  });

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _report;
  List<dynamic> _messages = [];

  final TextEditingController _messageController = TextEditingController();
  bool _sending = false;

  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadMyUserId();
    _load();
  }

  Future<void> _loadMyUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_id');
      setState(() {
        _myUserId = raw == null ? null : int.tryParse(raw);
      });
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await ReportsService.getReportDetails(scope: widget.scope, reportId: widget.reportId);
      setState(() {
        _report = (data['report'] as Map?)?.cast<String, dynamic>();
        _messages = (data['messages'] as List?) ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatStatus(String raw) {
    if (raw.isEmpty) return 'Unknown';
    return raw.replaceAll('_', ' ');
  }

  bool _isMine(Map<String, dynamic> msg) {
    final senderIdRaw = msg['sender_id'];
    final senderId = senderIdRaw is num ? senderIdRaw.toInt() : int.tryParse(senderIdRaw?.toString() ?? '');
    if (_myUserId == null || senderId == null) return false;
    return _myUserId == senderId;
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _sending = true;
    });

    try {
      await ReportsService.addMessage(scope: widget.scope, reportId: widget.reportId, message: text);
      _messageController.clear();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _report?['title']?.toString() ?? 'Report #${widget.reportId}';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textWhite,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildMessages()),
                    _buildComposer(),
                  ],
                ),
    );
  }

  Widget _buildHeader() {
    final status = _report?['status']?.toString() ?? '';
    final priority = _report?['priority']?.toString() ?? 'medium';
    final category = _report?['category']?.toString() ?? 'Other';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.surface,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Pill(label: 'Status: ${_formatStatus(status)}', color: AppColors.info),
          _Pill(label: 'Priority: $priority', color: AppColors.warning),
          _Pill(label: 'Category: $category', color: AppColors.accent4),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    if (_messages.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          SizedBox(height: 60),
          Center(child: Text('No messages yet')),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final m = (_messages[index] as Map).cast<String, dynamic>();
          final text = m['message']?.toString() ?? '';
          final senderType = m['sender_type']?.toString() ?? '';
          final mine = _isMine(m);

          return Align(
            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
              decoration: BoxDecoration(
                color: mine ? AppColors.myMessage : AppColors.theirMessage,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderType,
                    style: TextStyle(
                      fontSize: 11,
                      color: mine ? AppColors.messageTextMe.withOpacity(0.85) : AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(
                      color: mine ? AppColors.messageTextMe : AppColors.messageTextThem,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        color: AppColors.surface,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: AppColors.accent1,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
