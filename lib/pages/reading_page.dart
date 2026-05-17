import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';
import 'paper_reader_page.dart';

class ReadingPage extends StatefulWidget {
  const ReadingPage({super.key});

  @override
  State<ReadingPage> createState() => _ReadingPageState();
}

class _ReadingPageState extends State<ReadingPage>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabController;

  List<Paper> _readingPapers = [];
  List<Paper> _readPapers = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final reading = await _api.getPapers(status: 'reading', limit: 100);
      final read = await _api.getPapers(status: 'read', limit: 100);
      setState(() {
        _readingPapers = reading.papers;
        _readPapers = read.papers;
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _openReader(List<Paper> papers, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaperReaderPage(papers: papers, initialIndex: index),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder:
            (ctx, inner) => [
              SliverAppBar(
                floating: true,
                snap: true,
                expandedHeight: Responsive.appBarExpandedHeight(context),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.tertiaryContainer.withOpacity(0.3),
                          cs.surface,
                        ],
                      ),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: cs.tertiary, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      '阅读记录',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isCompact ? 18 : 20,
                      ),
                    ),
                  ],
                ),
                centerTitle: false,
                bottom: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerHeight: 0,
                  tabs: [
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_rounded,
                              size: 16,
                              color: Colors.orange.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text('在读 (${_readingPapers.length})'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text('已读 (${_readPapers.length})'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
        body:
            _loading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                  controller: _tabController,
                  children: [
                    _PaperStatusList(
                      papers: _readingPapers,
                      emptyIcon: Icons.visibility_off_rounded,
                      emptyTitle: '暂无在读论文',
                      emptySubtitle: '从论文列表点击进入阅读',
                      statusColor: Colors.orange,
                      onRefresh: _load,
                      onTap: (i) => _openReader(_readingPapers, i),
                    ),
                    _PaperStatusList(
                      papers: _readPapers,
                      emptyIcon: Icons.book_outlined,
                      emptyTitle: '暂无已读论文',
                      emptySubtitle: '阅读后点击 ✓ 标记完成',
                      statusColor: Colors.green,
                      onRefresh: _load,
                      onTap: (i) => _openReader(_readPapers, i),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _PaperStatusList extends StatelessWidget {
  final List<Paper> papers;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final Color statusColor;
  final Future<void> Function() onRefresh;
  final void Function(int) onTap;

  const _PaperStatusList({
    required this.papers,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.statusColor,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);

    if (papers.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  emptyIcon,
                  size: 48,
                  color: statusColor.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptySubtitle,
                style: TextStyle(fontSize: 13, color: cs.outline),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.symmetric(
          vertical: 8,
          horizontal: isCompact ? 8 : 12,
        ),
        itemCount: papers.length,
        itemBuilder: (ctx, i) {
          final p = papers[i];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            color: cs.surfaceContainerLowest,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTap(i);
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 12 : 14),
                child: Row(
                  children: [
                    // 序号头像
                    Container(
                      width: isCompact ? 34 : 40,
                      height: isCompact ? 34 : 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.15),
                            statusColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isCompact ? 10 : 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.secondaryContainer.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  p.conference,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onSecondaryContainer,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  p.authorsShort,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: cs.outline,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 指示器
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (p.hasAnalysis)
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 14,
                            color: Colors.amber.shade600,
                          ),
                        if (p.noteCount > 0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sticky_note_2_rounded,
                                size: 12,
                                color: cs.secondary,
                              ),
                              Text(
                                '${p.noteCount}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(width: 4),
                    if (!isCompact)
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: cs.outlineVariant,
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
