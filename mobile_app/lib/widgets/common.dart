import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme.dart';

void showToast(BuildContext context, String msg, {bool error = false}) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    content: Text(msg),
    backgroundColor: error ? AppColors.red : AppColors.green,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(12),
    duration: const Duration(milliseconds: 2800),
  ));
}

String fmtDateISO(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String fmtDatePretty(DateTime d) => DateFormat('EEE, d MMM y').format(d);

DateTime? parseISO(String s) {
  try {
    return DateTime.parse(s);
  } catch (_) {
    return null;
  }
}

Widget statCard({
  required String label,
  required String value,
  Color? color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE6EAF0)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color ?? AppColors.primary)),
        ),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.sub, fontSize: 12)),
      ],
    ),
  );
}

Widget sectionHeader(String title, {Widget? trailing}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        if (trailing != null) trailing,
      ],
    ),
  );
}

Widget roundedAvatar(String name, {double size = 38}) {
  final initials = () {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }();
  return Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primary, AppColors.primary2],
      ),
      shape: BoxShape.circle,
    ),
    child: Text(initials,
        style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.36)),
  );
}

Widget statusBadge(String status) {
  final c = AppColors.forStatus(status);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: c.withOpacity(0.4)),
    ),
    child: Text(
      status.isEmpty ? 'Not Updated' : status,
      style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}
