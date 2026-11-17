import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/format.dart';
import '../../core/json.dart';
import '../../core/l10n/strings.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

class EarningRow {
  const EarningRow({
    required this.id,
    required this.amountCents,
    required this.status,
    required this.earnedAt,
  });

  final String id;
  final int amountCents;
  final String status;
  final DateTime? earnedAt;

  factory EarningRow.fromJson(Map<String, dynamic> j) => EarningRow(
        id: str(j['id']) ?? '',
        amountCents: intOf(j['amountCents']),
        status: str(j['status']) ?? 'PENDING',
        earnedAt: dateOf(j['earnedAt']),
      );
}

class PayoutRow {
  const PayoutRow({
    required this.id,
    required this.totalCents,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
  });

  final String id;
  final int totalCents;
  final String status;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  factory PayoutRow.fromJson(Map<String, dynamic> j) => PayoutRow(
        id: str(j['id']) ?? '',
        totalCents: intOf(j['totalCents']),
        status: str(j['status']) ?? '',
        periodStart: dateOf(j['periodStart']),
        periodEnd: dateOf(j['periodEnd']),
      );
}

class EarningsSummary {
  const EarningsSummary({
    required this.pendingCents,
    required this.lifetimePaidCents,
    required this.earnings,
    required this.payouts,
  });

  final int pendingCents;
  final int lifetimePaidCents;
  final List<EarningRow> earnings;
  final List<PayoutRow> payouts;

  factory EarningsSummary.fromJson(Map<String, dynamic> j) => EarningsSummary(
        pendingCents: intOf(j['pendingCents']),
        lifetimePaidCents: intOf(j['lifetimePaidCents']),
        earnings: mapsOf(j['recentEarnings']).map(EarningRow.fromJson).toList(),
        payouts: mapsOf(j['recentPayouts']).map(PayoutRow.fromJson).toList(),
      );
}

final earningsProvider = FutureProvider.autoDispose<EarningsSummary>((ref) async {
  final ApiClient api = ref.watch(apiClientProvider);
  return EarningsSummary.fromJson(mapOf(await api.get('/cleaners/me/earnings')));
});

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(earningsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.t('earnings.title'))),
      body: data.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(earningsProvider)),
        data: (s) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(earningsProvider);
            await ref.read(earningsProvider.future);
          },
          child: _body(context, s),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, EarningsSummary s) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Brand.navy, Brand.navyDark],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('earnings.pending'),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                f.money(s.pendingCents),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, size: 18, color: Color(0xFF9BE15D)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.t('earnings.paid'),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Text(
                      f.money(s.lifetimePaidCents),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/payouts'),
          icon: const Icon(Icons.account_balance_outlined),
          label: Text(context.t('earnings.payoutSetup')),
        ),
        SectionTitle(context.t('earnings.recent')),
        if (s.earnings.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.t('earnings.emptyEarnings'), style: TextStyle(color: hint)),
          )
        else
          Card(
            child: Column(
              children: [
                for (final e in s.earnings)
                  ListTile(
                    title: Text(f.money(e.amountCents),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(e.earnedAt == null ? '' : f.date(e.earnedAt!)),
                    trailing: StatusPill(
                      label: _earningLabel(context, e.status),
                      color: e.status == 'PAID'
                          ? Brand.green
                          : (e.status == 'IN_PAYOUT' ? Brand.blue : const Color(0xFFD98200)),
                    ),
                  ),
              ],
            ),
          ),
        SectionTitle(context.t('earnings.payouts')),
        if (s.payouts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(context.t('earnings.emptyPayouts'), style: TextStyle(color: hint)),
          )
        else
          Card(
            child: Column(
              children: [
                for (final p in s.payouts)
                  ListTile(
                    title: Text(f.money(p.totalCents),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      (p.periodStart != null && p.periodEnd != null)
                          ? '${f.date(p.periodStart!)} – ${f.date(p.periodEnd!)}'
                          : '',
                    ),
                    trailing: Text(p.status, style: TextStyle(color: hint, fontSize: 12)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _earningLabel(BuildContext context, String status) => switch (status) {
        'PAID' => context.t('earnings.status.paid'),
        'IN_PAYOUT' => context.t('earnings.status.inPayout'),
        _ => context.t('earnings.status.pending'),
      };
}
