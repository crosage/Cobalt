import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';
import 'paper_reader_page.dart';

class TaskCenterPage extends StatefulWidget {
  const TaskCenterPage({super.key});

  @override
  State<TaskCenterPage> createState() => _TaskCenterPageState();
}

class _TaskCenterPageState extends State<TaskCenterPage> {
  final _api = ApiService();
  bool _loading = true;
  String? _error;
  List<LlmJob> _jobs = [];
  Map<String, dynamic>? _raw;

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
      final result = await _api.getLlmJobs();
      if (!mounted) return;
      setState(() {
        _jobs = result.jobs;
        _raw = result.raw;
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

  Future<void> _retry(LlmJob job) async {
    await _api.retryLlmJob(job.jobType, job.paperId);
    await _load();
  }

  Future<void> _delete(LlmJob job) async {
    await _api.deleteLlmJob(job.jobType, job.paperId);
    await _load();
  }

  Future<void> _openJob(LlmJob job) async {
    final paper = await _api.getPaper(job.paperId);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaperReaderPage(papers: [paper], initialIndex: 0),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final padding = Responsive.horizontalPadding(context);
    final analysis = (_raw?['analysis'] as Map?)?.cast<String, dynamic>();
    final translation = (_raw?['translation'] as Map?)?.cast<String, dynamic>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('任务中心'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(padding, 12, padding, 96),
          children: [
            Row(
              children: [
                Expanded(
                  child: _TaskSummaryCard(
                    icon: Icons.auto_awesome_rounded,
                    label: '解读',
                    status: analysis,
                    color: Colors.amber.shade700,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TaskSummaryCard(
                    icon: Icons.translate_rounded,
                    label: '翻译',
                    status: translation,
                    color: cs.tertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _TaskEmptyState(
                icon: Icons.error_outline_rounded,
                title: '任务加载失败',
                subtitle: _error!,
                action: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              )
            else if (_jobs.isEmpty)
              const _TaskEmptyState(
                icon: Icons.task_alt_rounded,
                title: '暂无后台任务',
                subtitle: '排队、运行和失败的解读/翻译会显示在这里。',
              )
            else
              ..._jobs.map(
                (job) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(
                    job: job,
                    onTap: () => _openJob(job),
                    onRetry: job.isFailed ? () => _retry(job) : null,
                    onDelete: () => _delete(job),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskSummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Map<String, dynamic>? status;
  final Color color;

  const _TaskSummaryCard({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$running 运行 / $queued 排队 / $failed 失败',
            style: TextStyle(fontSize: 11, color: cs.outline),
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

class _TaskCard extends StatelessWidget {
  final LlmJob job;
  final VoidCallback onTap;
  final VoidCallback? onRetry;
  final VoidCallback onDelete;

  const _TaskCard({
    required this.job,
    required this.onTap,
    required this.onRetry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color =
        job.jobType == 'translation' ? cs.tertiary : Colors.amber.shade700;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerLowest,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    job.jobType == 'translation'
                        ? Icons.translate_rounded
                        : Icons.auto_awesome_rounded,
                    size: 18,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(job: job),
                  if (job.queuePosition != null) ...[
                    const SizedBox(width: 6),
                    _TinyPill(label: '#${job.queuePosition}'),
                  ],
                  const Spacer(),
                  if (onRetry != null)
                    IconButton(
                      tooltip: '重试',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      onPressed: onRetry,
                    ),
                  IconButton(
                    tooltip: '删除任务',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    onPressed: onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                job.title.isNotEmpty ? job.title : job.paperId,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [job.conference, job.updatedAt]
                    .where((v) => v.trim().isNotEmpty)
                    .join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.outline),
              ),
              if (job.error.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  job.error,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.4, color: cs.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final LlmJob job;

  const _StatusPill({required this.job});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = switch (job.status) {
      'running' => cs.primary,
      'queued' => Colors.orange.shade700,
      'failed' => cs.error,
      _ => cs.outline,
    };
    return _TinyPill(label: '${job.kindLabel} ${_statusText(job.status)}', color: color);
  }

  String _statusText(String status) {
    return switch (status) {
      'running' => '运行中',
      'queued' => '排队中',
      'failed' => '失败',
      'done' => '完成',
      'cached' => '已缓存',
      _ => status,
    };
  }
}

class _TinyPill extends StatelessWidget {
  final String label;
  final Color? color;

  const _TinyPill({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c),
      ),
    );
  }
}

class _TaskEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const _TaskEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(icon, size: 42, color: cs.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          if (action != null) ...[
            const SizedBox(height: 14),
            action!,
          ],
        ],
      ),
    );
  }
}
