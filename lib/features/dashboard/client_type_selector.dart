import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

/// The client types a user can onboard or filter by.
enum ClientType { school, institution, bookshop }

extension ClientTypeX on ClientType {
  /// Canonical stored value used in [SchoolModel.dealerType].
  String get value {
    switch (this) {
      case ClientType.school:
        return 'School';
      case ClientType.institution:
        return 'Institution';
      case ClientType.bookshop:
        return 'Bookshop';
    }
  }

  /// Human readable label shown in the UI.
  String get label {
    switch (this) {
      case ClientType.school:
        return 'School';
      case ClientType.institution:
        return 'Institution (NGO, County offices, Library)';
      case ClientType.bookshop:
        return 'Bookshop';
    }
  }

  /// Short label used inside chips and compact buttons.
  String get shortLabel {
    switch (this) {
      case ClientType.school:
        return 'School';
      case ClientType.institution:
        return 'Institution';
      case ClientType.bookshop:
        return 'Bookshop';
    }
  }

  IconData get icon {
    switch (this) {
      case ClientType.school:
        return Icons.school_outlined;
      case ClientType.institution:
        return Icons.account_balance_outlined;
      case ClientType.bookshop:
        return Icons.local_library_outlined;
    }
  }

  /// Contextual search placeholder requested by the spec.
  /// Schools and Institutions share the "institutions around me" hint.
  String get searchPlaceholder {
    switch (this) {
      case ClientType.school:
      case ClientType.institution:
        return 'Search institutions around me';
      case ClientType.bookshop:
        return 'Search bookshops around me';
    }
  }

  /// Whether the given stored [dealerType] matches this client type.
  /// Tolerates the legacy "Institutions " value (trailing space).
  bool matches(String? dealerType) {
    if (dealerType == null) return false;
    final normalized = dealerType.trim();
    return normalized.toLowerCase() == value.toLowerCase();
  }
}

/// Parses a stored dealer type into a [ClientType], or null if unknown.
ClientType? clientTypeFromValue(String? value) {
  if (value == null) return null;
  final normalized = value.trim().toLowerCase();
  for (final type in ClientType.values) {
    if (type.value.toLowerCase() == normalized) return type;
  }
  return null;
}

/// Reusable popup modal for selecting a client type.
///
/// Returns the chosen [ClientType], or `null` when dismissed.
/// When [includeAll] is true an "All" option is appended (represented by
/// `null` in the returned value) so the same modal can power filtering.
Future<ClientType?> showClientTypeModal(
  BuildContext context, {
  bool includeAll = false,
  ClientType? selected,
}) {
  return showDialog<ClientType?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _ClientTypeModal(includeAll: includeAll, selected: selected),
  );
}

class _ClientTypeModal extends StatelessWidget {
  const _ClientTypeModal({required this.includeAll, this.selected});

  final bool includeAll;
  final ClientType? selected;

  @override
  Widget build(BuildContext context) {
    final options = <_ClientTypeOption>[
      if (includeAll)
        const _ClientTypeOption(
          icon: Icons.apps_outlined,
          title: 'All',
          subtitle: 'Show every client type',
          value: null,
        ),
      ...ClientType.values.map(
        (type) => _ClientTypeOption(
          icon: type.icon,
          title: type.shortLabel,
          subtitle: type.label,
          value: type,
          isSelected: type == selected,
        ),
      ),
    ];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              includeAll ? 'Filter by Client Type' : 'Select Client Type',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              includeAll
                  ? 'Choose a category to filter existing entries.'
                  : 'Choose the type of client you want to onboard.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ...options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ClientTypeTile(option: option),
              ),
            ),
            if (!includeAll)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ClientTypeOption {
  const _ClientTypeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    this.isSelected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ClientType? value;
  final bool isSelected;
}

class _ClientTypeTile extends StatelessWidget {
  const _ClientTypeTile({required this.option});

  final _ClientTypeOption option;

  @override
  Widget build(BuildContext context) {
    final selected = option.isSelected;
    return Material(
      color: selected ? AppColors.primaryGreen.withValues(alpha: 0.12) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, option.value),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primaryGreen : AppColors.borderGrey,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(option.icon, color: AppColors.primaryGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primaryGreen),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable filter bar shown at the top of pages.
///
/// Renders a tappable control that opens the shared [showClientTypeModal]
/// and displays the current selection (or "All" when [selected] is null).
class ClientTypeFilterBar extends StatelessWidget {
  const ClientTypeFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ClientType? selected;
  final ValueChanged<ClientType?> onChanged;

  @override
  Widget build(BuildContext context) {
    final label = selected?.shortLabel ?? 'All';
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primaryGreen,
      child: InkWell(
        onTap: () async {
          final result = await showClientTypeModal(
            context,
            includeAll: true,
            selected: selected,
          );
          if (result != null || selected != null) {
            onChanged(result);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                selected?.icon ?? Icons.apps_outlined,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Client Type: $label',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
