import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';
import 'paper_reader_page.dart';

class PaperListPage extends StatefulWidget {
  const PaperListPage({super.key});

  @override
  State<PaperListPage> createState() => _PaperListPageState();
}

class _PaperListPageState extends State<PaperListPage> {
  final _api = ApiService();
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _searchDebounce;

  List<Paper> _papers = [];
  List<Conference> _conferences = [];
  String? _selectedConference;
  String? _statusFilter;
  int _total = 0;
  bool _loading = false;
  bool _loadingMore = false;
  bool _syncing = false;
  String? _error;
  Map<String, dynamic>? _analysisQueueStatus;
  Map<String, dynamic>? _translationQueueStatus;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadConferences();
    _loadPapers();
    _loadQueueStatuses();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadConferences() async {
    try {
      final confs = await _api.getConferences();
      setState(() => _conferences = confs);
    } catch (_) {}
  }

  Future<void> _loadPapers({bool append = false}) async {
    if (_loading || _loadingMore) return;
    setState(() {
      if (append)
        _loadingMore = true;
      else {
        _loading = true;
        _error = null;
      }
    });

    try {
      final result = await _api.getPapers(
        conference: _selectedConference,
        keyword: _searchController.text.isEmpty ? null : _searchController.text,
        status: _statusFilter,
        offset: append ? _papers.length : 0,
        limit: 20,
      );
      setState(() {
        if (append)
          _papers.addAll(result.papers);
        else
          _papers = result.papers;
        _total = result.total;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_papers.length < _total) await _loadPapers(append: true);
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) _loadPapers();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([_loadConferences(), _loadPapers(), _loadQueueStatuses()]);
  }

  Future<void> _loadQueueStatuses() async {
    try {
      final results = await Future.wait([
        _api.getAnalysisQueueStatus(),
        _api.getTranslationQueueStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _analysisQueueStatus = results[0];
        _translationQueueStatus = results[1];
      });
    } catch (_) {}
  }

  Future<void> _syncConference(String conf) async {
    setState(() => _syncing = true);
    try {
      final count = await _api.syncConference(conf);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text('$conf 同步完成: $count 篇'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      _loadConferences();
      _loadPapers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $e'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
    setState(() => _syncing = false);
  }

  void _openReader(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => PaperReaderPage(
              papers: _papers,
              initialIndex: index,
              onLoadMore: () async {
                if (_papers.length < _total) await _loadPapers(append: true);
              },
            ),
      ),
    ).then((_) => _loadPapers());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    final horizontalPadding = Responsive.horizontalPadding(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            // ── 顶部大标题 + 搜索 ──
            SliverAppBar(
              floating: true,
              snap: true,
              // 1. 设置较小的高度，直接作为工具栏
              toolbarHeight: isCompact ? 60 : 64,
              // 2. 将原本标题的位置换成搜索框
              title: SizedBox(
                height: isCompact ? 40 : 44, // 限制搜索框高度
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  textAlignVertical: TextAlignVertical.center, // 内容垂直居中
                  style: TextStyle(fontSize: isCompact ? 13 : 14), // 字体调小一点
                  decoration: InputDecoration(
                    hintText: '搜索标题或摘要...',
                    hintStyle: TextStyle(
                      color: cs.outline.withOpacity(0.5),
                      fontSize: isCompact ? 13 : 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: cs.outline,
                      size: 20,
                    ),
                    suffixIcon:
                        _searchController.text.isEmpty
                            ? null
                            : IconButton(
                              tooltip: '清空搜索',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocus.unfocus();
                                _onSearchChanged('');
                              },
                            ),
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ), // 内部边距压缩
                  ),
                  onSubmitted: (_) => _loadPapers(),
                  onChanged: _onSearchChanged,
                ),
              ),
              centerTitle: false,
              titleSpacing: isCompact ? 12 : 16, // 控制搜索框左侧的间距
              actions: [
                // 同步按钮依然保留在最右侧
                _SyncButton(
                  conferences: _conferences,
                  syncing: _syncing,
                  onSync: _syncConference,
                ),
                const SizedBox(width: 8),
              ],
            ),
            // ── 过滤器 chips ──
            SliverToBoxAdapter(
              child: SizedBox(
                height: isCompact ? 44 : 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 6,
                  ),
                  children: [
                    _FilterPill(
                      label: '全部',
                      icon: Icons.all_inclusive_rounded,
                      selected:
                          _selectedConference == null && _statusFilter == null,
                      onTap: () {
                        setState(() {
                          _selectedConference = null;
                          _statusFilter = null;
                        });
                        _loadPapers();
                      },
                    ),
                    _FilterPill(
                      label: '在读',
                      icon: Icons.visibility_rounded,
                      selected: _statusFilter == 'reading',
                      color: Colors.orange,
                      onTap: () {
                        setState(
                          () =>
                              _statusFilter =
                                  _statusFilter == 'reading' ? null : 'reading',
                        );
                        _loadPapers();
                      },
                    ),
                    _FilterPill(
                      label: '已读',
                      icon: Icons.check_circle_rounded,
                      selected: _statusFilter == 'read',
                      color: Colors.green,
                      onTap: () {
                        setState(
                          () =>
                              _statusFilter =
                                  _statusFilter == 'read' ? null : 'read',
                        );
                        _loadPapers();
                      },
                    ),
                    const SizedBox(width: 4),
                    // 竖线分隔
                    Container(
                      width: 1,
                      height: 24,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      color: cs.outlineVariant.withOpacity(0.3),
                    ),
                    const SizedBox(width: 4),
                    for (final c in _conferences.where((c) => c.synced))
                      _FilterPill(
                        label: c.id,
                        selected: _selectedConference == c.id,
                        badge: '${c.paperCount}',
                        onTap: () {
                          setState(
                            () =>
                                _selectedConference =
                                    _selectedConference == c.id ? null : c.id,
                          );
                          _loadPapers();
                        },
                      ),
                  ],
                ),
              ),
            ),

            // ── 计数行 ──
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_total 篇',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.primary,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (_loading && _papers.isNotEmpty)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  6,
                  horizontalPadding,
                  10,
                ),
                child: _HomeQueuePanel(
                  analysisStatus: _analysisQueueStatus,
                  translationStatus: _translationQueueStatus,
                  onRefresh: _loadQueueStatuses,
                ),
              ),
            ),

            // ── 论文列表 ──
            if (_error != null)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '加载失败',
                  subtitle: _error!,
                  action: TextButton.icon(
                    onPressed: _loadPapers,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ),
              )
            else if (_loading && _papers.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_papers.isEmpty)
              SliverFillRemaining(
                child: _EmptyState(
                  icon: Icons.article_outlined,
                  title: '暂无论文',
                  subtitle: '点击右上角 ☁ 同步会议论文',
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                sliver: SliverList.separated(
                  itemCount: _papers.length + (_papers.length < _total ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (ctx, i) {
                    if (i >= _papers.length) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return _PaperCard(
                      paper: _papers[i],
                      index: i,
                      onTap: () => _openReader(i),
                    );
                  },
                ),
              ),

            // 底部留白
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 同步按钮 (带 sheet)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SyncButton extends StatelessWidget {
  final List<Conference> conferences;
  final bool syncing;
  final void Function(String) onSync;

  const _SyncButton({
    required this.conferences,
    required this.syncing,
    required this.onSync,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon:
          syncing
              ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary,
                ),
              )
              : Icon(Icons.cloud_sync_rounded, color: cs.primary),
      tooltip: '同步会议',
      onPressed: syncing ? null : () => _showSyncSheet(context),
    );
  }

  void _showSyncSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (ctx) => DraggableScrollableSheet(
            initialChildSize: 0.5,
            minChildSize: 0.3,
            maxChildSize: 0.7,
            expand: false,
            builder:
                (ctx, sc) => Column(
                  children: [
                    // handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_sync_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Text(
                            '同步会议',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        controller: sc,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: conferences.length,
                        itemBuilder: (ctx, i) {
                          final c = conferences[i];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color:
                                c.synced
                                    ? cs.surfaceContainerLowest
                                    : cs.surfaceContainerHighest.withOpacity(
                                      0.5,
                                    ),
                            child: ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      c.synced
                                          ? Colors.green.withOpacity(0.1)
                                          : cs.primaryContainer.withOpacity(
                                            0.3,
                                          ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  c.synced
                                      ? Icons.check_circle_rounded
                                      : Icons.cloud_download_rounded,
                                  color: c.synced ? Colors.green : cs.primary,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                c.id,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              subtitle:
                                  c.synced
                                      ? Text(
                                        '${c.paperCount} 篇',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.outline,
                                        ),
                                      )
                                      : Text(
                                        '未同步',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: cs.outline,
                                        ),
                                      ),
                              trailing: FilledButton.tonal(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  onSync(c.id);
                                },
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  minimumSize: const Size(0, 36),
                                ),
                                child: Text(c.synced ? '刷新' : '同步'),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 论文卡片
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PaperCard extends StatelessWidget {
  final Paper paper;
  final int index;
  final VoidCallback onTap;

  const _PaperCard({
    required this.paper,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);

    // 状态色带
    final statusColor = switch (paper.readStatus) {
      'reading' => Colors.orange,
      'read' => Colors.green,
      _ => Colors.transparent,
    };

    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 左侧色带
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    isCompact ? 12 : 14,
                    isCompact ? 12 : 14,
                    isCompact ? 12 : 14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 顶部行: 序号 + chips
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: cs.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                paper.conference,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSecondaryContainer,
                                  fontFamily: 'monospace',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          const Spacer(),
                          // 图标指示器
                          if (paper.hasAnalysis)
                            _MiniIcon(
                              icon: Icons.auto_awesome_rounded,
                              color: Colors.amber.shade600,
                            ),
                          if (paper.hasTranslation) ...[
                            const SizedBox(width: 4),
                            _MiniIcon(
                              icon: Icons.translate_rounded,
                              color: cs.tertiary,
                            ),
                          ],
                          if (paper.noteCount > 0) ...[
                            const SizedBox(width: 4),
                            _MiniIcon(
                              icon: Icons.sticky_note_2_rounded,
                              color: cs.secondary,
                              badge: '${paper.noteCount}',
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      // 标题
                      Text(
                        paper.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          color: cs.onSurface,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (paper.authorsShort.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          paper.authorsShort,
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.outline,
                            height: 1.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 右侧箭头
              if (!isCompact)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: cs.outlineVariant,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeQueuePanel extends StatelessWidget {
  final Map<String, dynamic>? analysisStatus;
  final Map<String, dynamic>? translationStatus;
  final VoidCallback onRefresh;

  const _HomeQueuePanel({
    required this.analysisStatus,
    required this.translationStatus,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active =
        _count(analysisStatus, 'running') +
        _count(analysisStatus, 'queued') +
        _count(translationStatus, 'running') +
        _count(translationStatus, 'queued');
    final failed =
        _count(analysisStatus, 'failed') + _count(translationStatus, 'failed');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withOpacity(0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dynamic_feed_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '后台队列',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              if (active > 0 || failed > 0)
                _QueueBadge(
                  label: active > 0 ? '$active 进行中' : '$failed 失败',
                  color: active > 0 ? cs.primary : cs.error,
                ),
              IconButton(
                tooltip: '刷新队列',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                onPressed: onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _QueueMiniSummary(
                  icon: Icons.auto_awesome_rounded,
                  label: '解读',
                  status: analysisStatus,
                  color: Colors.amber.shade700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QueueMiniSummary(
                  icon: Icons.translate_rounded,
                  label: '翻译',
                  status: translationStatus,
                  color: cs.tertiary,
                ),
              ),
            ],
          ),
          ..._recentRows(context),
        ],
      ),
    );
  }

  List<Widget> _recentRows(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final jobs = [
      ..._jobs(analysisStatus, '解读'),
      ..._jobs(translationStatus, '翻译'),
    ].take(3).toList();
    if (jobs.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      for (final job in jobs)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(_jobIcon(job.status), size: 14, color: cs.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${job.kind}${_jobStatusText(job.status)} · ${job.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  static int _count(Map<String, dynamic>? status, String key) {
    final value = status?[key];
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static List<({String kind, String status, String title})> _jobs(
    Map<String, dynamic>? status,
    String kind,
  ) {
    final jobs = (status?['recent_jobs'] as List?) ?? const [];
    return jobs.whereType<Map>().where((job) {
      final s = job['status']?.toString() ?? '';
      return s == 'running' || s == 'queued' || s == 'failed';
    }).map((job) {
      return (
        kind: kind,
        status: job['status']?.toString() ?? '',
        title: (job['title'] ?? job['paper_id'] ?? '').toString(),
      );
    }).toList();
  }

  static IconData _jobIcon(String status) {
    return switch (status) {
      'running' => Icons.play_circle_outline_rounded,
      'queued' => Icons.schedule_rounded,
      'failed' => Icons.error_outline_rounded,
      _ => Icons.circle_outlined,
    };
  }

  static String _jobStatusText(String status) {
    return switch (status) {
      'running' => '运行中',
      'queued' => '排队中',
      'failed' => '失败',
      _ => status,
    };
  }
}

class _QueueMiniSummary extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, dynamic>? status;
  final Color color;

  const _QueueMiniSummary({
    required this.icon,
    required this.label,
    required this.status,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final running = _count('running');
    final queued = _count('queued');
    final failed = _count('failed');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withOpacity(0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
          ),
          Text(
            '$running/$queued/$failed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.outline,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  int _count(String key) {
    final value = status?[key];
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _QueueBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _QueueBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? badge;
  const _MiniIcon({required this.icon, required this.color, this.badge});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        if (badge != null) ...[
          const SizedBox(width: 2),
          Text(
            badge!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Filter Pill
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _FilterPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final Color? color;
  final String? badge;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    this.icon,
    required this.selected,
    this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color:
                  selected
                      ? c.withOpacity(0.15)
                      : cs.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? c.withOpacity(0.4) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 14, color: selected ? c : cs.outline),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? c : cs.onSurfaceVariant,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color:
                          selected
                              ? c.withOpacity(0.2)
                              : cs.outlineVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: selected ? c : cs.outline,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 空状态
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: cs.outline),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: cs.outline),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
