import 'package:flutter/material.dart';

import '../constants/app_theme.dart';
import '../constants/business_types.dart';

class BusinessTypePicker extends StatelessWidget {
  final String? selectedId;
  final ValueChanged<String> onSelected;

  const BusinessTypePicker({
    super.key,
    this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: businessTypes.map((type) {
        final selected = type.id == selectedId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onSelected(type.id),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.limeSoft
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? const Color(0xFFC6F24E)
                      : Colors.grey.shade300,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    type.icon,
                    color: selected
                        ? const Color(0xFF143122)
                        : Colors.grey[600],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          type.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: Color(0xFF143122)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
