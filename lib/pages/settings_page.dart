import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/responsive.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _api = ApiService();
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _api.serverUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _testResult = '请先填写服务器地址';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });
    try {
      final stats = await _api.testServerUrl(url);
      await _api.setServerUrl(url);
      setState(() {
        _testResult = '连接成功 · ${stats.totalPapers} 篇论文';
        _testSuccess = true;
      });
    } catch (e) {
      setState(() {
        _testResult = '连接失败: $e';
        _testSuccess = false;
      });
    }
    setState(() => _testing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Scaffold(
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
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
                      cs.surfaceContainerHighest.withOpacity(0.3),
                      cs.surface,
                    ],
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Icon(Icons.settings_rounded, color: cs.outline, size: 22),
                const SizedBox(width: 10),
                Text(
                  '设置',
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
            padding: EdgeInsets.all(Responsive.horizontalPadding(context)),
            sliver: SliverList.list(
              children: [
                // ── 服务器地址 ──
                _SectionLabel(icon: Icons.dns_rounded, label: '服务器'),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(Responsive.cardPadding(context)),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _urlController,
                        decoration: InputDecoration(
                          hintText: ApiService.defaultServerUrl,
                          hintStyle: TextStyle(
                            color: cs.outline.withOpacity(0.4),
                          ),
                          prefixIcon: Icon(
                            Icons.link_rounded,
                            color: cs.primary,
                          ),
                          fillColor: cs.surfaceContainerHighest.withOpacity(
                            0.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _testing ? null : _testConnection,
                          icon:
                              _testing
                                  ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.onPrimary,
                                    ),
                                  )
                                  : const Icon(
                                    Icons.wifi_find_rounded,
                                    size: 20,
                                  ),
                          label: const Text('测试连接'),
                        ),
                      ),
                      if (_testResult != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _testSuccess == true
                                    ? Colors.green.withOpacity(0.08)
                                    : Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _testSuccess == true
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _testSuccess == true
                                    ? Icons.check_circle_rounded
                                    : Icons.error_rounded,
                                size: 18,
                                color:
                                    _testSuccess == true
                                        ? Colors.green.shade600
                                        : Colors.red.shade600,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _testResult!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        _testSuccess == true
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── 使用说明 ──
                _SectionLabel(icon: Icons.help_outline_rounded, label: '使用说明'),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(Responsive.cardPadding(context)),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _StepRow(
                        num: '1',
                        title: '启动后端服务',
                        code: 'python server.py',
                        icon: Icons.terminal_rounded,
                        color: cs.primary,
                      ),
                      _StepRow(
                        num: '2',
                        title: '配置服务器地址',
                        code: ApiService.defaultServerUrl,
                        icon: Icons.link_rounded,
                        color: cs.tertiary,
                      ),
                      _StepRow(
                        num: '3',
                        title: '同步会议论文',
                        code: '论文页面 → ☁ 同步',
                        icon: Icons.cloud_sync_rounded,
                        color: Colors.blue,
                      ),
                      _StepRow(
                        num: '4',
                        title: '左右滑动阅读',
                        code: '点击论文 → 进入阅读',
                        icon: Icons.swipe_rounded,
                        color: Colors.orange,
                      ),
                      _StepRow(
                        num: '5',
                        title: 'AI 解读 (可选)',
                        code: 'export LLM_API_KEY=...',
                        icon: Icons.auto_awesome_rounded,
                        color: Colors.amber.shade700,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── 关于 ──
                _SectionLabel(icon: Icons.info_outline_rounded, label: '关于'),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(Responsive.cardPadding(context)),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        cs.primaryContainer.withOpacity(0.15),
                        cs.tertiaryContainer.withOpacity(0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.auto_stories_rounded,
                              color: cs.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paper Reader',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onSurface,
                                  ),
                                ),
                                Text(
                                  'v1.0',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: cs.outline,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '会议论文精读工具',
                        style: TextStyle(fontSize: 14, color: cs.onSurface),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in [
                            'WACV',
                            'CVPR',
                            'ICCV',
                            'ECCV',
                            'NeurIPS',
                            'ICML',
                          ])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: cs.secondaryContainer.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSecondaryContainer,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: cs.outline),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: cs.outline,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final String num;
  final String title;
  final String code;
  final IconData icon;
  final Color color;
  final bool isLast;

  const _StepRow({
    required this.num,
    required this.title,
    required this.code,
    required this.icon,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = Responsive.isCompact(context);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: isCompact ? 30 : 32,
            height: isCompact ? 30 : 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Icon(icon, size: 16, color: color)),
          ),
          SizedBox(width: isCompact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: cs.outline,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
