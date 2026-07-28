import 'package:flutter/material.dart';

import 'project_form_store.dart';
import 'role5_project_form_submit_page.dart';

class Role5ProjectFormsPage extends StatefulWidget {
  const Role5ProjectFormsPage({super.key});

  @override
  State<Role5ProjectFormsPage> createState() => _Role5ProjectFormsPageState();
}

class _Role5ProjectFormsPageState extends State<Role5ProjectFormsPage> {
  late Future<List<ProjectForm>> _formsFuture;
  late Future<Map<String, List<ProjectFormResponse>>> _myResponsesByFormFuture;

  @override
  void initState() {
    super.initState();
    _formsFuture = ProjectFormStore.fetchPublishedForms();
    _myResponsesByFormFuture = _loadMyResponsesByForm();
  }

  void _reloadData() {
    setState(() {
      _formsFuture = ProjectFormStore.fetchPublishedForms();
      _myResponsesByFormFuture = _loadMyResponsesByForm();
    });
  }

  Future<Map<String, List<ProjectFormResponse>>>
  _loadMyResponsesByForm() async {
    final rows = await ProjectFormStore.fetchMyResponses();
    final grouped = <String, List<ProjectFormResponse>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.formId, () => <ProjectFormResponse>[]).add(row);
    }
    return grouped;
  }

  String _typeLabel(ProjectQuestionType type) {
    switch (type) {
      case ProjectQuestionType.shortAnswer:
        return 'Short answer';
      case ProjectQuestionType.paragraph:
        return 'Paragraph';
      case ProjectQuestionType.multipleChoice:
        return 'Multiple choice';
      case ProjectQuestionType.checkboxes:
        return 'Checkboxes';
      case ProjectQuestionType.dropdown:
        return 'Dropdown';
      case ProjectQuestionType.fileUpload:
        return 'File Upload';
      case ProjectQuestionType.datePicker:
        return 'Date Picker';
      case ProjectQuestionType.timePicker:
        return 'Time Picker';
      case ProjectQuestionType.dateTimePicker:
        return 'Date & Time Picker';
      case ProjectQuestionType.numberInput:
        return 'Number Input';
      case ProjectQuestionType.emailInput:
        return 'Email Input';
      case ProjectQuestionType.phoneNumberInput:
        return 'Phone Number Input';
      case ProjectQuestionType.urlInput:
        return 'URL Input';
      case ProjectQuestionType.ratingScale:
        return 'Rating Scale';
      case ProjectQuestionType.slider:
        return 'Slider';
      case ProjectQuestionType.toggleSwitch:
        return 'Toggle Switch';
      case ProjectQuestionType.linearScale:
        return 'Linear Scale';
      case ProjectQuestionType.matrixGrid:
        return 'Matrix/Grid Question';
      case ProjectQuestionType.sectionBreak:
        return 'Section Break / Divider';
      case ProjectQuestionType.imageChoice:
        return 'Image Choice';
      case ProjectQuestionType.signatureInput:
        return 'Signature Input';
      case ProjectQuestionType.locationPicker:
        return 'Location Picker';
      case ProjectQuestionType.autocompleteInput:
        return 'Autocomplete Input';
      case ProjectQuestionType.passwordInput:
        return 'Password Input';
      case ProjectQuestionType.richTextInput:
        return 'Rich Text Input';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 700;
    final maxContentWidth = screenWidth > 1200 ? 1080.0 : 940.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Project Forms')),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: FutureBuilder<List<ProjectForm>>(
            future: _formsFuture,
            builder: (context, formSnapshot) {
              if (formSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (formSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load forms: ${formSnapshot.error}'),
                  ),
                );
              }
              final forms = formSnapshot.data ?? <ProjectForm>[];
              if (forms.isEmpty) {
                return const Center(
                  child: Text('No published project forms yet.'),
                );
              }

              return FutureBuilder<Map<String, List<ProjectFormResponse>>>(
                future: _myResponsesByFormFuture,
                builder: (context, responseSnapshot) {
                  if (responseSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final grouped =
                      responseSnapshot.data ??
                      const <String, List<ProjectFormResponse>>{};

                  return ListView.separated(
                    padding: EdgeInsets.all(isSmall ? 12 : 16),
                    itemCount: forms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final form = forms[index];
                      final myRows =
                          form.id == null
                              ? const <ProjectFormResponse>[]
                              : (grouped[form.id!] ??
                                  const <ProjectFormResponse>[]);

                      return Card(
                        child: Padding(
                          padding: EdgeInsets.all(isSmall ? 12 : 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                form.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmall ? 15 : 16,
                                ),
                              ),
                              if (form.description.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(form.description),
                              ],
                              const SizedBox(height: 12),
                              Text(
                                '${form.questions.length} question(s)',
                                style: const TextStyle(
                                  color: Colors.black54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              for (final q in form.questions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Text(
                                    '• ${q.title} (${_typeLabel(q.type)}${q.required ? ', required' : ''})',
                                  ),
                                ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: isSmall ? double.infinity : null,
                                child: Align(
                                  alignment:
                                      isSmall
                                          ? Alignment.centerLeft
                                          : Alignment.centerRight,
                                  child: FilledButton.icon(
                                    onPressed:
                                        form.id == null
                                            ? null
                                            : () async {
                                              final submitted =
                                                  await Navigator.push<bool>(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (_) =>
                                                              Role5ProjectFormSubmitPage(
                                                                form: form,
                                                              ),
                                                    ),
                                                  );
                                              if (submitted == true) {
                                                _reloadData();
                                                if (!context.mounted) return;
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Response submitted.',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                    icon: const Icon(Icons.send_outlined),
                                    label: const Text('Submit Response'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _MySubmissionsSection(submissions: myRows),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MySubmissionsSection extends StatelessWidget {
  const _MySubmissionsSection({required this.submissions});

  final List<ProjectFormResponse> submissions;

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
    if (submissions.isEmpty) {
      return const Text(
        'My Previous Submissions: none yet.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: Text(
        'My Previous Submissions (${submissions.length})',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children:
          submissions.map((r) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submitted: ${_formatDateTime(r.submittedAt)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...r.answers.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value}'),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }
}
