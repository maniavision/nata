import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../l10n/l10n_ext.dart';

class DeliveryRequestScreen extends StatefulWidget {
  const DeliveryRequestScreen({super.key});

  @override
  State<DeliveryRequestScreen> createState() =>
      _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends State<DeliveryRequestScreen> {
  final _itemCtrl =
      TextEditingController(text: 'Apple AirPods Max (New in Box)');
  final _descCtrl = TextEditingController(
      text: 'Brand new sealed retail box with manufacturer wrap intact.');
  final _weightCtrl = TextEditingController(text: '0.9 kg');
  final _dimsCtrl = TextEditingController(text: '24 × 24 × 8 cm');

  int _category = 0; // 0=Electronics, 1=Apparel, 2=Documents
  bool _photoAttached = true;

  static const _categories = [
    (Icons.devices_rounded, 'Electronics'),
    (Icons.checkroom_rounded, 'Apparel'),
    (Icons.description_rounded, 'Documents'),
  ];

  @override
  void dispose() {
    _itemCtrl.dispose();
    _descCtrl.dispose();
    _weightCtrl.dispose();
    _dimsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                child: Column(
                  children: [
                    _buildTravelerSummary(),
                    const SizedBox(height: 16),
                    _buildItemRequirementBanner(),
                    const SizedBox(height: 16),
                    _buildItemDetailsCard(),
                    const SizedBox(height: 16),
                    _buildSizeWeightCard(),
                    const SizedBox(height: 16),
                    _buildPhotosCard(),
                    const SizedBox(height: 16),
                    _buildPricingCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _buildSendBar(context),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_back,
                  color: AppColors.primary, size: 20),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                context.l10n.deliveryRequest,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          Text(
            context.l10n.step1of1,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }

  // ── Traveler summary ───────────────────────────────────────────────────────
  Widget _buildTravelerSummary() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                'https://randomuser.me/api/portraits/women/44.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: AppColors.secondary,
                  child: const Icon(Icons.person,
                      color: AppColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.selectedTraveler,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 9,
                    letterSpacing: 1.4,
                    color: AppColors.mutedForeground,
                  ),
                ),
                Text(
                  'Amara Kalu',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.foreground,
                  ),
                ),
                Text(
                  'Lagos (LOS) → London (LHR) · Jun 22',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Max 3.0 kg',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Item requirement banner ────────────────────────────────────────────────
  Widget _buildItemRequirementBanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_rounded,
                size: 20, color: AppColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.itemRequirement,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.accent,
                    )),
                const SizedBox(height: 3),
                Text(
                  context.l10n.itemRequirementBody,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.foreground,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Item details card ──────────────────────────────────────────────────────
  Widget _buildItemDetailsCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('WHAT IS THE ITEM?'),
          const SizedBox(height: 6),
          _iconTextField(
            icon: Icons.label_rounded,
            controller: _itemCtrl,
            hint: 'e.g. Sony Headphones, Sealed Cosmetics...',
          ),
          const SizedBox(height: 14),
          _fieldLabel('ITEM CATEGORY'),
          const SizedBox(height: 8),
          Row(
            children: _categories.asMap().entries.map((e) {
              final active = _category == e.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _category = e.key),
                  child: Container(
                    margin: EdgeInsets.only(
                        right: e.key < _categories.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.input,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: active
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Icon(e.value.$1,
                            size: 16,
                            color: active
                                ? Colors.white
                                : AppColors.mutedForeground),
                        const SizedBox(height: 3),
                        Text(e.value.$2,
                            style: GoogleFonts.dmSans(
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 10,
                              color: active
                                  ? Colors.white
                                  : AppColors.foreground,
                            )),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _fieldLabel('ITEM DESCRIPTION'),
          const SizedBox(height: 6),
          TextField(
            controller: _descCtrl,
            maxLines: 2,
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w500,
              fontSize: 12,
              color: AppColors.foreground,
            ),
            decoration: InputDecoration(
              hintText:
                  'Provide details about the item and packaging...',
              hintStyle: GoogleFonts.dmSans(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
              filled: true,
              fillColor: AppColors.input,
              isDense: true,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.ring, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Size & weight card ─────────────────────────────────────────────────────
  Widget _buildSizeWeightCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Size and Weight',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppColors.foreground,
              )),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('PACKAGE WEIGHT'),
                    const SizedBox(height: 6),
                    _iconTextField(
                      icon: Icons.monitor_weight_outlined,
                      controller: _weightCtrl,
                      hint: '0.0 kg',
                    ),
                    const SizedBox(height: 4),
                    Text('Traveler limit: 3.0 kg',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        )),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('PACKAGE DIMENSIONS'),
                    const SizedBox(height: 6),
                    _iconTextField(
                      icon: Icons.inventory_2_outlined,
                      controller: _dimsCtrl,
                      hint: '0 × 0 × 0 cm',
                    ),
                    const SizedBox(height: 4),
                    Text('Traveler limit: Shoebox',
                        style: GoogleFonts.dmSans(
                          fontSize: 10,
                          color: AppColors.mutedForeground,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Photos card ────────────────────────────────────────────────────────────
  Widget _buildPhotosCard() {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(context.l10n.itemPhotos,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.foreground,
                    )),
              ),
              const SizedBox(width: 8),
              Text(
                _photoAttached ? '1 photo attached' : '0 photos',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Photo tile
              if (_photoAttached)
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.secondary,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: AppColors.muted),
                                Container(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.2),
                                  child: const Center(
                                    child: Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 28),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _photoAttached = false),
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.card
                                    .withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close_rounded,
                                  size: 12,
                                  color: AppColors.foreground),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (_photoAttached) const SizedBox(width: 10),
              // Add photo button
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      setState(() => _photoAttached = true),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.input,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded,
                              size: 22, color: AppColors.primary),
                          const SizedBox(height: 4),
                          Text(context.l10n.addPhoto,
                              style: GoogleFonts.dmSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                color: AppColors.mutedForeground,
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Hint tile
              Expanded(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.secondary
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color:
                              AppColors.border.withValues(alpha: 0.6),
                          style: BorderStyle.solid),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16,
                            color: AppColors.mutedForeground),
                        const SizedBox(height: 4),
                        Text('Photo must show sealed factory seal',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(
                              fontSize: 9,
                              color: AppColors.mutedForeground,
                              height: 1.3,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Pricing card ───────────────────────────────────────────────────────────
  Widget _buildPricingCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondary.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.calculatedPrice,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.secondaryForeground,
                  )),
              Text('\$27.50',
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.accent,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          _priceRow(
              'Based on weight (0.9 kg) & dimensions', '\$25.00'),
          const SizedBox(height: 4),
          _priceRow('Platform protection & escrow', '\$2.50'),
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.info_outline_rounded,
                    size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "The price is calculated from your item's weight & size. The traveler can accept or decline this request upon review.",
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppColors.mutedForeground,
              )),
        ),
        const SizedBox(width: 12),
        Text(value,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: AppColors.mutedForeground,
            )),
      ],
    );
  }

  // ── Send button bar ────────────────────────────────────────────────────────
  Widget _buildSendBar(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: AppColors.background.withValues(alpha: 0.95),
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            12 + MediaQuery.of(context).padding.bottom,
          ),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.send_rounded,
                  size: 18, color: Colors.white),
              label: Text(context.l10n.sendDeliveryRequest,
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: AppColors.accent.withValues(alpha: 0.4),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _fieldLabel(String text) => Text(
        text,
        style: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          fontSize: 10,
          letterSpacing: 1.2,
          color: AppColors.mutedForeground,
        ),
      );

  Widget _iconTextField({
    required IconData icon,
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.input,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.foreground,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared card wrapper ────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
