import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';

/// 核心阅读页面 — 当前论文内横滑查看原文、插图、翻译和笔记
class PaperReaderPage extends StatefulWidget {
  final List<Paper> papers;
  final int initialIndex;
  final Future<void> Function()? onLoadMore;

  const PaperReaderPage({
    super.key,
    required this.papers,
    required this.initialIndex,
    this.onLoadMore,
  });

  @override
  State<PaperReaderPage> createState() => _PaperReaderPageState();
}

class _PaperReaderPageState extends State<PaperReaderPage> {
  late int _currentIndex;
  final _api = ApiService();

  final Map<String, Paper> _detailCache = {};
  final Set<String> _loadingIds = {};
  final Set<String> _analyzingIds = {};
  final Set<String> _translatingIds = {};
  final Set<String> _pollingAnalysisIds = {};
  final Set<String> _pollingTranslationIds = {};
  Map<String, dynamic>? _analysisQueueStatus;
  Map<String, dynamic>? _translationQueueStatus;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadDetail(widget.papers[_currentIndex].id);
    _loadQueueStatuses();
    _api.updateReadingStatus(widget.papers[_currentIndex].id, 'reading');
  }

  @override
  void dispose() => super.dispose();

  Future<void> _loadDetail(String paperId) async {
    if (_loadingIds.contains(paperId)) {
      return;
    }
    setState(() => _loadingIds.add(paperId));
    try {
      final detail = await _api.getPaper(paperId);
      setState(() {
        _detailCache[paperId] = detail;
        _loadingIds.remove(paperId);
        if ((detail.analysis ?? '').trim().isNotEmpty) {
          _analyzingIds.remove(paperId);
        } else if (detail.analysisJobStatus == 'queued' ||
            detail.analysisJobStatus == 'running') {
          _analyzingIds.add(paperId);
        }
        if ((detail.translation ?? '').trim().isNotEmpty) {
          _translatingIds.remove(paperId);
        } else if (detail.translationJobStatus == 'queued' ||
            detail.translationJobStatus == 'running') {
          _translatingIds.add(paperId);
        }
      });
      if (detail.analysisJobStatus == 'queued' ||
          detail.analysisJobStatus == 'running') {
        _pollAnalysis(paperId);
      }
      if (detail.translationJobStatus == 'queued' ||
          detail.translationJobStatus == 'running') {
        _pollTranslation(paperId);
      }
    } catch (e) {
      setState(() => _loadingIds.remove(paperId));
    }
  }

  Future<void> _triggerAnalysis(String paperId, {bool force = false}) async {
    if (_analyzingIds.contains(paperId)) return;
    setState(() => _analyzingIds.add(paperId));
    try {
      final result = await _api.queueAnalysis(paperId, force: force);
      await _loadQueueStatuses();
      final status = result['status']?.toString() ?? 'queued';
      if (status == 'cached') {
        final detail = await _api.getPaper(paperId);
        setState(() {
          _detailCache[paperId] = detail;
          _analyzingIds.remove(paperId);
        });
        return;
      }
      _pollAnalysis(paperId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'running' ? '解读已在后台生成中' : '已加入解读队列'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _analyzingIds.remove(paperId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('解读失败: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteAnalysis(String paperId) async {
    try {
      await _api.deleteAnalysis(paperId);
      final detail = await _api.getPaper(paperId);
      await _loadQueueStatuses();
      setState(() {
        _detailCache[paperId] = detail;
        _analyzingIds.remove(paperId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除解读失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pollAnalysis(String paperId) async {
    if (_pollingAnalysisIds.contains(paperId)) return;
    _pollingAnalysisIds.add(paperId);
    for (var i = 0; i < 40; i++) {
      await Future<void>.delayed(const Duration(seconds: 10));
      if (!mounted || !_analyzingIds.contains(paperId)) break;
      try {
        final status = await _api.getAnalysisStatus(paperId);
        await _loadQueueStatuses();
        if (status['cached'] == true) {
          final detail = await _api.getPaper(paperId);
          if (!mounted) break;
          setState(() {
            _detailCache[paperId] = detail;
            _analyzingIds.remove(paperId);
          });
          break;
        }
        if (status['status'] == 'failed') {
          if (!mounted) break;
          setState(() => _analyzingIds.remove(paperId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('后台解读失败，可以重新生成'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
        }
      } catch (_) {}
    }
    _pollingAnalysisIds.remove(paperId);
  }

  Future<void> _triggerTranslation(String paperId, {bool force = false}) async {
    await _queueTranslation(paperId, force: force);
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

  Future<void> _queueTranslation(
    String paperId, {
    bool force = false,
    bool showSnackBar = true,
  }) async {
    if (_translatingIds.contains(paperId)) return;
    setState(() => _translatingIds.add(paperId));
    try {
      final result = await _api.queueTranslation(paperId, force: force);
      await _loadQueueStatuses();
      final status = result['status']?.toString() ?? 'queued';
      if (status == 'cached') {
        final detail = await _api.getPaper(paperId);
        setState(() {
          _detailCache[paperId] = detail;
          _translatingIds.remove(paperId);
        });
        return;
      }
      _pollTranslation(paperId);
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'running' ? '全文翻译已在后台生成中' : '已加入后台翻译队列'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _translatingIds.remove(paperId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加入后台翻译失败: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pollTranslation(String paperId) async {
    if (_pollingTranslationIds.contains(paperId)) return;
    _pollingTranslationIds.add(paperId);
    for (var i = 0; i < 24; i++) {
      await Future<void>.delayed(const Duration(seconds: 15));
      if (!mounted || !_translatingIds.contains(paperId)) break;
      try {
        final status = await _api.getTranslationStatus(paperId);
        await _loadQueueStatuses();
        if (status['cached'] == true) {
          final detail = await _api.getPaper(paperId);
          if (!mounted) break;
          setState(() {
            _detailCache[paperId] = detail;
            _translatingIds.remove(paperId);
          });
          break;
        }
        if (status['status'] == 'failed') {
          if (!mounted) break;
          setState(() => _translatingIds.remove(paperId));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('后台翻译失败，请稍后重试'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          break;
        }
      } catch (_) {}
    }
    _pollingTranslationIds.remove(paperId);
  }

  void _goToPaper(int index) {
    if (index < 0 || index >= widget.papers.length) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    final paper = widget.papers[index];
    _loadDetail(paper.id);
    _loadQueueStatuses();
    _api.updateReadingStatus(paper.id, 'reading');
    if (index >= widget.papers.length - 3 && widget.onLoadMore != null) {
      widget.onLoadMore!();
    }
  }

  void _markAsRead(String paperId) {
    HapticFeedback.mediumImpact();
    _api.updateReadingStatus(paperId, 'read');
    setState(() {
      for (final p in widget.papers) {
        if (p.id == paperId) {
          p.readStatus = 'read';
          break;
        }
      }
      final cached = _detailCache[paperId];
      if (cached != null) cached.readStatus = 'read';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('已标记为已读'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paper = widget.papers[_currentIndex];
    final detail = _detailCache[paper.id];
    final effectivePaper = detail ?? paper;

    return Scaffold(
      // 沉浸式 AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: cs.onSurface,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: _PageIndicator(
          current: _currentIndex + 1,
          total: widget.papers.length,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: '上一篇',
            onPressed:
                _currentIndex > 0 ? () => _goToPaper(_currentIndex - 1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: '下一篇',
            onPressed:
                _currentIndex < widget.papers.length - 1
                    ? () => _goToPaper(_currentIndex + 1)
                    : null,
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 20,
                color:
                    effectivePaper.readStatus == 'read'
                        ? Colors.green
                        : cs.onSurface,
              ),
            ),
            tooltip: '标记已读',
            onPressed: () => _markAsRead(paper.id),
          ),
          const SizedBox(width: 4),
        ],
      ),
      extendBodyBehindAppBar: false,
      body: _PaperView(
        key: ValueKey(effectivePaper.id),
        paper: effectivePaper,
        isLoading: _loadingIds.contains(paper.id),
        isAnalyzing: _analyzingIds.contains(paper.id),
        isTranslating: _translatingIds.contains(paper.id),
        analysisQueueStatus: _analysisQueueStatus,
        translationQueueStatus: _translationQueueStatus,
        onAnalyze: () => _triggerAnalysis(paper.id),
        onReanalyze: () => _triggerAnalysis(paper.id, force: true),
        onDeleteAnalysis: () => _deleteAnalysis(paper.id),
        onTranslate: () => _triggerTranslation(paper.id),
        onRetranslate: () => _triggerTranslation(paper.id, force: true),
        onAddNote: (content) => _addNote(paper.id, content),
        onDeleteNote: (noteId) => _deleteNote(paper.id, noteId),
      ),
    );
  }

  Future<void> _addNote(String paperId, String content) async {
    try {
      await _api.createNote(paperId, content);
      final detail = await _api.getPaper(paperId);
      setState(() => _detailCache[paperId] = detail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteNote(String paperId, int noteId) async {
    try {
      await _api.deleteNote(noteId);
      final detail = await _api.getPaper(paperId);
      setState(() => _detailCache[paperId] = detail);
    } catch (_) {}
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 页码指示器 (带动画的 pill)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PageIndicator extends StatelessWidget {
  final int current;
  final int total;
  const _PageIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$current',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: cs.onSecondaryContainer,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            ' / $total',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSecondaryContainer.withOpacity(0.6),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 单篇论文视图
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _PaperView extends StatelessWidget {
  final Paper paper;
  final bool isLoading;
  final bool isAnalyzing;
  final bool isTranslating;
  final Map<String, dynamic>? analysisQueueStatus;
  final Map<String, dynamic>? translationQueueStatus;
  final VoidCallback onAnalyze;
  final VoidCallback onReanalyze;
  final VoidCallback onDeleteAnalysis;
  final VoidCallback onTranslate;
  final VoidCallback onRetranslate;
  final Future<void> Function(String content) onAddNote;
  final Future<void> Function(int noteId) onDeleteNote;

  const _PaperView({
    super.key,
    required this.paper,
    required this.isLoading,
    required this.isAnalyzing,
    required this.isTranslating,
    required this.analysisQueueStatus,
    required this.translationQueueStatus,
    required this.onAnalyze,
    required this.onReanalyze,
    required this.onDeleteAnalysis,
    required this.onTranslate,
    required this.onRetranslate,
    required this.onAddNote,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final horizontalPadding = Responsive.horizontalPadding(context);
    Widget tabScroll(List<Widget> children) {
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          18,
          horizontalPadding,
          40,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
    }

    final abstractWidget =
        paper.abstract.isNotEmpty
            ? _SectionCard(
              icon: Icons.subject_rounded,
              title: 'Abstract',
              color: cs.primary,
              child: SelectableText(
                paper.abstract,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.8,
                  color: cs.onSurface.withOpacity(0.85),
                ),
              ),
            )
            : isLoading
            ? _LoadingCard()
            : _EmptyStateCard(
              icon: Icons.subject_rounded,
              title: '暂无原文摘要',
              subtitle: '可以打开 PDF 原文或等待后端提取章节。',
            );

    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          _HeroSection(paper: paper),
          Material(
            color: cs.surface,
            child: TabBar(
              isScrollable: false,
              labelPadding: EdgeInsets.zero,
              tabs: const [
                Tab(icon: Icon(Icons.article_rounded), text: '原文'),
                Tab(icon: Icon(Icons.image_rounded), text: '插图'),
                Tab(icon: Icon(Icons.translate_rounded), text: '翻译'),
                Tab(icon: Icon(Icons.auto_awesome_rounded), text: '解读'),
                Tab(icon: Icon(Icons.edit_note_rounded), text: '笔记'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                tabScroll([
                  _OriginalLinksBar(paper: paper),
                  const SizedBox(height: 18),
                  abstractWidget,
                ]),
                _FiguresSection(paperId: paper.id),
                tabScroll([
                  _TranslationSection(
                    paper: paper,
                    isTranslating: isTranslating,
                    queueStatus: translationQueueStatus,
                    onTranslate: onTranslate,
                    onRetranslate: onRetranslate,
                  ),
                ]),
                tabScroll([
                  _AnalysisSection(
                    paper: paper,
                    isAnalyzing: isAnalyzing,
                    queueStatus: analysisQueueStatus,
                    onAnalyze: onAnalyze,
                    onReanalyze: onReanalyze,
                    onDeleteAnalysis: onDeleteAnalysis,
                  ),
                  if (paper.tokenCount != null && paper.tokenCount! > 0) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: _MetaChip(
                        icon: Icons.memory_rounded,
                        label:
                            '${paper.llmModel ?? ""} · ${paper.tokenCount} tokens',
                      ),
                    ),
                  ],
                ]),
                tabScroll([
                  _NotesSection(
                    paper: paper,
                    onAddNote: onAddNote,
                    onDeleteNote: onDeleteNote,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Hero: 渐变头部 + 标题 + 作者 + 会议标签
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _HeroSection extends StatelessWidget {
  final Paper paper;
  const _HeroSection({required this.paper});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: cs.surfaceContainerLow),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.horizontalPadding(context),
          8,
          Responsive.horizontalPadding(context),
          isCompact ? 20 : 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 会议 + 状态 chips
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _Chip(
                  label: paper.conference,
                  icon: Icons.school_rounded,
                  color: cs.primary,
                  bgColor: cs.primaryContainer,
                  fgColor: cs.onPrimaryContainer,
                ),
                if (paper.pages.isNotEmpty)
                  _Chip(
                    label: paper.pages,
                    icon: Icons.numbers_rounded,
                    color: cs.tertiary,
                    bgColor: cs.tertiaryContainer,
                    fgColor: cs.onTertiaryContainer,
                  ),
                if (paper.hasAnalysis)
                  _Chip(
                    label: '已解读',
                    icon: Icons.auto_awesome_rounded,
                    color: Colors.amber.shade700,
                    bgColor: Colors.amber.shade50,
                    fgColor: Colors.amber.shade800,
                  ),
                if (paper.isRead)
                  _Chip(
                    label: '已读',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                    bgColor: Colors.green.shade50,
                    fgColor: Colors.green.shade800,
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // 标题
            SelectableText(
              paper.title,
              style: TextStyle(
                fontSize: isCompact ? 19 : 22,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: cs.onSurface,
                letterSpacing: 0,
              ),
            ),

            if (paper.authors.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                paper.authors.join(', '),
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  color: cs.onSurface.withOpacity(0.55),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final Color fgColor;
  const _Chip({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fgColor,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 查看原文 — 横向按钮栏
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _OriginalLinksBar extends StatelessWidget {
  final Paper paper;
  const _OriginalLinksBar({required this.paper});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final links = <_LinkItem>[
      if (paper.pdfUrl.isNotEmpty)
        _LinkItem(
          icon: Icons.picture_as_pdf_rounded,
          label: 'PDF 原文',
          color: Colors.red.shade600,
          url: paper.pdfUrl,
        ),
      if (paper.pageUrl.isNotEmpty)
        _LinkItem(
          icon: Icons.language_rounded,
          label: 'CVF 页面',
          color: cs.primary,
          url: paper.pageUrl,
        ),
      if (paper.arxivUrl.isNotEmpty)
        _LinkItem(
          icon: Icons.link_rounded,
          label: 'arXiv',
          color: Colors.deepOrange,
          url: paper.arxivUrl,
        ),
    ];

    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.open_in_new_rounded, size: 15, color: cs.outline),
            const SizedBox(width: 6),
            Text(
              '查看原文',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.outline,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: links.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (ctx, i) {
              final link = links[i];
              return _LinkButton(link: link);
            },
          ),
        ),
      ],
    );
  }
}

class _LinkItem {
  final IconData icon;
  final String label;
  final Color color;
  final String url;
  const _LinkItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.url,
  });
}

class _LinkButton extends StatelessWidget {
  final _LinkItem link;
  const _LinkButton({required this.link});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            () => launchUrl(
              Uri.parse(link.url),
              mode: LaunchMode.externalApplication,
            ),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 110,
          decoration: BoxDecoration(
            color: link.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: link.color.withOpacity(0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(link.icon, color: link.color, size: 24),
              const SizedBox(height: 6),
              Text(
                link.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: link.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Section 卡片容器
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final padding = Responsive.cardPadding(context);
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: EdgeInsets.all(padding), child: child),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Container(
      padding: EdgeInsets.all(isCompact ? 32 : 40),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Center(
        child: Column(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text('加载中...', style: TextStyle(fontSize: 13, color: cs.outline)),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: cs.outline),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: cs.outline),
          ),
        ],
      ),
    );
  }
}

class _FiguresSection extends StatefulWidget {
  final String paperId;

  const _FiguresSection({required this.paperId});

  @override
  State<_FiguresSection> createState() => _FiguresSectionState();
}

class _FiguresSectionState extends State<_FiguresSection> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _figures = [];
  List<String> _pages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getFigures(widget.paperId),
        _api.getPageImageUrls(widget.paperId, limit: 6),
      ]);
      if (!mounted) return;
      setState(() {
        _figures = (results[0] as List).cast<Map<String, dynamic>>();
        _pages = (results[1] as List).cast<String>();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final horizontalPadding = Responsive.horizontalPadding(context);
    if (_loading) {
      return Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: _LoadingCard(),
      );
    }
    if (_error != null) {
      return Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: _EmptyStateCard(
          icon: Icons.broken_image_outlined,
          title: '插图提取失败',
          subtitle: _error!,
        ),
      );
    }

    final hasFigures = _figures.isNotEmpty;
    final imageItems =
        hasFigures
            ? _figures
                .map(
                  (fig) => (
                    url: fig['url']?.toString() ?? '',
                    title: fig['label']?.toString() ?? 'Figure',
                    caption: fig['caption']?.toString() ?? '',
                    source: fig['source']?.toString() ?? '',
                  ),
                )
                .where((item) => item.url.isNotEmpty)
                .toList()
            : _pages
                .asMap()
                .entries
                .map(
                  (entry) => (
                    url: entry.value,
                    title: 'Page ${entry.key + 1}',
                    caption: '未检测到明确 Figure caption，显示 PDF 页面快照。',
                    source: 'page_snapshot',
                  ),
                )
                .toList();

    if (imageItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: _EmptyStateCard(
          icon: Icons.image_not_supported_rounded,
          title: '暂无可显示插图',
          subtitle: '后端没有从 PDF 中提取到图片或页面快照。',
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        18,
        horizontalPadding,
        40,
      ),
      itemCount: imageItems.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = imageItems[index];
        final isSnapshot = item.source == 'page_snapshot';
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  _MetaChip(
                    icon:
                        isSnapshot
                            ? Icons.article_outlined
                            : Icons.image_search_rounded,
                    label: isSnapshot ? '页面快照' : 'Figure 提取',
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ZoomableImagePreview(
                url: item.url,
                title: item.title,
                maxHeight: 520,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 520),
                    color: cs.surfaceContainerHigh,
                    child: Image.network(item.url, fit: BoxFit.contain),
                  ),
                ),
              ),
              if (item.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                SelectableText(
                  item.caption,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: cs.outline,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// LLM 解读区域
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _AnalysisSection extends StatelessWidget {
  final Paper paper;
  final bool isAnalyzing;
  final Map<String, dynamic>? queueStatus;
  final VoidCallback onAnalyze;
  final VoidCallback onReanalyze;
  final VoidCallback onDeleteAnalysis;

  const _AnalysisSection({
    required this.paper,
    required this.isAnalyzing,
    required this.queueStatus,
    required this.onAnalyze,
    required this.onReanalyze,
    required this.onDeleteAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);

    // 有解读内容
    if (paper.analysis != null && paper.analysis!.isNotEmpty) {
      return _SectionCard(
        icon: Icons.auto_awesome_rounded,
        title: '深度解读',
        color: Colors.amber.shade700,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QueueStatusCard(kind: '解读', status: queueStatus),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isAnalyzing ? null : onReanalyze,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('重新解读'),
                ),
                OutlinedButton.icon(
                  onPressed: isAnalyzing ? null : onDeleteAnalysis,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('删除解读'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _PaperMarkdownBody(data: paper.analysis!),
          ],
        ),
      );
    }

    // 正在解读
    if (isAnalyzing) {
      return Container(
        padding: EdgeInsets.symmetric(
          vertical: isCompact ? 32 : 40,
          horizontal: 12,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            _QueueStatusCard(kind: '解读', status: queueStatus),
            const SizedBox(height: 16),
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.amber.shade600),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              paper.analysisJobStatus == 'queued' ? '解读排队中...' : '正在智能解读...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '后台任务会持续运行，重新进入仍会显示当前状态',
              style: TextStyle(fontSize: 12, color: cs.outline),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 未解读 — 大按钮引导
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isCompact ? 28 : 32,
        horizontal: 12,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _QueueStatusCard(kind: '解读', status: queueStatus),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 32,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '获取 AI 深度解读',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '智能提取关键章节，节省 60%+ token',
            style: TextStyle(fontSize: 12, color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('生成解读'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 笔记区域
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class _TranslationSection extends StatelessWidget {
  final Paper paper;
  final bool isTranslating;
  final Map<String, dynamic>? queueStatus;
  final VoidCallback onTranslate;
  final VoidCallback onRetranslate;

  const _TranslationSection({
    required this.paper,
    required this.isTranslating,
    required this.queueStatus,
    required this.onTranslate,
    required this.onRetranslate,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final translation = paper.translation?.trim() ?? '';

    if (translation.isNotEmpty) {
      return _SectionCard(
        icon: Icons.translate_rounded,
        title: '全文翻译',
        color: cs.tertiary,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _QueueStatusCard(kind: '翻译', status: queueStatus),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isTranslating ? null : onRetranslate,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('重新翻译'),
            ),
            const SizedBox(height: 12),
            if ((paper.translationModel ?? '').isNotEmpty ||
                (paper.translationCreatedAt ?? '').isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if ((paper.translationModel ?? '').isNotEmpty)
                    _MetaChip(
                      icon: Icons.psychology_rounded,
                      label: paper.translationModel!,
                    ),
                  if ((paper.translationCreatedAt ?? '').isNotEmpty)
                    _MetaChip(
                      icon: Icons.schedule_rounded,
                      label: paper.translationCreatedAt!,
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _PaperMarkdownBody(data: translation),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          _QueueStatusCard(kind: '翻译', status: queueStatus),
          const SizedBox(height: 16),
          Icon(Icons.translate_rounded, size: 30, color: cs.tertiary),
          const SizedBox(height: 12),
          Text(
            isTranslating ? '后台翻译中' : '生成全文翻译',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isTranslating ? '可以继续阅读，完成后会自动缓存' : '按章节保留公式、引用和技术术语',
            style: TextStyle(fontSize: 12, color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isTranslating ? null : onTranslate,
            icon:
                isTranslating
                    ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                    : const Icon(Icons.translate_rounded, size: 18),
            label: Text(isTranslating ? '翻译中' : '开始翻译'),
          ),
        ],
      ),
    );
  }
}

class _PaperMarkdownBody extends StatelessWidget {
  final String data;

  const _PaperMarkdownBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return MarkdownBody(
      data: data,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      fitContent: false,
      onTapLink: (_, href, __) {
        final uri = Uri.tryParse(href ?? '');
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      imageBuilder: (uri, title, alt) {
        return _MarkdownImage(uri: uri, title: title, alt: alt);
      },
      styleSheet: MarkdownStyleSheet(
        h1: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          height: 1.6,
        ),
        h2: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          height: 1.7,
        ),
        h3: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: cs.primary,
          height: 1.8,
        ),
        h4: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: cs.tertiary,
          height: 1.8,
        ),
        p: TextStyle(fontSize: 14, height: 1.8, color: cs.onSurface),
        listBullet: TextStyle(fontSize: 14, color: cs.onSurface, height: 1.8),
        a: TextStyle(
          color: cs.primary,
          decoration: TextDecoration.underline,
          decorationColor: cs.primary.withOpacity(0.5),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        blockquoteDecoration: BoxDecoration(
          color: cs.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: cs.primary, width: 3)),
        ),
        code: TextStyle(
          fontSize: 13,
          color: cs.onSurface,
          backgroundColor: cs.surfaceContainerHighest,
          fontFamily: 'monospace',
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        tableHead: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: cs.onSurface,
        ),
        tableBody: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.5),
        tableBorder: TableBorder.all(color: cs.outlineVariant),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 6,
        ),
      ),
    );
  }
}

class _MarkdownImage extends StatelessWidget {
  final Uri uri;
  final String? title;
  final String? alt;

  const _MarkdownImage({required this.uri, this.title, this.alt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rawUrl = uri.toString();
    final imageUrl = ApiService().resolveUrl(rawUrl);

    if (rawUrl.isEmpty) {
      return _MarkdownImagePlaceholder(
        label: alt?.isNotEmpty == true ? alt! : '暂不支持的本地图片',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _ZoomableImagePreview(
              url: imageUrl,
              title: title?.isNotEmpty == true ? title! : alt ?? '图片',
              maxHeight: 360,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 360),
                color: cs.surfaceContainerHigh,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder:
                      (_, __, ___) => _MarkdownImagePlaceholder(
                        label: alt?.isNotEmpty == true ? alt! : '图片加载失败',
                      ),
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if ((title ?? alt ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              title?.isNotEmpty == true ? title! : alt!,
              style: TextStyle(fontSize: 12, color: cs.outline),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoomableImagePreview extends StatelessWidget {
  final String url;
  final String title;
  final double maxHeight;
  final Widget child;

  const _ZoomableImagePreview({
    required this.url,
    required this.title,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openZoomDialog(context),
            child: child,
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: IconButton.filledTonal(
            tooltip: '放大查看',
            icon: const Icon(Icons.zoom_out_map_rounded, size: 18),
            onPressed: () => _openZoomDialog(context),
          ),
        ),
      ],
    );
  }

  void _openZoomDialog(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder:
          (ctx) => Dialog.fullscreen(
            backgroundColor: cs.surface,
            child: SafeArea(
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '关闭',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                    ),
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 6,
                      child: Center(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (_, __, ___) =>
                                  const Text('图片加载失败，无法放大查看'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

class _MarkdownImagePlaceholder extends StatelessWidget {
  final String label;

  const _MarkdownImagePlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 160,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 28, color: cs.outline),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.outline),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
        ],
      ),
    );
  }
}

class _QueueStatusCard extends StatelessWidget {
  final String kind;
  final Map<String, dynamic>? status;

  const _QueueStatusCard({required this.kind, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == null) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final running = status!['running'] ?? 0;
    final queued = status!['queued'] ?? 0;
    final failed = status!['failed'] ?? 0;
    final recentJobs = (status!['recent_jobs'] as List?) ?? const [];
    final visibleJobs =
        recentJobs
            .whereType<Map>()
            .where((job) {
              final s = job['status']?.toString() ?? '';
              return s == 'running' || s == 'queued' || s == 'failed';
            })
            .take(3)
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaChip(icon: Icons.play_circle_outline_rounded, label: '$kind运行 $running'),
              _MetaChip(icon: Icons.schedule_rounded, label: '排队 $queued'),
              _MetaChip(icon: Icons.error_outline_rounded, label: '失败 $failed'),
            ],
          ),
          if (visibleJobs.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final job in visibleJobs)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${_jobStatusText(job['status']?.toString() ?? '')} · ${job['title'] ?? job['paper_id'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _jobStatusText(String status) {
    return switch (status) {
      'running' => '运行中',
      'queued' => '排队中',
      'failed' => '失败',
      'done' => '完成',
      _ => status,
    };
  }
}

class _NotesSection extends StatelessWidget {
  final Paper paper;
  final Future<void> Function(String content) onAddNote;
  final Future<void> Function(int noteId) onDeleteNote;

  const _NotesSection({
    required this.paper,
    required this.onAddNote,
    required this.onDeleteNote,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final notes = paper.notes ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 18, color: cs.secondary),
            const SizedBox(width: 6),
            Text(
              '笔记',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cs.secondary,
                letterSpacing: 0.3,
              ),
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${notes.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondaryContainer,
                  ),
                ),
              ),
            ],
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),

        for (final note in notes) ...[
          _NoteCard(note: note, onDelete: () => onDeleteNote(note.id)),
          const SizedBox(height: 8),
        ],

        _AddNoteButton(onAdd: onAddNote),
      ],
    );
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onDelete;
  const _NoteCard({required this.note, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondaryContainer.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sticky_note_2_rounded, size: 14, color: cs.secondary),
              const SizedBox(width: 6),
              Text(
                note.createdAt.isEmpty ? '' : note.createdAt.substring(0, 16),
                style: TextStyle(
                  fontSize: 11,
                  color: cs.outline,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: onDelete,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: cs.outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            note.content,
            style: TextStyle(fontSize: 14, height: 1.7, color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _AddNoteButton extends StatefulWidget {
  final Future<void> Function(String content) onAdd;
  const _AddNoteButton({required this.onAdd});

  @override
  State<_AddNoteButton> createState() => _AddNoteButtonState();
}

class _AddNoteButtonState extends State<_AddNoteButton>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_expanded) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => setState(() => _expanded = true),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('添加笔记'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: cs.outline.withOpacity(0.2)),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            maxLines: 5,
            minLines: 3,
            autofocus: true,
            style: const TextStyle(fontSize: 14, height: 1.6),
            decoration: InputDecoration(
              hintText: '写下你的想法、关键发现、与自己研究的关联...',
              hintStyle: TextStyle(
                color: cs.outline.withOpacity(0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed:
                    () => setState(() {
                      _expanded = false;
                      _controller.clear();
                    }),
                child: Text('取消', style: TextStyle(color: cs.outline)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed:
                    _saving
                        ? null
                        : () async {
                          if (_controller.text.trim().isEmpty) return;
                          setState(() => _saving = true);
                          await widget.onAdd(_controller.text.trim());
                          _controller.clear();
                          setState(() {
                            _expanded = false;
                            _saving = false;
                          });
                        },
                icon:
                    _saving
                        ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                        : const Icon(Icons.save_rounded, size: 18),
                label: const Text('保存'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
