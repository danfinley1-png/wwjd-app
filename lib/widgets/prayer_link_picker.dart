import 'package:flutter/material.dart';

import '../core/catholic_prayers/catholic_prayer_catalog.dart';
import '../core/responsive_layout.dart';
import '../core/user_text_input.dart';

/// Optional picker to link a My Gifts activity to a catalog prayer.
class PrayerLinkPicker extends StatelessWidget {
  const PrayerLinkPicker({
    super.key,
    required this.selectedPrayerId,
    required this.onChanged,
    this.enabled = true,
  });

  final String? selectedPrayerId;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  Future<void> _openSearch(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _PrayerSearchDialog(
        selectedPrayerId: selectedPrayerId,
        onSelected: (id) {
          onChanged(id);
          Navigator.pop(dialogContext);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = selectedPrayerId != null
        ? CatholicPrayerCatalog.byId(selectedPrayerId!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Link a prayer (optional)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.menu_book_outlined,
            color: enabled ? null : Colors.grey,
          ),
          title: Text(
            selected?.displayName ?? 'None selected',
            style: TextStyle(color: enabled ? null : Colors.grey),
          ),
          subtitle: Text(
            selected == null
                ? 'Search the Prayers library by title'
                : 'Opens in the Prayers library when shared or scheduled',
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Remove prayer link',
                  onPressed: enabled ? () => onChanged(null) : null,
                ),
              Icon(
                Icons.chevron_right,
                color: enabled ? null : Colors.grey,
              ),
            ],
          ),
          onTap: enabled ? () => _openSearch(context) : null,
        ),
      ],
    );
  }
}

class _PrayerSearchDialog extends StatefulWidget {
  const _PrayerSearchDialog({
    required this.selectedPrayerId,
    required this.onSelected,
  });

  final String? selectedPrayerId;
  final ValueChanged<String?> onSelected;

  @override
  State<_PrayerSearchDialog> createState() => _PrayerSearchDialogState();
}

class _PrayerSearchDialogState extends State<_PrayerSearchDialog> {
  final _queryController = TextEditingController();
  final _searchFocusNode = FocusNode();
  List<CatholicPrayer> _results = CatholicPrayerCatalog.sortedByTitle;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {
      _results = CatholicPrayerCatalog.search(_queryController.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: responsiveDialogMaxWidth(context),
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Link a prayer',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose from the Prayers library',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  UserTextField(
                    controller: _queryController,
                    focusNode: _searchFocusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search by title',
                      hintText: 'e.g. Angelus, Rosary, Memorare',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('No prayer linked'),
              trailing: widget.selectedPrayerId == null
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () => widget.onSelected(null),
            ),
            const Divider(height: 1),
            Flexible(
              child: _results.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No prayers match "${_queryController.text.trim()}".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final prayer = _results[index];
                        final isSelected = prayer.id == widget.selectedPrayerId;
                        return ListTile(
                          title: Text(prayer.displayName),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.green)
                              : null,
                          onTap: () => widget.onSelected(prayer.id),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
