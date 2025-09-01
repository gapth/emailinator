import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _forwardAlias;
  String? _verificationLink;
  int? _verificationId;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;

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

    if (mounted) {
      setState(() {});
    }
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
          if (_verificationLink != null)
            Card(
              color: Colors.amber[100],
              child: ListTile(
                title: const Text('Click here to verify the forward address.'),
                onTap: _launchVerification,
              ),
            ),
          if (_verificationLink != null) const SizedBox(height: 16),
          if (_forwardAlias != null)
            ListTile(
              title: const Text('Forward to this address'),
              subtitle: Text(_forwardAlias!),
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
        ],
      ),
    );
  }
}
