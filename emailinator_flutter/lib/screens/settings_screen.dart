import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:emailinator_flutter/models/raw_email.dart';
import 'package:emailinator_flutter/utils/date_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _userEmail;
  List<RawEmail> _recentEmails = [];
  bool _isLoadingEmails = false;
  DateTime? _forcedToday = DateProvider.forcedToday;
  double? _processingBudgetUsd;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final userEmail = Supabase.instance.client.auth.currentUser!.email;
    _userEmail = userEmail;

    // Ensure user has an alias (create one if needed)
    final aliasRow = await Supabase.instance.client
        .from('email_aliases')
        .select('alias')
        .eq('user_id', userId)
        .eq('active', true)
        .maybeSingle();

    if (aliasRow == null) {
      final uuid = const Uuid().v4().replaceAll('-', '').substring(0, 8);
      final alias = 'u_$uuid@in.emailinator.app';
      await Supabase.instance.client.from('email_aliases').insert({
        'user_id': userId,
        'alias': alias,
        'active': true,
      });
    }

    await _loadRecentEmails();

    // Load processing budget for debug mode
    if (kDebugMode) {
      final budgetRow = await Supabase.instance.client
          .from('processing_budgets')
          .select('remaining_nano_usd')
          .eq('user_id', userId)
          .maybeSingle();

      if (budgetRow != null) {
        final nanoUsd = budgetRow['remaining_nano_usd'] as int?;
        if (nanoUsd != null) {
          _processingBudgetUsd =
              nanoUsd / 1000000000.0; // Convert nano USD to USD
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadRecentEmails() async {
    setState(() => _isLoadingEmails = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;

    final emailsResponse = await Supabase.instance.client
        .from('raw_emails')
        .select('*')
        .eq('user_id', userId)
        .order('sent_at', ascending: false)
        .limit(10);

    _recentEmails = (emailsResponse as List)
        .map((email) => RawEmail.fromJson(email))
        .toList();

    setState(() => _isLoadingEmails = false);
  }

  Future<void> _pickDebugDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _forcedToday ?? DateProvider.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: "Force today's date",
    );
    if (picked != null) {
      DateProvider.setForcedToday(picked);
      if (mounted) {
        setState(() => _forcedToday = picked);
      }
    }
  }

  void _clearDebugDate() {
    DateProvider.setForcedToday(null);
    if (mounted) {
      setState(() => _forcedToday = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Show user email address
          if (_userEmail != null)
            ListTile(
              title: const Text('User Email'),
              subtitle: Text(_userEmail!),
              leading: const Icon(Icons.person),
            ),
          if (_userEmail != null) const SizedBox(height: 16),

          // Setup menu item
          ListTile(
            title: const Text('Setup'),
            subtitle: const Text('Set up email forwarding'),
            leading: const Icon(Icons.settings_outlined),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.pushNamed(context, '/setup');
            },
          ),
          const SizedBox(height: 16),

          // 4. Last 10 Received Emails - Collapsible section
          ExpansionTile(
            title: const Text('Last 10 Received Emails'),
            leading: const Icon(Icons.email),
            children: [
              if (_isLoadingEmails)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_recentEmails.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'No emails received yet',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                ..._recentEmails.map((email) => _buildEmailListItem(email)),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(
                _forcedToday == null
                    ? "Debug: force today's date"
                    : "Debug: forcing today's date to ${DateFormat('yMMMd').format(_forcedToday!)}",
              ),
              onTap: _pickDebugDate,
              trailing: _forcedToday != null
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _clearDebugDate,
                    )
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: Text(
                _processingBudgetUsd != null
                    ? "Debug: processing budget: \$${_processingBudgetUsd!.toStringAsFixed(6)} USD"
                    : "Debug: processing budget: not available",
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmailListItem(RawEmail email) {
    final sentDate = email.sentAt ?? email.processedAt;
    final dateString = sentDate != null
        ? DateFormat('MMM d, y').format(sentDate)
        : 'Unknown date';

    return ListTile(
      title: Text(
        '$dateString: From ${email.fromEmail ?? 'Unknown sender'}',
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        email.subject ?? 'No subject',
        style: const TextStyle(fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      dense: true,
    );
  }
}
