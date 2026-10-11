import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_gate.dart';
import 'app_colors.dart';
import 'at_risk_screen.dart';
import 'friendly_error.dart';
import 'notification_log.dart';
import 'responsive.dart';
import 'soft_delete.dart';
import 'ui_kit.dart';

/// Admin-only simulated notification log. Koi asli message nahi jaata.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBackground,
      appBar: AppBar(
        flexibleSpace: const AppBarRibbon(),
        title: const Text('Notifications'),
        backgroundColor: AppColors.appPrimary,
        foregroundColor: Colors.white,
      ),
      body: PageWash(child: const ContentWidth(
        maxWidth: 900,
        child: AdminGate(screenName: 'Notifications', child: _NotificationsBody()),
      )),
    );
  }
}

IconData _typeIcon(NotificationType? t) => switch (t) {
      NotificationType.feeDue => Icons.currency_rupee,
      NotificationType.absentAlert => Icons.event_busy_outlined,
      NotificationType.batchAlert => Icons.campaign_outlined,
      NotificationType.adminSummary => Icons.summarize_outlined,
      NotificationType.riskAlert => Icons.warning_amber_outlined,
      null => Icons.notifications_none,
    };

DateTime? _createdAt(Map<String, dynamic> d) {
  final v = d['createdAt'];
  return v is Timestamp ? v.toDate() : null;
}

class _NotificationsBody extends StatefulWidget {
  const _NotificationsBody();

  @override
  State<_NotificationsBody> createState() => _NotificationsBodyState();
}

class _NotificationsBodyState extends State<_NotificationsBody> {
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('notifications').snapshots();
  NotificationType? _filter;
  bool _busy = false;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? AppColors.danger : AppColors.appPrimary),
    );
  }

  Future<List<Map<String, dynamic>>> _students() async =>
      liveStudentMapsFrom(await FirebaseFirestore.instance.collection('students').get());

  Future<bool> _confirm(String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.appPrimary),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  /// Data lao, ginti dikha ke poochho, phir log karo
  Future<void> _runBulk(String noun, Future<NotificationBatch> Function() build) async {
    setState(() => _busy = true);
    try {
      final batch = await build();
      if (!mounted) return;
      if (batch.items.isEmpty) {
        _snack(batch.noPhone > 0
            ? 'No $noun to log. ${batch.noPhone} trainees have no guardian phone.'
            : 'No $noun to log.');
        return;
      }
      final n = batch.items.length;
      final ok = await _confirm(
        'Log $n $noun?',
        'This only creates simulated records. No real messages are sent.\n\n'
            '${batch.noPhone > 0 ? '${batch.noPhone} trainees have no guardian phone and will be skipped.\n' : ''}'
            'Anything already logged today will be skipped.',
      );
      if (!ok) return;
      final result = await logNotifications(batch.items);
      _snack(logResultMessage(result, noPhone: batch.noPhone));
    } catch (e) {
      debugPrint('Notification log failed: $e');
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _feeReminders() =>
      _runBulk('fee reminders', () async => feeReminders(await _students(), DateTime.now()));

  Future<void> _absentAlerts() => _runBulk('absent alerts', () async {
        final db = FirebaseFirestore.instance;
        final results = await Future.wait([
          db.collection('students').get(),
          db.collection('attendance').get(),
        ]);
        final students = liveStudentMapsFrom(results[0]);
        return absentAlerts(
            students, liveAttendance(attendanceDaysFrom(results[1]), idsOf(students)), DateTime.now());
      });

  Future<void> _batchAlert() async {
    setState(() => _busy = true);
    List<String> batches;
    try {
      final snap = await FirebaseFirestore.instance.collection('batches').get();
      batches = snap.docs
          .map((d) => (d.data()['batchName'] ?? '').toString().trim())
          .where((b) => b.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } catch (e) {
      debugPrint('Load batches failed: $e');
      _snack(friendlyError(e), error: true);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (batches.isEmpty) {
      _snack('No batches found.');
      return;
    }
    final input = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _BatchAlertDialog(batches: batches),
    );
    if (input == null) return;
    final (batch, text) = input;
    await _runBulk('batch alerts', () async => batchAlerts(await _students(), batch, text, DateTime.now()));
  }

  Future<void> _dailySummary() async {
    setState(() => _busy = true);
    try {
      final db = FirebaseFirestore.instance;
      final results = await Future.wait([
        db.collection('students').get(),
        db.collection('attendance').get(),
        db.collection('enquiries').get(),
      ]);
      final students = liveStudentMapsFrom(results[0]);
      final summary = dailySummary(
        students,
        liveAttendance(attendanceDaysFrom(results[1]), idsOf(students)),
        results[2].docs.map((d) => d.data()).where(isLive),
        DateTime.now(),
      );
      if (!mounted) return;
      final ok = await _confirm('Log 1 daily summary?', '${summary.message}\n\nThis is a simulated record only.');
      if (!ok) return;
      final result = await logNotifications([summary]);
      _snack(result.logged == 0 ? 'Already logged today.' : 'Daily summary logged.');
    } catch (e) {
      debugPrint('Daily summary failed: $e');
      _snack(friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Simulation: no real messages are sent.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textDark),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ActionButton(icon: Icons.currency_rupee, label: 'Generate fee reminders', onPressed: _busy ? null : _feeReminders),
              _ActionButton(icon: Icons.event_busy_outlined, label: 'Generate absent alerts', onPressed: _busy ? null : _absentAlerts),
              _ActionButton(icon: Icons.campaign_outlined, label: 'Batch alert', onPressed: _busy ? null : _batchAlert),
              _ActionButton(icon: Icons.summarize_outlined, label: 'Daily summary', onPressed: _busy ? null : _dailySummary),
            ],
          ),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: LinearProgressIndicator(color: AppColors.appPrimary, backgroundColor: AppColors.border),
          ),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            children: [
              _filterChip(null, 'All'),
              for (final t in NotificationType.values) _filterChip(t, t.label),
            ],
          ),
        ),
        Expanded(child: _list()),
      ],
    );
  }

  Widget _filterChip(NotificationType? type, String label) {
    final selected = _filter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = type),
        labelStyle: TextStyle(fontSize: 12.5, color: selected ? Colors.white : AppColors.textDark),
        selectedColor: AppColors.appPrimary,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: selected ? AppColors.appPrimary : AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _list() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const _Empty(text: 'Could not load notifications. Check your internet connection and try again.');
        }
        if (!snap.hasData) {
          return const AppLoader();
        }
        final docs = snap.data!.docs.map((d) => d.data()).where((d) {
          return _filter == null || d['type'] == _filter!.id;
        }).toList()
          // Naya pehle; abhi likha gaya (createdAt null) sabse upar
          ..sort((a, b) {
            final ta = _createdAt(a), tb = _createdAt(b);
            if (ta == null) return -1;
            if (tb == null) return 1;
            return tb.compareTo(ta);
          });
        if (docs.isEmpty) {
          return _Empty(
            text: _filter == null ? 'No notifications logged yet.' : 'No ${_filter!.label.toLowerCase()} records yet.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: docs.length,
          itemBuilder: (context, i) => _NotificationRow(data: docs[i]),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _ActionButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.appPrimary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ChannelChip extends StatelessWidget {
  final String channel;
  const _ChannelChip(this.channel);

  @override
  Widget build(BuildContext context) {
    final color = channel == 'SMS' ? AppColors.teal : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(channel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationRow({required this.data});

  String _str(String key) => (data[key] ?? '').toString().trim();

  String _time() {
    final t = _createdAt(data);
    return t == null ? 'Just now' : DateFormat('dd MMM, hh:mm a').format(t);
  }

  void _open(BuildContext context) {
    final type = notificationTypeFromId(_str('type'));
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              ),
              Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontSize: 13))),
            ],
          ),
        );
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(type?.label ?? 'Notification'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.appBackground,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(_str('message'), style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
              const SizedBox(height: 12),
              row('Trainee', [_str('traineeName'), _str('traineeId')].where((s) => s.isNotEmpty).join(' · ')),
              row('Batch', _str('batch')),
              row('Recipient', _str('recipient')),
              row('Channel', _str('channel')),
              row('Status', _str('status')),
              row('Time', _time()),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.appPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = notificationTypeFromId(_str('type'));
    final who = _str('traineeName').isNotEmpty ? _str('traineeName') : (_str('recipient').isEmpty ? '-' : _str('recipient'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: AppCard.radius,
        child: InkWell(
          borderRadius: AppCard.radius,
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: AppCard.radius,
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_typeIcon(type), size: 20, color: AppColors.appPrimary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _str('message'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textDark),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [type?.label ?? _str('type'), who, _time()].join(' · '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ChannelChip(_str('channel')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BatchAlertDialog extends StatefulWidget {
  final List<String> batches;
  const _BatchAlertDialog({required this.batches});

  @override
  State<_BatchAlertDialog> createState() => _BatchAlertDialogState();
}

class _BatchAlertDialogState extends State<_BatchAlertDialog> {
  final _controller = TextEditingController();
  String? _batch;
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (_batch == null) {
      setState(() => _error = 'Please select a batch.');
      return;
    }
    if (text.isEmpty) {
      setState(() => _error = 'Please write a message.');
      return;
    }
    Navigator.of(context).pop((_batch!, text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Batch alert'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _batch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Batch', border: OutlineInputBorder()),
              items: [for (final b in widget.batches) DropdownMenuItem(value: b, child: Text(b))],
              onChanged: (v) => setState(() {
                _batch = v;
                _error = '';
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              maxLines: 4,
              maxLength: 300,
              onChanged: (_) {
                if (_error.isNotEmpty) setState(() => _error = '');
              },
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'For example: Classes will start at 10 AM tomorrow.',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            if (_error.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(_error, style: const TextStyle(color: AppColors.danger, fontSize: 12.5)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.appPrimary),
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty({required this.text});

  @override
  Widget build(BuildContext context) {
    return EmptyState(icon: Icons.notifications_none, message: text);
  }
}
