import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';

const _green = Color(0xFF2E7D32);

/// Lets admin fire off a quick text announcement to every customer,
/// without needing a full Offer Card — for short-lived things like
/// "Flash sale — next 2 hours only!" that don't need an image,
/// discount %, or product links behind them, just a message.
class AdminSendNotificationScreen extends StatefulWidget {
  const AdminSendNotificationScreen({super.key});

  @override
  State<AdminSendNotificationScreen> createState() => _AdminSendNotificationScreenState();
}

class _AdminSendNotificationScreenState extends State<AdminSendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send to all customers?'),
        content: Text(
          'This sends "${_titleController.text.trim()}" as a push notification to every customer right now. This can\'t be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSending = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('sendAdminBroadcastNotification');
      await callable.call({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification sent to all customers.')));
        _titleController.clear();
        _bodyController.clear();
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Could not send notification.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send Announcement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Send a quick text notification to every customer — good for short-lived things like a flash sale or a limited-time offer that doesn\'t need a full offer card.',
                style: TextStyle(fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Flash Sale!',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                maxLength: 300,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'e.g. 20% off all snacks — next 2 hours only!',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: _isSending ? null : _send,
                  icon: _isSending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.campaign_outlined),
                  label: Text(_isSending ? 'Sending...' : 'Send to All Customers'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}