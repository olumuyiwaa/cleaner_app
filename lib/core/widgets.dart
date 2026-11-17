import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'l10n/strings.dart';

/// Human-readable text for any error, in the app language.
String errorText(BuildContext context, Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return context.t('error.network');
    return error.message;
  }
  return context.t('error.generic');
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(errorText(context, error)),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
}

void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// A soft round badge behind an icon, used by empty and error states.
class _IconBadge extends StatelessWidget {
  const _IconBadge(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary.withValues(alpha: 0.08),
      ),
      child: Icon(icon, size: 38, color: scheme.primary.withValues(alpha: 0.75)),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).isNetwork;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadge(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded),
            const SizedBox(height: 20),
            Text(
              errorText(context, error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: Text(context.t('common.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadge(icon),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(color: hint),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).hintColor,
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A small coloured pill, e.g. a job or leave status.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shows [message] and asks to confirm. Returns true when confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(ctx.t('common.cancel')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(100, 44),
            backgroundColor: destructive ? Theme.of(ctx).colorScheme.error : null,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A light tap for important actions (check-in, complete, send).
void tapFeedback() => HapticFeedback.lightImpact();

/// A firmer tap when something is finished.
void successFeedback() => HapticFeedback.mediumImpact();

/// A pulsing grey block shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 14, this.radius = 8});

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base.withValues(alpha: 0.06 + 0.06 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Placeholder cards while a list loads.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Skeleton(width: 120, height: 20),
                  Spacer(),
                  Skeleton(width: 64, height: 22, radius: 20),
                ],
              ),
              SizedBox(height: 14),
              Skeleton(width: 180),
              SizedBox(height: 10),
              Skeleton(),
              SizedBox(height: 8),
              Skeleton(width: 110),
            ],
          ),
        ),
      ),
    );
  }
}
