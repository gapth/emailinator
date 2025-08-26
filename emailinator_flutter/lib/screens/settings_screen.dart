import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _includeNoDueDate = true;
  List<String> _parentRequirementLevels = [];
  final List<String> _allLevels = ['NONE', 'OPTIONAL', 'VOLUNTEER', 'MANDATORY'];
  String? _forwardAlias;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    final response = await Supabase.instance.client
        .from('preferences')
        .select('parent_requirement_levels, include_no_due_date')
        .eq('user_id', userId)
        .maybeSingle();

    if (response != null) {
      _includeNoDueDate = response['include_no_due_date'] ?? true;
      _parentRequirementLevels = List<String>.from(response['parent_requirement_levels'] ?? []);
    }

    final aliasRow = await Supabase.instance.client
        .from('email_aliases')
        .select('alias')
        .eq('user_id', userId)
        .eq('active', true)
        .maybeSingle();

    if (aliasRow != null) {
      _forwardAlias = aliasRow['alias'];
    } else {
      final uuid = Uuid().v4().replaceAll('-', '').substring(0, 8);
      final alias = 'u_'+uuid+'@in.emailinator.app';
      await Supabase.instance.client.from('email_aliases').insert({
        'user_id': userId,
        'alias': alias,
        'active': true,
      });
      _forwardAlias = alias;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveSettings() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      await Supabase.instance.client.from('preferences').upsert({
        'user_id': userId,
        'parent_requirement_levels': _parentRequirementLevels,
        'include_no_due_date': _includeNoDueDate,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings saved!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save settings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          if (_forwardAlias != null)
            ListTile(
              title: Text('Forward to this address'),
              subtitle: Text(_forwardAlias!),
              trailing: IconButton(
                icon: Icon(Icons.copy),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _forwardAlias ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Copied to clipboard')),
                  );
                },
              ),
            ),
          if (_forwardAlias != null) SizedBox(height: 16),
          SwitchListTile(
            title: Text('Include tasks with no due date'),
            value: _includeNoDueDate,
            onChanged: (bool value) {
              setState(() {
                _includeNoDueDate = value;
              });
            },
          ),
          SizedBox(height: 16),
          Text('Parent Requirement Levels', style: Theme.of(context).textTheme.titleLarge),
          ..._allLevels.map((level) {
            return CheckboxListTile(
              title: Text(level),
              value: _parentRequirementLevels.contains(level),
              onChanged: (bool? value) {
                setState(() {
                  if (value == true) {
                    _parentRequirementLevels.add(level);
                  } else {
                    _parentRequirementLevels.remove(level);
                  }
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}
