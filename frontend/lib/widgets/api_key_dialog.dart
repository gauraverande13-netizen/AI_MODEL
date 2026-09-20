import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ApiKeyDialog extends StatefulWidget {
  const ApiKeyDialog({Key? key}) : super(key: key);

  @override
  State<ApiKeyDialog> createState() => _ApiKeyDialogState();
}

class _ApiKeyDialogState extends State<ApiKeyDialog> {
  String _provider = 'gemini';
  final TextEditingController _keyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _provider = prefs.getString('llm_provider') ?? 'gemini';
      _keyController.text = prefs.getString('api_key') ?? '';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('llm_provider', _provider);
    await prefs.setString('api_key', _keyController.text.trim());
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('API Settings (BYOK)'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select AI Provider:'),
            Row(
              children: [
                Radio<String>(
                  value: 'gemini',
                  groupValue: _provider,
                  onChanged: (val) => setState(() => _provider = val!),
                ),
                const Text('Gemini'),
                Radio<String>(
                  value: 'openai',
                  groupValue: _provider,
                  onChanged: (val) => setState(() => _provider = val!),
                ),
                const Text('OpenAI'),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _keyController,
              decoration: const InputDecoration(
                labelText: 'API Key (Optional)',
                hintText: 'Leave empty to use backend .env key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                if (_provider == 'gemini') {
                  _launchUrl('https://aistudio.google.com/app/apikey');
                } else {
                  _launchUrl('https://platform.openai.com/api-keys');
                }
              },
              child: Text(
                'Get ${_provider == 'gemini' ? 'Gemini' : 'OpenAI'} Key',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
