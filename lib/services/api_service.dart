import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class ApiService {
  static const String defaultServerUrl = 'https://paper-api.zundamon.bond';

  late Dio _dio;
  String _baseUrl = defaultServerUrl;

  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 480), // LLM 解读/全文翻译可能很慢
      ),
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('server_url') ?? defaultServerUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  Future<void> setServerUrl(String url) async {
    _baseUrl = url.replaceAll(RegExp(r'/+$'), '');
    _dio.options.baseUrl = _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  String get serverUrl => _baseUrl;

  String resolveUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    if (trimmed.startsWith('/')) return '$_baseUrl$trimmed';
    return '$_baseUrl/$trimmed';
  }

  Future<Stats> testServerUrl(String url) async {
    final normalized = _normalizeServerUrl(url);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    try {
      final resp = await dio.get('/api/stats');
      return Stats.fromJson(resp.data);
    } on DioException catch (e) {
      throw Exception(_formatDioError(e));
    }
  }

  String _normalizeServerUrl(String url) =>
      url.trim().replaceAll(RegExp(r'/+$'), '');

  String _formatDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout) return '连接超时，请检查服务器地址';
    if (e.type == DioExceptionType.receiveTimeout) return '服务器响应超时';
    if (e.type == DioExceptionType.connectionError) return '无法连接服务器，请确认后端已启动';
    final status = e.response?.statusCode;
    if (status != null) return '服务器返回 HTTP $status';
    return e.message ?? '网络请求失败';
  }

  String _requireLlmText(dynamic data, String field) {
    final value = (data[field] ?? '').toString();
    if (value.startsWith('[LLM ') || value.startsWith('[Unable to ')) {
      throw Exception(value);
    }
    return value;
  }

  // ── 会议 ──

  Future<List<Conference>> getConferences() async {
    final resp = await _dio.get('/api/conferences');
    return (resp.data as List).map((e) => Conference.fromJson(e)).toList();
  }

  Future<int> syncConference(String conference, {bool force = false}) async {
    final resp = await _dio.post(
      '/api/conferences/$conference/sync',
      queryParameters: {'force': force},
    );
    return resp.data['paper_count'] ?? 0;
  }

  // ── 论文列表 ──

  Future<({int total, List<Paper> papers})> getPapers({
    String? conference,
    String? keyword,
    String? status,
    int offset = 0,
    int limit = 20,
  }) async {
    final resp = await _dio.get(
      '/api/papers',
      queryParameters: {
        if (conference != null) 'conference': conference,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (status != null) 'status': status,
        'offset': offset,
        'limit': limit,
      },
    );
    final data = resp.data;
    final papers =
        (data['papers'] as List).map((e) => Paper.fromJson(e)).toList();
    return (total: data['total'] as int, papers: papers);
  }

  // ── 单篇详情 ──

  Future<Paper> getPaper(String paperId) async {
    final resp = await _dio.get('/api/papers/$paperId');
    return Paper.fromJson(resp.data);
  }

  // ── 解读 ──

  Future<String> analyzePaper(String paperId, {bool force = false}) async {
    final resp = await _dio.post(
      '/api/papers/$paperId/analyze',
      queryParameters: {'background': false, 'force': force},
    );
    return _requireLlmText(resp.data, 'analysis');
  }

  Future<Map<String, dynamic>> queueAnalysis(
    String paperId, {
    bool force = false,
  }) async {
    final resp = await _dio.post(
      '/api/papers/$paperId/analyze',
      queryParameters: {'background': true, 'force': force},
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getAnalysisStatus(String paperId) async {
    final resp = await _dio.get('/api/papers/$paperId/analyze/status');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getAnalysisQueueStatus() async {
    final resp = await _dio.get('/api/analyses/status');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<void> deleteAnalysis(String paperId) async {
    await _dio.delete('/api/papers/$paperId/analyze');
  }

  Future<String> translatePaper(String paperId) async {
    final resp = await _dio.post(
      '/api/papers/$paperId/translate',
      queryParameters: {'background': false},
    );
    return _requireLlmText(resp.data, 'translation');
  }

  Future<Map<String, dynamic>> queueTranslation(
    String paperId, {
    bool force = false,
  }) async {
    final resp = await _dio.post(
      '/api/papers/$paperId/translate',
      queryParameters: {'background': true, 'force': force},
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getTranslationStatus(String paperId) async {
    final resp = await _dio.get('/api/papers/$paperId/translate/status');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getTranslationQueueStatus() async {
    final resp = await _dio.get('/api/translations/status');
    return (resp.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, String>> getSections(String paperId) async {
    final resp = await _dio.get('/api/papers/$paperId/sections');
    return (resp.data['sections'] as Map?)?.cast<String, String>() ?? {};
  }

  Future<List<String>> getPageImageUrls(String paperId, {int limit = 8}) async {
    final resp = await _dio.get(
      '/api/papers/$paperId/page-images',
      queryParameters: {'limit': limit},
    );
    final images = (resp.data['images'] as List?) ?? [];
    return images
        .map((e) => (e as Map)['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .map(resolveUrl)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getFigures(
    String paperId, {
    int limit = 16,
  }) async {
    final resp = await _dio.get(
      '/api/papers/$paperId/figures',
      queryParameters: {'limit': limit},
    );
    final figures = (resp.data['figures'] as List?) ?? [];
    return figures.map((e) {
      final item = (e as Map).cast<String, dynamic>();
      final url = item['url']?.toString() ?? '';
      return {...item, 'url': url.isEmpty ? '' : resolveUrl(url)};
    }).toList();
  }

  // ── 阅读状态 ──

  Future<void> updateReadingStatus(
    String paperId,
    String status, {
    double progress = 0.0,
  }) async {
    await _dio.put(
      '/api/papers/$paperId/status',
      data: {'status': status, 'progress': progress},
    );
  }

  // ── 笔记 ──

  Future<Note> createNote(String paperId, String content) async {
    final resp = await _dio.post(
      '/api/papers/$paperId/notes',
      data: {'content': content},
    );
    return Note(id: resp.data['id'], paperId: paperId, content: content);
  }

  Future<void> updateNote(int noteId, String content) async {
    await _dio.put('/api/notes/$noteId', data: {'content': content});
  }

  Future<void> deleteNote(int noteId) async {
    await _dio.delete('/api/notes/$noteId');
  }

  // ── 统计 ──

  Future<Stats> getStats() async {
    final resp = await _dio.get('/api/stats');
    return Stats.fromJson(resp.data);
  }
}
