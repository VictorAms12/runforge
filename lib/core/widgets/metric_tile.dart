import 'package:flutter/material.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white60,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: emphasized ? 38 : 28,
                  ),
            ),
            if (unit != null) ...[
              const SizedBox(width: 5),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit!, style: const TextStyle(color: Colors.white54)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
