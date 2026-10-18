import 'package:flutter/material.dart';
import '../main.dart';

/// The Nata logo mark (assets/images/nata_logo.png) in a light circle, so its
/// navy and teal read on the dark glass pills of the welcome screens.
class NataLogo extends StatelessWidget {
  final double size;

  const NataLogo({super.key, this.size = 24});

  static const asset = 'assets/images/nata_logo.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('nata-logo'),
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: const BoxDecoration(
        color: AppColors.background,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
