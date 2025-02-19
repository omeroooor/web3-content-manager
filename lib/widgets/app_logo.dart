import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final bool showText;
  final double size;
  final Color? color;

  const AppLogo({
    super.key,
    this.showText = true,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logoColor = color ?? theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Web3 Content Management logo
        Stack(
          children: [
            // Web3/Blockchain network icon
            Icon(
              Icons.hub_outlined,
              size: size,
              color: logoColor,
            ),
            // W3 indicator
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: logoColor,
                    width: 1,
                  ),
                ),
                child: Text(
                  '3',
                  style: TextStyle(
                    color: logoColor,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Text(
            'W3CM',
            style: TextStyle(
              color: logoColor,
              fontSize: size * 0.8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
