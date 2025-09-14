import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

enum EmailProvider { gmail, outlook, icloud, other }

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? _userAlias;
  EmailProvider? _selectedProvider;
  bool _isLoading = true;
  String? _verificationLink;
  int? _verificationId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Load user's active alias
    await _loadUserAlias();

    // Load saved provider preference
    await _loadSavedProvider();

    // Check for pending verification
    await _checkPendingVerification();

    setState(() => _isLoading = false);
  }

  Future<void> _loadUserAlias() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // No user logged in (e.g., in tests)
        return;
      }

      final userId = user.id;

      final aliasRow = await Supabase.instance.client
          .from('email_aliases')
          .select('alias')
          .eq('user_id', userId)
          .eq('active', true)
          .maybeSingle();

      if (aliasRow != null) {
        _userAlias = aliasRow['alias'];
      }
    } catch (e) {
      // Handle error gracefully (e.g., in test environment)
      // Error loading user alias - fail silently
    }
  }

  Future<void> _loadSavedProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final savedProvider = prefs.getString('selected_email_provider');
    if (savedProvider != null) {
      _selectedProvider = EmailProvider.values.firstWhere(
        (e) => e.name == savedProvider,
        orElse: () => EmailProvider.gmail,
      );
    }
  }

  Future<void> _checkPendingVerification() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // No user logged in (e.g., in tests)
        return;
      }

      final userId = user.id;

      final verificationRow = await Supabase.instance.client
          .from('forwarding_verifications')
          .select('id, verification_link')
          .eq('user_id', userId)
          .isFilter('clicked_at', null)
          .order('created_at', ascending: false)
          .maybeSingle();

      if (verificationRow != null) {
        _verificationId = verificationRow['id'];
        _verificationLink = verificationRow['verification_link'];
      }
    } catch (e) {
      // Handle error gracefully (e.g., in test environment)
      // Error checking pending verification - fail silently
    }
  }

  Future<void> _saveProvider(EmailProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_email_provider', provider.name);
    setState(() => _selectedProvider = provider);
  }

  Future<void> _launchVerification() async {
    if (_verificationLink == null) return;

    final uri = Uri.parse(_verificationLink!);
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (_verificationId != null) {
        await Supabase.instance.client
            .from('forwarding_verifications')
            .update({'clicked_at': DateTime.now().toIso8601String()}).eq(
                'id', _verificationId!);
      }

      setState(() {
        _verificationLink = null;
        _verificationId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification link opened')),
        );
      }
    }
  }

  Future<void> _openGmailForwarding() async {
    final uri = Uri.parse('https://mail.google.com/#settings/fwdandpop');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Gmail settings')),
        );
      }
    }
  }

  void _copyAlias() {
    if (_userAlias != null) {
      Clipboard.setData(ClipboardData(text: _userAlias!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Setup')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // If provider is already selected, go directly to provider-specific screen
    if (_selectedProvider != null) {
      return _buildProviderSpecificScreen();
    }

    // Show provider picker
    return _buildProviderPicker();
  }

  Widget _buildProviderPicker() {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Forward school emails to Emailinator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),

            // Alias display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: Row(
                children: [
                  const Text(
                    'Alias: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Expanded(
                    child: Text(
                      _userAlias ?? 'Loading...',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  TextButton(
                    onPressed: _userAlias != null ? _copyAlias : null,
                    child: const Text('copy'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            const Text(
              "You'll need ~2 minutes.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),

            const SizedBox(height: 32),

            // Provider buttons
            _buildProviderButton(
              provider: EmailProvider.gmail,
              title: 'Gmail',
              icon: Icons.email,
              enabled: true,
            ),

            const SizedBox(height: 12),
            _buildProviderButton(
              provider: EmailProvider.outlook,
              title: 'Outlook / Microsoft 365',
              icon: Icons.email_outlined,
              enabled: false, // Not implemented yet
            ),

            const SizedBox(height: 12),
            _buildProviderButton(
              provider: EmailProvider.icloud,
              title: 'iCloud',
              icon: Icons.cloud,
              enabled: false, // Not implemented yet
            ),

            const SizedBox(height: 12),
            _buildProviderButton(
              provider: EmailProvider.other,
              title: 'Other',
              icon: Icons.more_horiz,
              enabled: false, // Not implemented yet
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderButton({
    required EmailProvider provider,
    required String title,
    required IconData icon,
    required bool enabled,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? () => _saveProvider(provider) : null,
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: enabled ? null : Colors.grey.shade200,
          foregroundColor: enabled ? null : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildProviderSpecificScreen() {
    switch (_selectedProvider!) {
      case EmailProvider.gmail:
        return _buildGmailScreen();
      case EmailProvider.outlook:
      case EmailProvider.icloud:
      case EmailProvider.other:
        return _buildComingSoonScreen();
    }
  }

  Widget _buildGmailScreen() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gmail Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Clear saved provider to go back to picker
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('selected_email_provider');
            setState(() => _selectedProvider = null);
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Step G1
          _buildGmailStep(
            stepNumber: 'G1',
            title: 'Add your Emailinator address in Gmail',
            isCompleted: false, // TODO: Track completion state
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                // Open Gmail button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openGmailForwarding,
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Open Gmail Forwarding'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Address to paste
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.blue.shade50,
                  ),
                  child: Row(
                    children: [
                      const Text('Paste your address: '),
                      Expanded(
                        child: Text(
                          _userAlias ?? '',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _copyAlias,
                        child: const Text('Copy'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Tip
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.orange.shade50,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tip: If you have multiple Gmail accounts, switch to the right one in the top-right avatar.',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Verification section
                if (_verificationLink != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.green.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.green.shade50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Verification email received!',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _launchVerification,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Tap to verify'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Step G2 (minimal for now)
          _buildGmailStep(
            stepNumber: 'G2',
            title: 'Choose which emails to forward',
            isCompleted: false, // TODO: Track completion state
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Create a filter (only forward school mail)',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGmailStep({
    required String stepNumber,
    required String title,
    required bool isCompleted,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.shade100 : Colors.blue.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green : Colors.blue,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      stepNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isCompleted)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildComingSoonScreen() {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_selectedProvider!.name.toUpperCase()} Setup'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // Clear saved provider to go back to picker
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('selected_email_provider');
            setState(() => _selectedProvider = null);
          },
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'This provider setup will be available soon.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
