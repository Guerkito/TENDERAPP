import 'package:flutter/material.dart';

class InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback onClose;

  const InfoBanner({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Color.lerp(color, Colors.black, 0.3),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClose,
            child: Icon(Icons.close, color: color.withOpacity(0.5), size: 18),
          ),
        ],
      ),
    );
  }
}
