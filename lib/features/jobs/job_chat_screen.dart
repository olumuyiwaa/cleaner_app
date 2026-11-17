import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets.dart';
import 'job_models.dart';
import 'jobs_repository.dart';

/// Chat with the customer about one job. New messages are fetched by
/// polling (only messages after the last one seen).
class JobChatScreen extends ConsumerStatefulWidget {
  const JobChatScreen({super.key, required this.jobId});

  final String jobId;

  @override
  ConsumerState<JobChatScreen> createState() => _JobChatScreenState();
}

class _JobChatScreenState extends ConsumerState<JobChatScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  List<ChatMessage> _messages = [];
  bool _open = true;
  String? _with;
  bool _loading = true;
  Object? _error;
  bool _sending = false;
  bool _polling = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _timer = Timer.periodic(AppConfig.chatPollInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    if (_polling) return;
    _polling = true;
    try {
      final after = (!initial && _messages.isNotEmpty) ? _messages.last.createdAt : null;
      final thread = await ref.read(jobsRepositoryProvider).messages(widget.jobId, after: after);
      if (!mounted) return;
      setState(() {
        _open = thread.open;
        _with = thread.withName ?? _with;
        if (initial || after == null) {
          _messages = thread.messages;
        } else {
          final known = _messages.map((m) => m.id).toSet();
          _messages = [
            ..._messages,
            ...thread.messages.where((m) => !known.contains(m.id)),
          ];
        }
        _loading = false;
        _error = null;
      });
      if (thread.messages.isNotEmpty) _toBottom();
    } catch (e) {
      // Keep showing what we have; only the first load shows an error page.
      if (mounted && _loading) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    } finally {
      _polling = false;
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(jobsRepositoryProvider).sendMessage(widget.jobId, text);
      _controller.clear();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_with ?? context.t('chat.title')),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _content(context)),
            if (_open) _composer(context) else _closedBanner(context),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null && _messages.isEmpty) {
      return ErrorView(
        error: _error!,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load(initial: true);
        },
      );
    }
    if (_messages.isEmpty) {
      return EmptyView(
        icon: Icons.chat_bubble_outline,
        title: context.t('chat.empty'),
        message: _open ? context.t('chat.emptyHint') : null,
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _Bubble(message: _messages[i]),
    );
  }

  Widget _composer(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.t('chat.hint'),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _sending ? null : _send,
            tooltip: context.t('chat.send'),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  Widget _closedBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        context.t('chat.closed'),
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).hintColor),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mine = message.mine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!mine && message.name != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.name!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            Text(
              message.body,
              style: TextStyle(color: mine ? scheme.onPrimary : scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
