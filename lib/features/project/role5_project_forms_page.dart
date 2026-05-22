import 'package:flutter/material.dart';

import 'project_form_store.dart';

class Role5ProjectFormsPage extends StatefulWidget {
  const Role5ProjectFormsPage({super.key});

  @override
  State<Role5ProjectFormsPage> createState() => _Role5ProjectFormsPageState();
}

class _Role5ProjectFormsPageState extends State<Role5ProjectFormsPage> {
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
            future: ProjectFormStore.fetchPublishedForms(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('Failed to load forms: ${snapshot.error}'),
                  ),
                );
              }
              final forms = snapshot.data ?? <ProjectForm>[];
              if (forms.isEmpty) {
                return const Center(child: Text('No published project forms yet.'));
              }
              return ListView.separated(
                padding: EdgeInsets.all(isSmall ? 12 : 16),
                itemCount: forms.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final form = forms[index];
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
                              alignment: isSmall
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: form.id == null
                                    ? null
                                    : () =>
                                        _openSubmitResponseSheet(context, form),
                                icon: const Icon(Icons.send_outlined),
                                label: const Text('Submit Response'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openSubmitResponseSheet(BuildContext context, ProjectForm form) async {
    final controllers = <int, TextEditingController>{};
    for (int i = 0; i < form.questions.length; i++) {
      controllers[i] = TextEditingController();
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Submit: ${form.title}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 320,
                      child: ListView(
                        children: List.generate(form.questions.length, (index) {
                          final q = form.questions[index];
                          final controller = controllers[index]!;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: TextField(
                              controller: controller,
                              minLines:
                                  q.type == ProjectQuestionType.paragraph ? 2 : 1,
                              maxLines:
                                  q.type == ProjectQuestionType.paragraph ? 4 : 1,
                              decoration: InputDecoration(
                                labelText:
                                    q.required ? '${q.title} *' : q.title,
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const Text(
                      'You can submit multiple responses for the same form.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final answers = <String, dynamic>{};
                                for (int i = 0; i < form.questions.length; i++) {
                                  final q = form.questions[i];
                                  final value = controllers[i]!.text.trim();
                                  if (q.required && value.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Please fill required question: ${q.title}',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  answers['Q${i + 1}: ${q.title}'] = value;
                                }
                                setSheetState(() => isSubmitting = true);
                                try {
                                  await ProjectFormStore.submitResponse(
                                    formId: form.id!,
                                    formTitle: form.title,
                                    answers: answers,
                                  );
                                  if (!context.mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Response submitted.'),
                                    ),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  setSheetState(() => isSubmitting = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Submit failed: $e. If this persists, ask admin to run latest project SQL migration.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: Text(isSubmitting ? 'Submitting...' : 'Submit'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    for (final c in controllers.values) {
      c.dispose();
    }
  }
}
