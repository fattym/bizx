import 'package:flutter/material.dart';

import '../project/project_form_store.dart';
import 'utils/csv_download_stub.dart'
    if (dart.library.html) 'utils/csv_download_web.dart'
    if (dart.library.io) 'utils/csv_download_io.dart';

class ProjectFormResponsesPage extends StatefulWidget {
  const ProjectFormResponsesPage({super.key});

  @override
  State<ProjectFormResponsesPage> createState() =>
      _ProjectFormResponsesPageState();
}

class _ProjectFormResponsesPageState extends State<ProjectFormResponsesPage> {
  final TextEditingController _filterController = TextEditingController();
  final int _pageSize = 50;
  final List<ProjectFormResponse> _responses = <ProjectFormResponse>[];
  List<ProjectFormResponse> _currentResponses = <ProjectFormResponse>[];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _applyFilter() {
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _isLoading = true;
      _responses.clear();
      _currentResponses = <ProjectFormResponse>[];
      _page = 0;
      _hasMore = true;
    });
    try {
      final pageRows = await ProjectFormStore.fetchResponsesPage(
        formNameFilter: _filterController.text,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _responses.addAll(pageRows);
        _currentResponses = List<ProjectFormResponse>.from(_responses);
        _hasMore = pageRows.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load responses: $e')));
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _page + 1;
      final pageRows = await ProjectFormStore.fetchResponsesPage(
        formNameFilter: _filterController.text,
        page: nextPage,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _page = nextPage;
        _responses.addAll(pageRows);
        _currentResponses = List<ProjectFormResponse>.from(_responses);
        _hasMore = pageRows.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load more: $e')));
    }
  }

  Future<void> _downloadExcelLikeCsv() async {
    if (_currentResponses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No response data to export.')),
      );
      return;
    }

    final questionColumns = <String>{};
    for (final r in _currentResponses) {
      questionColumns.addAll(r.answers.keys);
    }
    final sortedQuestions = questionColumns.toList()..sort();

    final headers = <String>[
      'Form Name',
      'Respondent ID',
      'Submitted At',
      ...sortedQuestions,
    ];
    final buffer = StringBuffer('${headers.map(_csvEscape).join(',')}\n');

    for (final r in _currentResponses) {
      final row = <String>[
        r.formTitle,
        r.respondentId,
        r.submittedAt.toIso8601String(),
        ...sortedQuestions.map((q) => (r.answers[q] ?? '').toString()),
      ];
      buffer.writeln(row.map(_csvEscape).join(','));
    }

    final filter = _filterController.text.trim();
    final suffix =
        filter.isEmpty
            ? 'all_forms'
            : filter.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final fileName =
        'project_form_responses_${suffix}_${DateTime.now().millisecondsSinceEpoch}.csv';

    try {
      await downloadCsvTemplate(fileName, buffer.toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel export download started: $fileName')),
      );
    } on UnsupportedError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Download is not supported on this device in current mode.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  String _csvEscape(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    var hour = local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;
    final hh = hour.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 700;
    final maxContentWidth = screenWidth > 1200 ? 1100.0 : 980.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Project Form Responses')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                child:
                    isSmall
                        ? Column(
                          children: [
                            TextField(
                              controller: _filterController,
                              decoration: const InputDecoration(
                                labelText: 'Filter by form name',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _applyFilter(),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _applyFilter,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Filter'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _downloadExcelLikeCsv,
                                    icon: const Icon(Icons.download_outlined),
                                    label: const Text('Download Excel'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                        : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _filterController,
                                decoration: const InputDecoration(
                                  labelText: 'Filter by form name',
                                  border: OutlineInputBorder(),
                                ),
                                onSubmitted: (_) => _applyFilter(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _applyFilter,
                              icon: const Icon(Icons.search),
                              label: const Text('Filter'),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _downloadExcelLikeCsv,
                              icon: const Icon(Icons.download_outlined),
                              label: const Text('Download Excel'),
                            ),
                          ],
                        ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _responses.isEmpty
                        ? const Center(
                          child: Text(
                            'No collected data found for this filter.',
                          ),
                        )
                        : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            isSmall ? 12 : 16,
                            0,
                            isSmall ? 12 : 16,
                            isSmall ? 12 : 16,
                          ),
                          itemCount: _responses.length + 1,
                          separatorBuilder:
                              (_, __) => SizedBox(height: isSmall ? 8 : 10),
                          itemBuilder: (context, index) {
                            if (index == _responses.length) {
                              if (!_hasMore) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Center(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _isLoadingMore ? null : _loadMore,
                                    icon:
                                        _isLoadingMore
                                            ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : const Icon(Icons.expand_more),
                                    label: Text(
                                      _isLoadingMore
                                          ? 'Loading...'
                                          : 'Load More',
                                    ),
                                  ),
                                ),
                              );
                            }

                            final r = _responses[index];
                            return Card(
                              child: Padding(
                                padding: EdgeInsets.all(isSmall ? 12 : 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.formTitle,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isSmall ? 15 : 16,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Submitted by: ${r.respondentId}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Submitted at: ${_formatDateTime(r.submittedAt)}',
                                    ),
                                    const Divider(height: 20),
                                    ...r.answers.entries.map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Text('${e.key}: ${e.value}'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
