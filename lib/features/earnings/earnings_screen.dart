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

final earningsProvider =
    FutureProvider.autoDispose<EarningsSummary>((ref) async {
  final ApiClient api = ref.watch(apiClientProvider);
  return EarningsSummary.fromJson(
      mapOf(await api.get('/cleaners/me/earnings')));
});

Color _earningColor(String status) => status == 'PAID'
    ? Brand.green
    : (status == 'IN_PAYOUT' ? Brand.blue : const Color(0xFFD98200));

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(earningsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: data.when(
          loading: () => const LoadingView(),
          error: (e, _) => ErrorView(
              error: e, onRetry: () => ref.invalidate(earningsProvider)),
          data: (s) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(earningsProvider);
              await ref.read(earningsProvider.future);
            },
            child: _body(context, s),
          ),
        ),
      ),
    );
  }

  Widget _emptyLine(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(text, style: TextStyle(color: Theme.of(context).hintColor)),
    );
  }

  Widget _body(BuildContext context, EarningsSummary s) {
    final f = context.fmt;
    final hint = Theme.of(context).hintColor;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        ScreenHeader(
          title: context.t('earnings.title'),
          trailing: Material(
            color: Theme.of(context).cardTheme.color,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => context.push('/payouts'),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      context.t('earnings.payoutSetup'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        HeroCard(
          chip:
              '${context.t('earnings.paid')} · ${f.money(s.lifetimePaidCents)}',
          label: context.t('earnings.pending'),
          value: f.money(s.pendingCents),
        ),
        if (s.earnings.isNotEmpty) ...[
          const SizedBox(height: 14),
          _EarningBars(earnings: s.earnings),
        ],
        SectionHeading(context.t('earnings.recent')),
        if (s.earnings.isEmpty)
          _emptyLine(context, context.t('earnings.emptyEarnings'))
        else
          for (final e in s.earnings) ...[
            _row(
              context,
              icon: Icons.payments_outlined,
              color: _earningColor(e.status),
              title: f.money(e.amountCents),
              subtitle: e.earnedAt == null ? '' : f.date(e.earnedAt!),
              trailing: StatusPill(
                label: _earningLabel(context, e.status),
                color: _earningColor(e.status),
              ),
            ),
            const SizedBox(height: 10),
          ],
        SectionHeading(context.t('earnings.payouts')),
        if (s.payouts.isEmpty)
          _emptyLine(context, context.t('earnings.emptyPayouts'))
        else
          for (final p in s.payouts) ...[
            _row(
              context,
              icon: Icons.account_balance_outlined,
              color: Brand.blue,
              title: f.money(p.totalCents),
              subtitle: (p.periodStart != null && p.periodEnd != null)
                  ? '${f.date(p.periodStart!)} – ${f.date(p.periodEnd!)}'
                  : '',
              trailing:
                  Text(p.status, style: TextStyle(color: hint, fontSize: 12)),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconTile(icon: icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle,
                        style: TextStyle(
                            color: Theme.of(context).hintColor, fontSize: 13)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  String _earningLabel(BuildContext context, String status) => switch (status) {
        'PAID' => context.t('earnings.status.paid'),
        'IN_PAYOUT' => context.t('earnings.status.inPayout'),
        _ => context.t('earnings.status.pending'),
      };
}

/// Rounded vertical bars for the latest earnings, oldest on the left. The
/// biggest bar carries its amount in a dark bubble. Bars are rounded at the
/// top and flat at the bottom, matching the UI guide.
class _EarningBars extends StatelessWidget {
  const _EarningBars({required this.earnings});

  final List<EarningRow> earnings;

  // Cycles through brand colours so each bar is visually distinct.
  static const _barColors = [
    Brand.navy,
    Color(0xFFE87722), // orange
    Brand.green,
    Brand.blue,
    Color(0xFF8E44AD), // purple
    Color(0xFFD98200), // amber
  ];

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final recent = earnings.take(6).toList().reversed.toList();
    final maxCents =
        recent.fold<int>(1, (m, e) => e.amountCents > m ? e.amountCents : m);
    const chartHeight = 150.0;
    const barWidth = 32.0;
    const topRadius = Radius.circular(8);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 36, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('earnings.recent'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: chartHeight + 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < recent.length; i++)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Stack(
                            alignment: Alignment.topCenter,
                            clipBehavior: Clip.none,
                            children: [
                              // Bar — rounded top, flat bottom
                              Container(
                                width: barWidth,
                                height: 24 +
                                    (chartHeight - 24) *
                                        recent[i].amountCents /
                                        maxCents,
                                decoration: BoxDecoration(
                                  color: _barColors[i % _barColors.length],
                                  borderRadius: const BorderRadius.only(
                                    topLeft: topRadius,
                                    topRight: topRadius,
                                  ),
                                ),
                              ),
                              // Amount bubble floats above the tallest bar
                              if (recent[i].amountCents == maxCents)
                                Positioned(
                                  top: -26,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Brand.navyDark,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: FittedBox(
                                      child: Text(
                                        f.money(recent[i].amountCents),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recent[i].earnedAt == null
                                ? ''
                                : f.dayShort(recent[i].earnedAt!),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).hintColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
