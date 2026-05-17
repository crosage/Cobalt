import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final _api = ApiService();
  Stats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final stats = await _api.getStats();
      setState(() => _stats = stats);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);

    return Scaffold(
      body:
          _stats == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    // 头部
                    SliverAppBar(
                      floating: true,
                      expandedHeight: Responsive.appBarExpandedHeight(context),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                cs.secondaryContainer.withOpacity(0.3),
                                cs.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            Icons.analytics_rounded,
                            color: cs.secondary,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '阅读统计',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: isCompact ? 18 : 20,
                            ),
                          ),
                        ],
                      ),
                      centerTitle: false,
                    ),

                    SliverPadding(
                      padding: EdgeInsets.all(
                        Responsive.horizontalPadding(context),
                      ),
                      sliver: SliverList.list(
                        children: [
                          // ── 四宫格数字 ──
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.totalPapers,
                                  label: '总论文',
                                  icon: Icons.library_books_rounded,
                                  gradient: [
                                    cs.primary.withOpacity(0.1),
                                    cs.primary.withOpacity(0.03),
                                  ],
                                  color: cs.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.read,
                                  label: '已读',
                                  icon: Icons.check_circle_rounded,
                                  gradient: [
                                    Colors.green.withOpacity(0.1),
                                    Colors.green.withOpacity(0.03),
                                  ],
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.reading,
                                  label: '在读',
                                  icon: Icons.visibility_rounded,
                                  gradient: [
                                    Colors.orange.withOpacity(0.1),
                                    Colors.orange.withOpacity(0.03),
                                  ],
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.unread,
                                  label: '未读',
                                  icon: Icons.circle_outlined,
                                  gradient: [
                                    cs.outlineVariant.withOpacity(0.1),
                                    cs.outlineVariant.withOpacity(0.03),
                                  ],
                                  color: cs.outline,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ── 进度条 ──
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.outlineVariant.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '阅读进度',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${(_stats!.totalPapers > 0 ? _stats!.read / _stats!.totalPapers * 100 : 0).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                        color: cs.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    height: 10,
                                    child: LinearProgressIndicator(
                                      value:
                                          _stats!.totalPapers > 0
                                              ? _stats!.read /
                                                  _stats!.totalPapers
                                              : 0,
                                      backgroundColor:
                                          cs.surfaceContainerHighest,
                                      valueColor: AlwaysStoppedAnimation(
                                        cs.primary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ── 解读 & 笔记 ──
                          Row(
                            children: [
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.analyzed,
                                  label: '已解读',
                                  icon: Icons.auto_awesome_rounded,
                                  gradient: [
                                    Colors.amber.withOpacity(0.12),
                                    Colors.amber.withOpacity(0.03),
                                  ],
                                  color: Colors.amber.shade700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatTile(
                                  value: _stats!.notes,
                                  label: '笔记',
                                  icon: Icons.edit_note_rounded,
                                  gradient: [
                                    cs.secondary.withOpacity(0.1),
                                    cs.secondary.withOpacity(0.03),
                                  ],
                                  color: cs.secondary,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── 会议分布 ──
                          if (_stats!.byConference.isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(
                                  Icons.school_rounded,
                                  size: 16,
                                  color: cs.outline,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '按会议分布',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: cs.outline,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            for (final entry
                                in _stats!.byConference.entries.toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                              _ConfBar(
                                name: entry.key,
                                count: entry.value,
                                total: _stats!.totalPapers,
                                color: cs.primary,
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final Color color;

  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(isCompact ? 14 : 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: TextStyle(
              fontSize: isCompact ? 24 : 30,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'monospace',
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              color: cs.outline,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ConfBar extends StatelessWidget {
  final String name;
  final int count;
  final int total;
  final Color color;
  const _ConfBar({
    required this.name,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ratio = total > 0 ? count / total : 0.0;
    final isCompact = Responsive.isCompact(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: isCompact ? 64 : 90,
            child: Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isCompact ? 6 : 8),
          Expanded(
            child: Container(
              height: 22,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: ratio,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.6)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: isCompact ? 8 : 10),
          SizedBox(
            width: isCompact ? 34 : 40,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
