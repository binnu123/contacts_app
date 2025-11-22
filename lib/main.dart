import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

void main() {
  runApp(const ContactBackupApp());
}

class ContactBackupApp extends StatelessWidget {
  const ContactBackupApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contact Backup',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = false;
  List<Contact> _contacts = [];
  Set<int> _selectedIndexes = {};
  String? _lastSavedPath;

  Future<bool> _requestContactPermission({bool write = false}) async {
    final status = await Permission.contacts.request();
    if (!status.isGranted) return false;
    return true;
  }

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final ok = await _requestContactPermission();
    if (!ok) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Contacts permission required')));
      return;
    }

    final Iterable<Contact> contacts = await ContactsService.getContacts(withThumbnails: false);
    setState(() {
      _contacts = contacts.toList();
      _selectedIndexes.clear();
      _loading = false;
    });
  }

  Future<void> _backupSelectedContacts() async {
    if (_contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Load contacts first')));
      return;
    }

    final selected = _selectedIndexes.isEmpty ? List.generate(_contacts.length, (i) => i) : _selectedIndexes.toList();

    final jsonContacts = selected.map((i) {
      final c = _contacts[i];
      return {
        'name': c.displayName ?? '',
        'phones': c.phones?.map((p) => p.value ?? '').toList() ?? [],
        'emails': c.emails?.map((e) => e.value ?? '').toList() ?? [],
      };
    }).toList();

    final jsonString = const JsonEncoder.withIndent('  ').convert(jsonContacts);
    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'contacts_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonString);

    setState(() => _lastSavedPath = file.path);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved: $fileName')));
  }

  Future<void> _shareBackup() async {
    if (_lastSavedPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No backup available.')));
      return;
    }
    await Share.shareXFiles([XFile(_lastSavedPath!)], text: 'Contacts backup');
  }

  Future<void> _restoreFromJson() async {
    final ok = await _requestContactPermission(write: true);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contacts permission required to restore')));
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final List<dynamic> data = json.decode(content);

    int restored = 0;
    for (final item in data) {
      try {
        final c = Contact();
        c.givenName = item['name'] ?? '';
        final phones = <Item>[];
        if (item['phones'] != null) {
          for (final p in (item['phones'] as List)) {
            if (p?.toString().trim().isNotEmpty ?? false) {
              phones.add(Item(label: 'mobile', value: p.toString()));
            }
          }
        }
        c.phones = phones;

        final emails = <Item>[];
        if (item['emails'] != null) {
          for (final e in (item['emails'] as List)) {
            if (e?.toString().trim().isNotEmpty ?? false) {
              emails.add(Item(label: 'home', value: e.toString()));
            }
          }
        }
        c.emails = emails;

        await ContactsService.addContact(c);
        restored++;
      } catch (e) {
        // ignore invalid entries
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $restored contacts')));
    await _loadContacts();
  }

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Backup')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              ElevatedButton.icon(
                onPressed: _loadContacts,
                icon: const Icon(Icons.refresh),
                label: const Text('Load Contacts'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _backupSelectedContacts,
                icon: const Icon(Icons.backup),
                label: const Text('Backup Selected'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _shareBackup,
                icon: const Icon(Icons.share),
                label: const Text('Share Last Backup')),
            ]),

            const SizedBox(height: 12),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _contacts.length,
                      itemBuilder: (context, index) {
                        final c = _contacts[index];
                        final phone = (c.phones?.isNotEmpty ?? false) ? c.phones!.first.value : '';
                        final selected = _selectedIndexes.contains(index);
                        return CheckboxListTile(
                          title: Text(c.displayName ?? 'No Name'),
                          subtitle: Text(phone ?? ''),
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) _selectedIndexes.add(index);
                              else _selectedIndexes.remove(index);
                            });
                          },
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _restoreFromJson,
              icon: const Icon(Icons.upload_file),
              label: const Text('Restore From JSON'),
            ),
          ],
        ),
      ),
    );
  }
}
