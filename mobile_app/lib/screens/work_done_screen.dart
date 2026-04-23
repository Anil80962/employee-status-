import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Matches the web portal's per-row "Update" action —
/// updates columns J–T via `updateWorkDone`.
class WorkDoneScreen extends StatefulWidget {
  final StatusRecord record;
  const WorkDoneScreen({super.key, required this.record});

  @override
  State<WorkDoneScreen> createState() => _WorkDoneScreenState();
}

class _WorkDoneScreenState extends State<WorkDoneScreen> {
  late final _workDone =
      TextEditingController(text: widget.record.workDone);
  late final _completion = TextEditingController(
      text: widget.record.completionPct.isEmpty
          ? '100'
          : widget.record.completionPct);
  late final _remarks =
      TextEditingController(text: widget.record.workRemarks);
  late final _nextDate =
      TextEditingController(text: widget.record.nextVisitDate);
  late final _instruction =
      TextEditingController(text: widget.record.instructionFrom);
  late final _inspectedBy =
      TextEditingController(text: widget.record.inspectedBy);
  late final _customer =
      TextEditingController(text: widget.record.customerName);
  late final _designation =
      TextEditingController(text: widget.record.designation);
  late final _phone = TextEditingController(text: widget.record.phone);
  late final _email = TextEditingController(text: widget.record.email);
  String _nextVisit = 'No';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nextVisit = widget.record.nextVisitRequired.isEmpty
        ? 'No'
        : widget.record.nextVisitRequired;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateWorkDone(
        empId: widget.record.empId,
        date: widget.record.date,
        workDone: _workDone.text.trim(),
        completionPct: _completion.text.trim(),
        workRemarks: _remarks.text.trim(),
        nextVisitRequired: _nextVisit,
        nextVisitDate: _nextDate.text.trim(),
        instructionFrom: _instruction.text.trim(),
        inspectedBy: _inspectedBy.text.trim(),
        customerName: _customer.text.trim(),
        designation: _designation.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
      );
      if (!mounted) return;
      showToast(context, 'Work done saved');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return Scaffold(
      appBar: AppBar(title: const Text('Update Work Done')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6EAF0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.empName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                    '${r.date} · ${r.siteName.isEmpty ? '—' : r.siteName} · ${r.workType}',
                    style: const TextStyle(
                        color: AppColors.sub, fontSize: 12)),
                if (r.scopeOfWork.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(r.scopeOfWork,
                      style: const TextStyle(fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          sectionHeader('Work completion'),
          TextField(
            controller: _workDone,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Work done',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _completion,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Completion %'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _remarks,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 14),
          sectionHeader('Next visit'),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _nextVisit,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: 'Required'),
                items: const [
                  DropdownMenuItem(value: 'No', child: Text('No')),
                  DropdownMenuItem(value: 'Yes', child: Text('Yes')),
                ],
                onChanged: (v) =>
                    setState(() => _nextVisit = v ?? _nextVisit),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    _nextDate.text = fmtDateISO(picked);
                    setState(() {});
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(_nextDate.text.isEmpty ? '—' : _nextDate.text),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          sectionHeader('Customer (service)'),
          TextField(
            controller: _instruction,
            decoration:
                const InputDecoration(labelText: 'Instruction from'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _inspectedBy,
            decoration: const InputDecoration(labelText: 'Inspected by'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _customer,
            decoration: const InputDecoration(labelText: 'Customer name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _designation,
            decoration: const InputDecoration(labelText: 'Designation'),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
