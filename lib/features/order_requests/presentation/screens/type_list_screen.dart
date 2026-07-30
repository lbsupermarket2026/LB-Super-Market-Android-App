import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_spacing.dart';

/// Common supermarket units — kept as a fixed list rather than letting
/// admin configure it, since this is a small, stable set that rarely
/// needs to change.
const List<String> kListUnits = ['kg', 'g', 'L', 'ml', 'pieces', 'dozen', 'packet', 'box'];

/// Returns a List<String> of "name - qty unit" lines via Navigator.pop
/// when the user taps Done, or null if they back out without any items.
class TypeListScreen extends StatefulWidget {
  final List<String>? initialLines;
  const TypeListScreen({super.key, this.initialLines});

  @override
  State<TypeListScreen> createState() => _TypeListScreenState();
}

class _RowControllers {
  final name = TextEditingController();
  final qty = TextEditingController();
  String unit = kListUnits.first;
}

class _TypeListScreenState extends State<TypeListScreen> {
  final List<_RowControllers> _rows = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialLines != null && widget.initialLines!.isNotEmpty) {
      for (final line in widget.initialLines!) {
        final row = _RowControllers();
        final parts = line.split(' - ');
        row.name.text = parts.isNotEmpty ? parts[0] : line;

        // Older entries stored qty+unit together as free text (e.g.
        // "1kg") — best-effort split so editing an existing list
        // doesn't just dump everything into the qty box.
        final qtyPart = parts.length > 1 ? parts[1].trim() : '1';
        final match = RegExp(r'^([\d.]+)\s*([a-zA-Z]*)$').firstMatch(qtyPart);
        if (match != null) {
          row.qty.text = match.group(1) ?? qtyPart;
          final parsedUnit = match.group(2)?.trim() ?? '';
          if (parsedUnit.isNotEmpty) {
            final found = kListUnits.firstWhere(
              (u) => u.toLowerCase() == parsedUnit.toLowerCase(),
              orElse: () => kListUnits.first,
            );
            row.unit = found;
          }
        } else {
          row.qty.text = qtyPart;
        }
        _rows.add(row);
      }
    } else {
      _rows.add(_RowControllers());
    }
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.name.dispose();
      r.qty.dispose();
    }
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_RowControllers()));

  void _removeRow(int index) {
    setState(() {
      _rows[index].name.dispose();
      _rows[index].qty.dispose();
      _rows.removeAt(index);
    });
  }

  void _done() {
    final lines = _rows
        .where((r) => r.name.text.trim().isNotEmpty)
        .map((r) => '${r.name.text.trim()} - ${r.qty.text.trim().isEmpty ? '1' : r.qty.text.trim()} ${r.unit}')
        .toList();
    Navigator.pop(context, lines);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Type My List')),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _rows.length + 1,
        itemBuilder: (context, index) {
          if (index == _rows.length) {
            return Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                label: const Text('Add Item'),
              ),
            );
          }
          final row = _rows[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: row.name,
                    decoration: InputDecoration(labelText: 'Item ${index + 1}', hintText: 'e.g. Rice'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: row.qty,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))],
                    decoration: const InputDecoration(labelText: 'Qty', hintText: 'e.g. 1'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: row.unit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Unit'),
                    items: kListUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => row.unit = v ?? row.unit),
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(icon: const Icon(Icons.close), onPressed: () => _removeRow(index)),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(AppSpacing.md),
        child: ElevatedButton(onPressed: _done, child: const Text('Done')),
      ),
    );
  }
}