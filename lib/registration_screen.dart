import 'dart:convert';
import 'package:flutter/material.dart';
import 'backend/registration_repository.dart';
import 'pager_screen.dart';

class RegistrationGate extends StatefulWidget {
  const RegistrationGate(
      {super.key,
      required this.repository,
      required this.platform,
      required this.appVersion});
  final RegistrationRepository repository;
  final String platform;
  final String appVersion;
  @override
  State<RegistrationGate> createState() => _RegistrationGateState();
}

class _RegistrationGateState extends State<RegistrationGate> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _password = TextEditingController();
  late final _device = TextEditingController(text: '${widget.platform} device');
  bool _loading = true;
  bool _restoreFailed = false;
  String? _error;
  Installation? _installation;
  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final saved = await widget.repository.restore();
      if (mounted) {
        setState(() {
          _installation = saved;
          _restoreFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _restoreFailed = true;
          _error =
              'Could not connect to local Supabase. Your registration has not been changed.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _join() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final member = await widget.repository.join(
          password: _password.text,
          displayName: _name.text,
          platform: widget.platform,
          deviceName: _device.text,
          appVersion: widget.appVersion);
      _password.clear();
      if (mounted) setState(() => _installation = member);
    } on JoinFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not join. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _password.dispose();
    _device.dispose();
    super.dispose();
  }

  String? _required(String? text, int max) =>
      text == null || text.trim().isEmpty
          ? 'Required'
          : text.trim().runes.length > max
              ? 'Use at most $max characters'
              : null;
  @override
  Widget build(BuildContext context) {
    if (_installation != null) {
      return PagerScreen(
          installation: _installation!, repository: widget.repository);
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Join Friend Pager')),
      body: Center(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: _restoreFailed
              ? Column(children: [
                  Text(_error!),
                  FilledButton(
                      onPressed: _loading ? null : _restore,
                      child: const Text('Retry connection'))
                ])
              : Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        'Join this installation using the shared group password. Display names do not have to be unique.'),
                    TextFormField(
                        key: const Key('display_name'),
                        controller: _name,
                        decoration:
                            const InputDecoration(labelText: 'Display name'),
                        validator: (value) => _required(value, 80),
                        enabled: !_loading),
                    TextFormField(
                        key: const Key('device_name'),
                        controller: _device,
                        decoration:
                            const InputDecoration(labelText: 'Device label'),
                        validator: (value) => _required(value, 120),
                        enabled: !_loading),
                    TextFormField(
                        key: const Key('group_password'),
                        controller: _password,
                        decoration:
                            const InputDecoration(labelText: 'Group password'),
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: !_loading,
                        validator: (value) => value == null || value.isEmpty
                            ? 'Required'
                            : utf8.encode(value).length > 72
                                ? 'Use at most 72 UTF-8 bytes'
                                : null),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Text(_error!, key: const Key('join_error')),
                    if (_loading) const CircularProgressIndicator(),
                    FilledButton(
                        key: const Key('join_group'),
                        onPressed: _loading ? null : _join,
                        child: const Text('Join group')),
                  ])),
        ),
      )),
    );
  }
}
