import 'package:flutter/material.dart';
import 'package:prescription_scanner/theme.dart';

/// Full-height, keyboard-safe editor for one transcribed medicine.
class MedicineEditSheet extends StatelessWidget {
  const MedicineEditSheet({
    required this.name,
    required this.strength,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.route,
    required this.instructions,
    super.key,
  });

  final TextEditingController name;
  final TextEditingController strength;
  final TextEditingController dosage;
  final TextEditingController frequency;
  final TextEditingController duration;
  final TextEditingController route;
  final TextEditingController instructions;

  static const _field = InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.canvas,
    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: AppColors.teal, width: 1.4),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.88,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        builder: (context, scroll) => Material(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 4, 0),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Edit medicine',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.muted,
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Correct only what is visible on the paper. This is not medical advice.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  children: [
                    TextField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: _field.copyWith(
                        labelText: 'Medicine name',
                        prefixIcon: const Icon(Icons.medication_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: strength,
                            textInputAction: TextInputAction.next,
                            decoration: _field.copyWith(
                              labelText: 'Strength',
                              hintText: '500 mg',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: dosage,
                            textInputAction: TextInputAction.next,
                            decoration: _field.copyWith(
                              labelText: 'Dosage',
                              hintText: '1 tablet',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: frequency,
                            textInputAction: TextInputAction.next,
                            decoration: _field.copyWith(
                              labelText: 'How often',
                              hintText: 'Twice a day',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: duration,
                            textInputAction: TextInputAction.next,
                            decoration: _field.copyWith(
                              labelText: 'Duration',
                              hintText: '5 days',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: route,
                      textInputAction: TextInputAction.next,
                      decoration: _field.copyWith(
                        labelText: 'Route',
                        hintText: 'By mouth',
                        prefixIcon: const Icon(Icons.route_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: instructions,
                      minLines: 2,
                      maxLines: 4,
                      decoration: _field.copyWith(
                        labelText: 'Instructions',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
