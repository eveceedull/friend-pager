import 'dart:async';
import 'package:flutter/material.dart';
import 'alert_sound.dart';
import 'backend/paging_repository.dart';
import 'backend/registration_repository.dart';
import 'paging_controller.dart';

class PagerScreen extends StatefulWidget {
  const PagerScreen(
      {super.key,
      required this.installation,
      required this.repository,
      this.paging,
      this.sound});
  final Installation installation;
  final RegistrationRepository repository;
  final PagingRepository? paging;
  final AlertSound? sound;
  @override
  State<PagerScreen> createState() => _PagerScreenState();
}

class _PagerScreenState extends State<PagerScreen> {
  late final PagingController _controller;
  bool _savingReceive = false;
  String? _receiveError;
  bool _armed = false;
  double _progress = 0;
  @override
  void initState() {
    super.initState();
    final registration = widget.repository;
    _controller = PagingController(
      repository: widget.paging ??
          (registration is SupabaseRegistrationRepository
              ? SupabasePagingRepository(registration.client)
              : null),
      sound: widget.sound ?? DeviceAlertSound(),
      installationId: widget.installation.id,
      receiving: widget.installation.receiving,
    )..addListener(_refresh);
    unawaited(_controller.start());
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_refresh);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _changeReceiving(bool enabled) async {
    final previous = _controller.receiving;
    setState(() {
      _savingReceive = true;
      _receiveError = null;
    });
    if (!enabled) _controller.setReceiving(false);
    try {
      final result = await widget.repository.setReceiving(enabled);
      if (mounted) _controller.setReceiving(result.receiving);
    } catch (_) {
      if (mounted) {
        _controller.setReceiving(previous);
        setState(() => _receiveError =
            'Could not save receiving preference. Check your connection or rejoin after restarting.');
      }
    } finally {
      if (mounted) setState(() => _savingReceive = false);
    }
  }

  void _confirm() {
    setState(() {
      _armed = false;
      _progress = 0;
    });
    unawaited(_controller.send());
  }

  @override
  Widget build(BuildContext context) {
    final alert = _controller.current;
    return Scaffold(
      appBar: AppBar(title: const Text('Friend Pager')),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Joined as ${widget.installation.displayName}'),
                Text(_controller.connected
                    ? 'Connected for live alerts'
                    : 'Live alerts disconnected'),
                if (_receiveError != null) Text(_receiveError!),
                if (_controller.error != null) Text(_controller.error!),
                SwitchListTile(
                    title: const Text('Receive Alerts'),
                    subtitle: const Text('This device only'),
                    value: _controller.receiving,
                    onChanged: _savingReceive ? null : _changeReceiving),
                if (_controller.receiving) ...[
                  TextButton(
                      onPressed: _controller.testSound,
                      child: const Text('Enable/test sound')),
                  if (_controller.soundError != null)
                    Text(_controller.soundError!),
                ],
                if (alert != null)
                  Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(children: [
                            Text('Alert from ${alert.senderName}',
                                key: const Key('received_alert'),
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            TextButton(
                                onPressed: _controller.dismiss,
                                child: const Text('Dismiss')),
                          ]))),
                const SizedBox(height: 16),
                if (!_armed) ...[
                  const Icon(Icons.notifications_active, size: 72),
                  const SizedBox(height: 24),
                ],
                if (_controller.sending)
                  const Text('Submitting alert…')
                else if (_controller.submitted) ...[
                  const Text('Alert submitted. Delivery is best effort.'),
                  FilledButton(
                      onPressed: _controller.resetSubmission,
                      child: const Text('Send another alert')),
                ] else if (_armed) ...[
                  const Text('Slide to confirm'),
                  Slider(
                      key: const Key('confirmation_slider'),
                      value: _progress,
                      allowedInteraction: SliderInteraction.slideOnly,
                      onChanged: (value) => setState(() => _progress = value),
                      onChangeEnd: (value) {
                        if (value >= 0.99) {
                          _confirm();
                        } else {
                          setState(() => _progress = 0);
                        }
                      }),
                  TextButton(
                      onPressed: () => setState(() {
                            _armed = false;
                            _progress = 0;
                          }),
                      child: const Text('Cancel')),
                ] else
                  FilledButton.icon(
                      key: const Key('send_alert_button'),
                      onPressed: () => setState(() => _armed = true),
                      icon: const Icon(Icons.campaign),
                      label: const Text('SEND ALERT')),
                const SizedBox(height: 24),
                const Text(
                    'Keep this app open to receive local alerts. The sending installation stays silent.',
                    textAlign: TextAlign.center),
              ],
            )),
      ))),
    );
  }
}
