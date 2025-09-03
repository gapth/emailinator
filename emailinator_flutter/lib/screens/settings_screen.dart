import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:emailinator_flutter/models/raw_email.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _forwardAlias;
  String? _verificationLink;
  int? _verificationId;
  String? _userEmail;
  List<RawEmail> _recentEmails = [];
  bool _isLoadingEmails = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final userEmail = Supabase.instance.client.auth.currentUser!.email;
    _userEmail = userEmail;

    final aliasRow = await Supabase.instance.client
        .from('email_aliases')
        .select('alias')
        .eq('user_id', userId)
        .eq('active', true)
        .maybeSingle();

    if (aliasRow != null) {
      _forwardAlias = aliasRow['alias'];
    } else {
      final uuid = const Uuid().v4().replaceAll('-', '').substring(0, 8);
      final alias = 'u_$uuid@in.emailinator.app';
      await Supabase.instance.client.from('email_aliases').insert({
        'user_id': userId,
        'alias': alias,
        'active': true,
      });
      _forwardAlias = alias;
    }

    final verificationRow = await Supabase.instance.client
        .from('forwarding_verifications')
        .select('id, verification_link')
        .eq('user_id', userId)
        .isFilter('clicked_at', null)
        .order('created_at', ascending: false)
        .maybeSingle();

    if (verificationRow != null) {
      _verificationId = verificationRow['id'] as int?;
      _verificationLink = verificationRow['verification_link'] as String?;
    }

    await _loadRecentEmails();

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

  Future<void> _launchVerification() async {
    if (_verificationLink == null) return;
    final uri = Uri.parse(_verificationLink!);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (_verificationId != null) {
        await Supabase.instance.client
            .from('forwarding_verifications')
            .update({'clicked_at': DateTime.now().toIso8601String()}).eq(
                'id', _verificationId ?? 0);
      }
      if (mounted) {
        setState(() {
          _verificationLink = null;
          _verificationId = null;
        });
      }
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

          // 2. Show forward verification if pending
          if (_verificationLink != null)
            Card(
              color: Colors.amber[100],
              child: ListTile(
                title: const Text('Forward verification pending'),
                subtitle:
                    const Text('Click here to verify the forward address.'),
                leading: const Icon(Icons.warning),
                onTap: _launchVerification,
              ),
            ),
          if (_verificationLink != null) const SizedBox(height: 16),

          // 3. Show current "Forward to this address" section
          if (_forwardAlias != null)
            ListTile(
              title: const Text('Forward to this address'),
              subtitle: Text(_forwardAlias!),
              leading: const Icon(Icons.forward_to_inbox),
              trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _forwardAlias ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ),
          if (_forwardAlias != null) const SizedBox(height: 24),

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
