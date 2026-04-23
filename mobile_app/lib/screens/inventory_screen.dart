import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  bool _loading = true;
  List<InventoryItem> _items = [];
  String _search = '';
  String _cat = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await ApiService.instance.getInventory();
      if (!mounted) return;
      setState(() {
        _items = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast(context, 'Failed: $e', error: true);
    }
  }

  List<InventoryItem> get _filtered {
    final q = _search.toLowerCase();
    return _items.where((i) {
      final matchesText = q.isEmpty ||
          i.name.toLowerCase().contains(q) ||
          i.itemId.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          i.location.toLowerCase().contains(q);
      final matchesCat = _cat == 'ALL' || i.category == _cat;
      return matchesText && matchesCat;
    }).toList();
  }

  List<String> get _categories {
    final s = <String>{};
    for (final i in _items) {
      if (i.category.isNotEmpty) s.add(i.category);
    }
    final l = s.toList()..sort();
    return ['ALL', ...l];
  }

  int get _lowStockCount =>
      _items.where((i) => i.qty <= i.minStock).length;

  num get _totalQty => _items.fold<num>(0, (p, c) => p + c.qty);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory'), actions: [
        IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Stock'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.1,
                    children: [
                      statCard(
                          label: 'Total items',
                          value: _items.length.toString()),
                      statCard(
                          label: 'Low stock',
                          value: _lowStockCount.toString(),
                          color: AppColors.red),
                      statCard(
                          label: 'Categories',
                          value: (_categories.length - 1).toString(),
                          color: AppColors.orange),
                      statCard(
                          label: 'Total qty',
                          value: _totalQty.toString(),
                          color: AppColors.green),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search items',
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _cat,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(c == 'ALL' ? 'All' : c)))
                        .toList(),
                    onChanged: (v) => setState(() => _cat = v ?? 'ALL'),
                  ),
                  const SizedBox(height: 10),
                  ..._filtered.map(_tile),
                ],
              ),
            ),
    );
  }

  Widget _tile(InventoryItem i) {
    final low = i.qty <= i.minStock;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: low
                ? AppColors.red.withOpacity(0.4)
                : const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(i.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (low ? AppColors.red : AppColors.green)
                    .withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${i.qty} ${i.unit}',
                  style: TextStyle(
                      color: low ? AppColors.red : AppColors.green,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            [
              i.itemId,
              if (i.category.isNotEmpty) i.category,
              if (i.location.isNotEmpty) i.location,
            ].join(' · '),
            style: const TextStyle(color: AppColors.sub, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(children: [
            TextButton.icon(
              onPressed: () => _openForm(existing: i),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit'),
            ),
            TextButton.icon(
              onPressed: () => _openTx(i),
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Transaction'),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => _delete(i),
              icon: const Icon(Icons.delete_outline, color: AppColors.red),
            ),
          ]),
        ],
      ),
    );
  }

  Future<void> _delete(InventoryItem i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove ${i.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.deleteInventory(i.itemId);
      if (!mounted) return;
      showToast(context, 'Deleted');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _openForm({InventoryItem? existing}) async {
    final res = await showModalBottomSheet<InventoryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _InventoryForm(existing: existing),
    );
    if (res == null) return;
    final username =
        context.read<AuthService>().user?.displayName ?? 'unknown';
    try {
      if (existing == null) {
        await ApiService.instance.addInventory(res, username);
      } else {
        await ApiService.instance.editInventory(res, username);
      }
      if (!mounted) return;
      showToast(context, existing == null ? 'Added' : 'Updated');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    }
  }

  Future<void> _openTx(InventoryItem i) async {
    final res = await showModalBottomSheet<_TxResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _TransactionForm(item: i),
    );
    if (res == null) return;
    final username =
        context.read<AuthService>().user?.displayName ?? 'unknown';
    try {
      await ApiService.instance.invTransaction(
        itemId: i.itemId,
        itemName: i.name,
        qty: res.qty,
        type: res.type,
        siteName: res.siteName,
        empName: res.empName,
        remarks: res.remarks,
        purpose: res.purpose,
        updatedBy: username,
      );
      if (!mounted) return;
      showToast(context, 'Transaction saved');
      _load();
    } catch (e) {
      if (!mounted) return;
      showToast(context, 'Failed: $e', error: true);
    }
  }
}

class _InventoryForm extends StatefulWidget {
  final InventoryItem? existing;
  const _InventoryForm({this.existing});
  @override
  State<_InventoryForm> createState() => _InventoryFormState();
}

class _InventoryFormState extends State<_InventoryForm> {
  late final _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _cat =
      TextEditingController(text: widget.existing?.category ?? '');
  late final _qty =
      TextEditingController(text: widget.existing?.qty.toString() ?? '0');
  late final _min =
      TextEditingController(text: widget.existing?.minStock.toString() ?? '5');
  late final _unit =
      TextEditingController(text: widget.existing?.unit ?? 'pcs');
  late final _loc =
      TextEditingController(text: widget.existing?.location ?? '');
  late final _desc =
      TextEditingController(text: widget.existing?.description ?? '');
  final List<String> _serials = [];
  final _serialCtrl = TextEditingController();

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _BarcodeScannerPage()),
    );
    if (code != null && code.isNotEmpty) {
      setState(() => _serials.add(code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isEdit ? 'Edit item' : 'Add stock',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Item name')),
            const SizedBox(height: 10),
            TextField(
                controller: _cat,
                decoration: const InputDecoration(labelText: 'Category')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _qty,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantity')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Min stock')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Unit')),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
                controller: _loc,
                decoration: const InputDecoration(labelText: 'Location')),
            const SizedBox(height: 10),
            TextField(
                controller: _desc,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Description')),
            const SizedBox(height: 14),
            const Text('Serial numbers (optional)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                    controller: _serialCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Enter serial')),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () {
                  final v = _serialCtrl.text.trim();
                  if (v.isNotEmpty) {
                    setState(() => _serials.add(v));
                    _serialCtrl.clear();
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                onPressed: _scan,
              ),
            ]),
            if (_serials.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _serials
                    .map((s) => Chip(
                          label: Text(s),
                          onDeleted: () =>
                              setState(() => _serials.remove(s)),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (_name.text.trim().isEmpty ||
                      _cat.text.trim().isEmpty) {
                    showToast(context, 'Name and category required',
                        error: true);
                    return;
                  }
                  final item = InventoryItem(
                    itemId: widget.existing?.itemId ??
                        'INV-${DateTime.now().millisecondsSinceEpoch}',
                    name: _name.text.trim(),
                    category: _cat.text.trim(),
                    qty: num.tryParse(_qty.text) ?? 0,
                    minStock: num.tryParse(_min.text) ?? 0,
                    unit: _unit.text.trim(),
                    location: _loc.text.trim(),
                    description: _desc.text.trim(),
                  );

                  for (final s in _serials) {
                    try {
                      await ApiService.instance.addSerialNumber(
                        serialNo: s,
                        itemId: item.itemId,
                        itemName: item.name,
                      );
                    } catch (_) {}
                  }
                  if (!mounted) return;
                  Navigator.of(context).pop(item);
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionForm extends StatefulWidget {
  final InventoryItem item;
  const _TransactionForm({required this.item});
  @override
  State<_TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<_TransactionForm> {
  String _type = 'Issue';
  final _qty = TextEditingController(text: '1');
  final _site = TextEditingController();
  final _emp = TextEditingController();
  final _remarks = TextEditingController();
  final _purpose = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Transaction · ${widget.item.name}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'Issue', child: Text('Issue')),
                DropdownMenuItem(value: 'Receipt', child: Text('Receipt')),
                DropdownMenuItem(
                    value: 'Adjustment', child: Text('Adjustment')),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 10),
            TextField(
                controller: _qty,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 10),
            TextField(
                controller: _site,
                decoration: const InputDecoration(labelText: 'Site')),
            const SizedBox(height: 10),
            TextField(
                controller: _emp,
                decoration: const InputDecoration(labelText: 'Employee')),
            const SizedBox(height: 10),
            TextField(
                controller: _purpose,
                decoration: const InputDecoration(labelText: 'Purpose')),
            const SizedBox(height: 10),
            TextField(
                controller: _remarks,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Remarks')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final q = num.tryParse(_qty.text) ?? 0;
                  if (q <= 0) {
                    showToast(context, 'Quantity > 0', error: true);
                    return;
                  }
                  Navigator.of(context).pop(_TxResult(
                    type: _type,
                    qty: q,
                    siteName: _site.text.trim(),
                    empName: _emp.text.trim(),
                    remarks: _remarks.text.trim(),
                    purpose: _purpose.text.trim(),
                  ));
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxResult {
  final String type;
  final num qty;
  final String siteName;
  final String empName;
  final String remarks;
  final String purpose;
  _TxResult({
    required this.type,
    required this.qty,
    required this.siteName,
    required this.empName,
    required this.remarks,
    required this.purpose,
  });
}

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();
  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan code')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_handled) return;
          final codes = capture.barcodes;
          if (codes.isEmpty) return;
          final value = codes.first.rawValue ?? '';
          if (value.isEmpty) return;
          _handled = true;
          Navigator.of(context).pop(value);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
