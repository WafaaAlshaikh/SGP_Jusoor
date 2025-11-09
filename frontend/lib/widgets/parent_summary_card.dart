import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

class ParentSummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final String buttonText;
  final VoidCallback onTap;
  final Color color;

  const ParentSummaryCard({
    super.key,
    required this.icon,
    required this.title,
    this.count,
    required this.buttonText,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 15),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 5),
            Text(
              count.toString(),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: ParentAppColors.textDark),
            ),
            Text(title, style: const TextStyle(fontSize: 12, color: ParentAppColors.textGrey)),
            const Spacer(),
            Text(buttonText, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
