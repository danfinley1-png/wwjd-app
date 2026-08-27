import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/usage_analytics_service.dart';
import '../../../core/analytics/usage_section.dart';
import '../../../core/app_colors.dart';
import '../../../core/external_link.dart';
import '../../../core/responsive_layout.dart';
import '../../../core/user_text_input.dart';
import '../../../admin/models/organization.dart';
import '../../../admin/providers/admin_providers.dart';
import '../local_worship_providers.dart';
import '../models/location_profile_kind.dart';
import '../models/parish.dart';
import '../models/parish_schedule.dart';
import '../models/worship_preferences.dart';
import '../services/mass_times_links.dart';
import '../services/parish_ranking.dart';
import '../widgets/edit_parish_schedule_dialog.dart';
import '../widgets/member_school_schedule_section.dart';
import '../widgets/parish_schedule_card.dart';

/// Local Catholic worship times — Neighborhood lookup and School chapel template.
class LocalWorshipScreen extends ConsumerStatefulWidget {
  const LocalWorshipScreen({
    super.key,
    this.initialKindId,
    this.initialOrgId,
  });

  static const path = '/near-me';

  final String? initialKindId;
  final String? initialOrgId;

  @override
  ConsumerState<LocalWorshipScreen> createState() => _LocalWorshipScreenState();
}

class _LocalWorshipScreenState extends ConsumerState<LocalWorshipScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, TextEditingController> _addressControllers = {
    for (final kind in LocationProfileKind.active)
      kind.id: TextEditingController(),
  };
  final Map<String, _ChapelFields> _chapelFields = {
    for (final kind in LocationProfileKind.active)
      if (!kind.usesLocationLookup) kind.id: _ChapelFields(),
  };
  final Map<String, NearbySearchResult?> _results = {};
  final Map<String, Parish?> _adoration = {};
  final Map<String, String?> _errors = {};
  final Map<String, bool> _searching = {};
  final Map<String, bool> _findingAdoration = {};
  final Map<String, bool> _adorationLookedUp = {};
  final Map<String, bool> _autoSearchAttempted = {};
  bool _usingLocation = false;
  String? _selectedSchoolOrgId;

  @override
  void initState() {
    super.initState();
    UsageAnalyticsService.instance.trackSectionView(UsageSection.localWorship);
    final kinds = LocationProfileKind.active;
    final initial = kinds.indexWhere((k) => k.id == widget.initialKindId);
    _tabs = TabController(
      length: kinds.length,
      vsync: this,
      initialIndex: initial >= 0 ? initial : 0,
    );
    _tabs.addListener(() {
      if (mounted && !_tabs.indexIsChanging) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _hydrateFields());
  }

  bool get _onSchoolTab {
    final index = _tabs.index;
    final kinds = LocationProfileKind.active;
    if (index < 0 || index >= kinds.length) return false;
    return kinds[index].id == LocationProfileKind.school.id;
  }

  Organization? _selectedSchoolOrg(List<Organization> orgs) {
    if (orgs.isEmpty) return null;
    final preferred = _selectedSchoolOrgId ?? widget.initialOrgId;
    if (preferred != null) {
      for (final org in orgs) {
        if (org.id == preferred) return org;
      }
    }
    return orgs.first;
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in _addressControllers.values) {
      controller.dispose();
    }
    for (final fields in _chapelFields.values) {
      fields.dispose();
    }
    super.dispose();
  }

  void _hydrateFields() {
    final prefs = ref.read(localWorshipPreferencesProvider).valueOrNull;
    if (prefs == null) return;
    for (final kind in LocationProfileKind.active) {
      final profile = prefs.forKind(kind);
      final text = profile.addressText;
      if (text.isNotEmpty && _addressControllers[kind.id]!.text.isEmpty) {
        _addressControllers[kind.id]!.text = text;
      }
      _chapelFields[kind.id]?.hydrate(profile.myParish);
    }
    _refreshSavedLookups(prefs);
  }

  void _refreshSavedLookups(WorshipPreferences prefs) {
    for (final kind in LocationProfileKind.active) {
      if (!kind.usesLocationLookup) continue;
      if (_autoSearchAttempted[kind.id] == true) continue;
      if (_searching[kind.id] == true || _results[kind.id] != null) continue;
      final profile = prefs.forKind(kind);
      if (!profile.hasAddress && !profile.hasCoordinates) continue;
      _autoSearchAttempted[kind.id] = true;
      _search(kind);
    }
  }

  Future<void> _search(LocationProfileKind kind, {bool fromGps = false}) async {
    if (!kind.usesLocationLookup) return;

    final directory = ref.read(parishDirectoryServiceProvider);
    final location = ref.read(deviceLocationServiceProvider);
    final controller = _addressControllers[kind.id]!;
    setState(() {
      _searching[kind.id] = true;
      _errors[kind.id] = null;
      _adoration[kind.id] = null;
      _adorationLookedUp[kind.id] = false;
    });

    try {
      double? lat;
      double? lng;
      var address = controller.text.trim();

      if (fromGps) {
        setState(() => _usingLocation = true);
        final coords = await location.currentPosition();
        lat = coords.latitude;
        lng = coords.longitude;
      }

      final result = await directory.search(
        address: address.isEmpty ? null : address,
        latitude: lat,
        longitude: lng,
      );

      if (fromGps && result.origin.label.isNotEmpty) {
        controller.text = result.origin.label;
        address = result.origin.label;
      } else if (result.origin.label.isNotEmpty && address.isEmpty) {
        controller.text = result.origin.label;
        address = result.origin.label;
      } else if (address.isEmpty) {
        address = '${result.origin.latitude.toStringAsFixed(5)}, '
            '${result.origin.longitude.toStringAsFixed(5)}';
        controller.text = address;
      }

      await ref.read(localWorshipPreferencesProvider.notifier).updateProfile(
        kind,
        (current) => current.copyWith(
          addressText: address,
          latitude: result.origin.latitude,
          longitude: result.origin.longitude,
        ),
      );

      if (!mounted) return;
      setState(() {
        _results[kind.id] = result;
        _searching[kind.id] = false;
        _usingLocation = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _searching[kind.id] = false;
        _usingLocation = false;
        _errors[kind.id] = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _saveTemplateChapel(LocationProfileKind kind) async {
    final fields = _chapelFields[kind.id];
    if (fields == null) return;
    final name = fields.name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter the ${kind.chapelNameLabel.toLowerCase()}.')),
      );
      return;
    }

    final current = ref.read(localWorshipPreferencesProvider).valueOrNull
            ?.forKind(kind) ??
        const LocationProfileState();
    final existing = current.myParish;
    final website = fields.website.text.trim();
    final phone = fields.phone.text.trim();
    final parish = Parish(
      id: existing?.id ?? 'template:${kind.id}',
      name: name,
      address: fields.address.text.trim(),
      phone: phone.isEmpty ? null : phone,
      website: website.isEmpty ? null : website,
      isMyParish: true,
      schedule: existing == null
          ? const ParishSchedule()
          : current.displayParish(existing).schedule,
    );

    await ref.read(localWorshipPreferencesProvider.notifier).updateProfile(
      kind,
      (state) => state.copyWith(
        addressText: _addressControllers[kind.id]!.text.trim(),
        myParish: parish,
        clearCoordinates: true,
      ).withScheduleOverride(parish, parish.schedule),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parish.name} saved as ${kind.chapelBadgeLabel}.')),
    );
  }

  Future<void> _chooseParish(LocationProfileKind kind, Parish parish) async {
    await ref.read(localWorshipPreferencesProvider.notifier).updateProfile(
      kind,
      (current) => current.copyWith(myParish: parish.copyWith(isMyParish: true)),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${parish.name} saved as My Parish.')),
    );
  }

  Future<void> _editSchedule(LocationProfileKind kind, Parish parish) async {
    final current = ref.read(localWorshipPreferencesProvider).valueOrNull
            ?.forKind(kind) ??
        const LocationProfileState();
    final result = await showEditParishScheduleDialog(
      context,
      parish: current.displayParish(parish),
      hasOverride: kind.usesLocationLookup &&
          current.scheduleOverrides.containsKey(parish.preferenceKey),
    );
    if (result == null || !mounted) return;

    await ref.read(localWorshipPreferencesProvider.notifier).updateProfile(
      kind,
      (state) {
        if (result.revert) return state.withoutScheduleOverride(parish);
        return state.withScheduleOverride(parish, result.schedule!);
      },
    );
  }

  Future<void> _findAdoration(LocationProfileKind kind) async {
    if (!kind.usesLocationLookup) return;
    setState(() => _findingAdoration[kind.id] = true);
    try {
      var result = _results[kind.id];
      if (result == null) {
        await _search(kind);
        result = _results[kind.id];
      }
      if (result == null) return;

      var chapel = ParishRanking.closestPerpetualAdoration(result.parishes);
      if (chapel == null) {
        try {
          final more = await ref.read(parishDirectoryServiceProvider).search(
                address: _addressControllers[kind.id]!.text.trim(),
                latitude: result.origin.latitude,
                longitude: result.origin.longitude,
                page: 2,
              );
          chapel = ParishRanking.closestPerpetualAdoration(more.parishes);
        } catch (_) {
          chapel = null;
        }
      }

      if (!mounted) return;
      setState(() {
        _adoration[kind.id] = chapel;
        _findingAdoration[kind.id] = false;
        _adorationLookedUp[kind.id] = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _findingAdoration[kind.id] = false;
        _adorationLookedUp[kind.id] = true;
        _errors[kind.id] = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(localWorshipPreferencesProvider);
    ref.listen(localWorshipPreferencesProvider, (previous, next) {
      final value = next.valueOrNull;
      if (value == null) return;
      _hydrateFields();
    });
    final locationSupported =
        ref.watch(deviceLocationServiceProvider).isSupported;
    final schoolOrgs =
        ref.watch(memberOrganizationsProvider).valueOrNull ?? const [];
    final schoolOrg = _selectedSchoolOrg(schoolOrgs);
    final schoolTitle = _onSchoolTab
        ? (schoolOrg?.name.trim().isNotEmpty == true
            ? schoolOrg!.name.trim()
            : 'My School')
        : 'Local Worship Times';

    return Scaffold(
      appBar: AppBar(
        title: Text(schoolTitle, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final kind in LocationProfileKind.active)
              Tab(text: kind.tabLabel, icon: Icon(kind.icon, size: 18)),
          ],
        ),
      ),
      body: Column(
        children: [
          if (prefsAsync.isLoading)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final kind in LocationProfileKind.active)
                  _ProfileTab(
                    kind: kind,
                    state: prefsAsync.valueOrNull?.forKind(kind) ??
                        const LocationProfileState(),
                    addressController: _addressControllers[kind.id]!,
                    chapelFields: _chapelFields[kind.id],
                    result: _results[kind.id],
                    adoration: _adoration[kind.id],
                    error: _errors[kind.id],
                    searching: _searching[kind.id] == true,
                    findingAdoration: _findingAdoration[kind.id] == true,
                    adorationLookedUp: _adorationLookedUp[kind.id] == true,
                    usingLocation: _usingLocation,
                    locationSupported: locationSupported,
                    schoolOrgId: kind.id == LocationProfileKind.school.id
                        ? (schoolOrg?.id ?? widget.initialOrgId)
                        : null,
                    onSelectSchoolOrg: kind.id == LocationProfileKind.school.id
                        ? (id) => setState(() => _selectedSchoolOrgId = id)
                        : null,
                    onSearch: () => _search(kind),
                    onUseLocation: kind.usesLocationLookup && locationSupported
                        ? () => _search(kind, fromGps: true)
                        : null,
                    onSaveChapel: () => _saveTemplateChapel(kind),
                    onChooseParish: (parish) => _chooseParish(kind, parish),
                    onEditSchedule: (parish) => _editSchedule(kind, parish),
                    onFindAdoration: () => _findAdoration(kind),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChapelFields {
  _ChapelFields();

  final name = TextEditingController();
  final address = TextEditingController();
  final phone = TextEditingController();
  final website = TextEditingController();

  void hydrate(Parish? parish) {
    if (parish == null) return;
    if (name.text.isEmpty) name.text = parish.name;
    if (address.text.isEmpty) address.text = parish.address;
    if (phone.text.isEmpty) phone.text = parish.phone ?? '';
    if (website.text.isEmpty) website.text = parish.website ?? '';
  }

  void dispose() {
    name.dispose();
    address.dispose();
    phone.dispose();
    website.dispose();
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.kind,
    required this.state,
    required this.addressController,
    required this.chapelFields,
    required this.result,
    required this.adoration,
    required this.error,
    required this.searching,
    required this.findingAdoration,
    required this.adorationLookedUp,
    required this.usingLocation,
    required this.locationSupported,
    required this.onSearch,
    required this.onUseLocation,
    required this.onSaveChapel,
    required this.onChooseParish,
    required this.onEditSchedule,
    required this.onFindAdoration,
    this.schoolOrgId,
    this.onSelectSchoolOrg,
  });

  final LocationProfileKind kind;
  final LocationProfileState state;
  final TextEditingController addressController;
  final _ChapelFields? chapelFields;
  final NearbySearchResult? result;
  final Parish? adoration;
  final String? error;
  final bool searching;
  final bool findingAdoration;
  final bool adorationLookedUp;
  final bool usingLocation;
  final bool locationSupported;
  final VoidCallback onSearch;
  final VoidCallback? onUseLocation;
  final VoidCallback onSaveChapel;
  final ValueChanged<Parish> onChooseParish;
  final ValueChanged<Parish> onEditSchedule;
  final VoidCallback onFindAdoration;
  final String? schoolOrgId;
  final ValueChanged<String>? onSelectSchoolOrg;

  @override
  Widget build(BuildContext context) {
    if (!kind.usesLocationLookup) {
      return _buildTemplate(context);
    }
    return _buildLookup(context);
  }

  Widget _buildTemplate(BuildContext context) {
    final padding = responsiveHorizontalPadding(context);
    final fields = chapelFields;
    final chapel = state.myParish == null
        ? null
        : state.displayParish(state.myParish!).copyWith(isMyParish: true);

    return ListView(
      padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, 32),
      children: [
        if (kind.id == LocationProfileKind.school.id) ...[
          MemberSchoolScheduleSection(
            initialOrgId: schoolOrgId,
            onSelectOrg: onSelectSchoolOrg,
          ),
          const SizedBox(height: 20),
        ],
        Text(
          kind.templateIntro,
          style: TextStyle(height: 1.45, color: Colors.grey.shade800),
        ),
        if (kind.id == LocationProfileKind.school.id) ...[
          const SizedBox(height: 28),
          Text(
            'Campus chapel (optional)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save a chapel name and worship times for this device. That template is '
            'separate from the published school schedule above.',
            style: TextStyle(height: 1.45, color: Colors.grey.shade800),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          kind.addressLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        UserTextField(
          controller: addressController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: kind.addressHint,
            prefixIcon: Icon(kind.icon),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        if (fields != null) ...[
          UserTextField(
            controller: fields.name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: kind.chapelNameLabel,
              hintText: 'e.g. St. Thomas Aquinas Chapel',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: fields.address,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: kind.chapelAddressLabel,
              hintText: 'Building, street, or campus location',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: fields.phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          UserTextField(
            controller: fields.website,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Website (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onSaveChapel,
            icon: const Icon(Icons.save_outlined),
            label: Text('Save ${kind.chapelBadgeLabel.toLowerCase()}'),
          ),
        ],
        const SizedBox(height: 24),
        if (chapel != null)
          ParishScheduleCard(
            parish: chapel,
            badgeLabel: kind.chapelBadgeLabel,
            showChooseAction: false,
            showMassTimesLink: false,
            onEditSchedule: () => onEditSchedule(chapel),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Worship times template',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save the chapel first, then fill Mass times, Confession, Adoration, and the other rows. Empty rows stay as “Not listed”.',
                    style: TextStyle(height: 1.45, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLookup(BuildContext context) {
    final padding = responsiveHorizontalPadding(context);
    final featured = ParishRanking.featuredParishes(
      nearby: result?.parishes ?? const [],
      myParish: state.myParish,
    ).map(state.displayParish).toList();
    final pickerParishes =
        (result?.parishes ?? const []).map(state.displayParish).toList();
    final showPicker = pickerParishes.isNotEmpty && !state.hasMyParish;
    final adorationParish =
        adoration == null ? null : state.displayParish(adoration!);

    return ListView(
      padding: EdgeInsets.fromLTRB(padding.left, 20, padding.right, 32),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => launchExternalLink(
              context,
              MassTimesLinks.homeUrl,
            ),
            icon: const Icon(Icons.open_in_new),
            label: const Text(
              'Find times on MassTimes.org',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        Text(
          'MassTimes.org is the official directory of Catholic churches and worship times. '
          'WWJD-DI saves this neighborhood address and My Parish choice; live times come from MassTimes when available.',
          style: TextStyle(height: 1.45, color: Colors.grey.shade800),
        ),
        const SizedBox(height: 20),
        Text(
          kind.addressLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        UserTextField(
          controller: addressController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSearch(),
          decoration: InputDecoration(
            hintText: kind.addressHint,
            prefixIcon: Icon(kind.icon),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: searching ? null : onSearch,
              icon: const Icon(Icons.church_outlined),
              label: const Text('Find nearby parishes'),
            ),
            if (onUseLocation != null)
              OutlinedButton.icon(
                onPressed: searching || usingLocation ? null : onUseLocation,
                icon: const Icon(Icons.my_location),
                label: Text(
                  usingLocation ? 'Finding location…' : 'Use my current location',
                ),
              ),
            TextButton.icon(
              onPressed: () {
                final text = addressController.text.trim();
                final uri = MassTimesLinks.nearbyMap(
                  latitude: state.latitude ?? result?.origin.latitude,
                  longitude: state.longitude ?? result?.origin.longitude,
                  searchQuery: text.isEmpty ? null : text,
                );
                launchExternalLink(context, uri.toString());
              },
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open this area on MassTimes.org'),
            ),
          ],
        ),
        if (!locationSupported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Current location is not available on this device. Enter a street address instead.',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        if (searching) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 3),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!, style: TextStyle(color: Colors.orange.shade900)),
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (showPicker) ...[
          const Text(
            'Choose My Parish',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Select the parish that is home for this neighborhood. '
            'The three next-closest parishes will appear underneath.',
            style: TextStyle(height: 1.45, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          for (final parish in pickerParishes.take(12))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ParishScheduleCard(
                parish: parish,
                onChooseAsMyParish: () => onChooseParish(parish),
                onEditSchedule: () => onEditSchedule(parish),
              ),
            ),
        ],
        if (featured.isNotEmpty && (state.hasMyParish || !showPicker)) ...[
          const Text(
            'My Parish and nearby churches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'My Parish is listed first, followed by the three next-closest parishes.',
            style: TextStyle(height: 1.45, color: Colors.grey.shade800),
          ),
          const SizedBox(height: 12),
          for (final parish in featured)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ParishScheduleCard(
                parish: parish,
                onChooseAsMyParish: parish.isMyParish
                    ? null
                    : () => onChooseParish(parish),
                onEditSchedule: () => onEditSchedule(parish),
              ),
            ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: findingAdoration ? null : onFindAdoration,
          icon: const Icon(Icons.wb_sunny_outlined),
          label: Text(
            findingAdoration
                ? 'Searching for perpetual adoration…'
                : 'Find closest perpetual adoration',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The nearest chapel with perpetual adoration may be farther than the three nearby parishes.',
          style: TextStyle(height: 1.45, color: Colors.grey.shade800),
        ),
        if (adorationParish != null) ...[
          const SizedBox(height: 12),
          ParishScheduleCard(
            parish: adorationParish,
            showChooseAction: false,
            onEditSchedule: () => onEditSchedule(adorationParish),
          ),
        ] else if (adorationLookedUp) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'No perpetual adoration chapel was listed in the nearby MassTimes results.',
                    style: TextStyle(height: 1.45),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final uri = MassTimesLinks.adorationMap(
                        latitude: state.latitude ?? result?.origin.latitude,
                        longitude: state.longitude ?? result?.origin.longitude,
                        searchQuery: addressController.text.trim(),
                      );
                      launchExternalLink(context, uri.toString());
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Search Adoration on MassTimes.org'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
