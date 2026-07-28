import 'package:flutter/material.dart';

import 'project_form_store.dart';

class Role5ProjectFormSubmitPage extends StatefulWidget {
  const Role5ProjectFormSubmitPage({required this.form, super.key});

  final ProjectForm form;

  @override
  State<Role5ProjectFormSubmitPage> createState() =>
      _Role5ProjectFormSubmitPageState();
}

class _Role5ProjectFormSubmitPageState
    extends State<Role5ProjectFormSubmitPage> {
  final Map<int, dynamic> _answers = <int, dynamic>{};
  bool _isSubmitting = false;

  Future<void> _pickDate(int index) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDate: now,
    );
    if (picked == null) return;
    setState(() => _answers[index] = picked.toIso8601String().split('T').first);
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() => _answers[index] = picked.format(context));
  }

  Future<void> _pickDateTime(int index) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      initialDate: now,
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (pickedTime == null) return;
    setState(() {
      _answers[index] =
          '${pickedDate.toIso8601String().split('T').first} ${pickedTime.format(context)}';
    });
  }

  bool _isMissingRequired(ProjectFormQuestion q, dynamic value) {
    if (!q.required) return false;
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is List) return value.isEmpty;
    return false;
  }

  Future<void> _submit() async {
    for (int i = 0; i < widget.form.questions.length; i++) {
      final q = widget.form.questions[i];
      if (_isMissingRequired(q, _answers[i])) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill required question: ${q.title}')),
        );
        return;
      }
    }

    final payload = <String, dynamic>{};
    for (int i = 0; i < widget.form.questions.length; i++) {
      final q = widget.form.questions[i];
      final value = _answers[i];
      payload['Q${i + 1}: ${q.title}'] = value ?? '';
    }

    setState(() => _isSubmitting = true);
    try {
      await ProjectFormStore.submitResponse(
        formId: widget.form.id!,
        formTitle: widget.form.title,
        answers: payload,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
    }
  }

  Widget _buildField(int index, ProjectFormQuestion q) {
    final value = _answers[index];
    switch (q.type) {
      case ProjectQuestionType.shortAnswer:
      case ProjectQuestionType.autocompleteInput:
      case ProjectQuestionType.signatureInput:
      case ProjectQuestionType.fileUpload:
      case ProjectQuestionType.locationPicker:
        return TextFormField(
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.paragraph:
      case ProjectQuestionType.richTextInput:
        return TextFormField(
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          minLines: 3,
          maxLines: 5,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.passwordInput:
        return TextFormField(
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          obscureText: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.numberInput:
      case ProjectQuestionType.slider:
      case ProjectQuestionType.linearScale:
        final start = (value is num) ? value.toDouble() : 5.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Slider(
              value: start.clamp(0, 10),
              min: 0,
              max: 10,
              divisions: 10,
              label: start.round().toString(),
              onChanged: (v) => setState(() => _answers[index] = v.round()),
            ),
            Text('Selected: ${(value ?? 5).toString()}'),
          ],
        );
      case ProjectQuestionType.emailInput:
        return TextFormField(
          keyboardType: TextInputType.emailAddress,
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.phoneNumberInput:
        return TextFormField(
          keyboardType: TextInputType.phone,
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '+254...',
          ),
        );
      case ProjectQuestionType.urlInput:
        return TextFormField(
          keyboardType: TextInputType.url,
          initialValue: (value ?? '').toString(),
          onChanged: (v) => _answers[index] = v,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.multipleChoice:
      case ProjectQuestionType.ratingScale:
      case ProjectQuestionType.imageChoice:
      case ProjectQuestionType.matrixGrid:
        final options = q.options.isEmpty ? <String>['Option 1'] : q.options;
        return Column(
          children:
              options
                  .map(
                    (o) => RadioListTile<String>(
                      value: o,
                      groupValue: value?.toString(),
                      onChanged:
                          (v) => setState(() => _answers[index] = v ?? ''),
                      title: Text(o),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
        );
      case ProjectQuestionType.checkboxes:
        final options = q.options.isEmpty ? <String>['Option 1'] : q.options;
        final selected = (value is List ? value.cast<String>() : <String>[]);
        return Column(
          children:
              options
                  .map(
                    (o) => CheckboxListTile(
                      value: selected.contains(o),
                      onChanged: (checked) {
                        final next = List<String>.from(selected);
                        if (checked == true) {
                          if (!next.contains(o)) next.add(o);
                        } else {
                          next.remove(o);
                        }
                        setState(() => _answers[index] = next);
                      },
                      title: Text(o),
                      contentPadding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
        );
      case ProjectQuestionType.dropdown:
        final options = q.options.isEmpty ? <String>['Option 1'] : q.options;
        return DropdownButtonFormField<String>(
          value: options.contains(value) ? value.toString() : null,
          items:
              options
                  .map(
                    (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
                  )
                  .toList(),
          onChanged: (v) => setState(() => _answers[index] = v ?? ''),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        );
      case ProjectQuestionType.toggleSwitch:
        return SwitchListTile(
          value: value == true,
          onChanged: (v) => setState(() => _answers[index] = v),
          title: const Text('Yes / No'),
          contentPadding: EdgeInsets.zero,
        );
      case ProjectQuestionType.datePicker:
        return OutlinedButton.icon(
          onPressed: () => _pickDate(index),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text(value?.toString() ?? 'Select date'),
        );
      case ProjectQuestionType.timePicker:
        return OutlinedButton.icon(
          onPressed: () => _pickTime(index),
          icon: const Icon(Icons.schedule_outlined),
          label: Text(value?.toString() ?? 'Select time'),
        );
      case ProjectQuestionType.dateTimePicker:
        return OutlinedButton.icon(
          onPressed: () => _pickDateTime(index),
          icon: const Icon(Icons.event_outlined),
          label: Text(value?.toString() ?? 'Select date & time'),
        );
      case ProjectQuestionType.sectionBreak:
        return const Divider(thickness: 1.2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 700;
    return Scaffold(
      appBar: AppBar(title: Text(widget.form.title)),
      body: ListView.builder(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        itemCount: widget.form.questions.length + 1,
        itemBuilder: (context, index) {
          if (index == widget.form.questions.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 20),
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: Text(
                  _isSubmitting ? 'Submitting...' : 'Submit Response',
                ),
              ),
            );
          }
          final q = widget.form.questions[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${q.title}${q.required ? ' *' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  _buildField(index, q),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
