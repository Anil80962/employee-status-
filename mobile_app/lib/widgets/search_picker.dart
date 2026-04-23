import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-screen searchable picker. Returns the selected label or null.
Future<String?> pickFromList({
  required BuildContext context,
  required String title,
  required List<String> items,
  String? initial,
  String hint = 'Search…',
}) async {
  return Navigator.of(context).push<String>(MaterialPageRoute(
    builder: (_) => _SearchPickerPage(
      title: title,
      items: items,
      initial: initial,
      hint: hint,
    ),
    fullscreenDialog: true,
  ));
}

class _SearchPickerPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? initial;
  final String hint;
  const _SearchPickerPage({
    required this.title,
    required this.items,
    this.initial,
    required this.hint,
  });

  @override
  State<_SearchPickerPage> createState() => _SearchPickerPageState();
}

class _SearchPickerPageState extends State<_SearchPickerPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _q.trim().isEmpty
        ? widget.items
        : widget.items
            .where((e) => e.toLowerCase().contains(_q.toLowerCase()))
            .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.hint,
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No matches'))
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF1F4)),
                    itemBuilder: (_, i) {
                      final label = filtered[i];
                      final selected = label == widget.initial;
                      return ListTile(
                        title: Text(label),
                        trailing: selected
                            ? const Icon(Icons.check,
                                color: AppColors.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(label),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Tap-to-open field that looks like a dropdown but opens a searchable picker.
class SearchPickerField extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String> onSelected;
  final IconData? icon;
  final String? hint;

  const SearchPickerField({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.value,
    this.icon,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final v = await pickFromList(
          context: context,
          title: label,
          items: items,
          initial: value,
          hint: hint ?? 'Search $label…',
        );
        if (v != null) onSelected(v);
      },
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          value ?? '',
          style: TextStyle(
            color: value == null ? AppColors.sub : AppColors.text,
          ),
        ),
      ),
    );
  }
}
