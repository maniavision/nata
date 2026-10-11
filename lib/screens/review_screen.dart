import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import 'home_screen.dart';
import '../l10n/l10n_ext.dart';

/// Post-delivery review screen — used by both sender (reviewing traveler)
/// and traveler (reviewing sender). Role is inferred from context in a real
/// app; here we default to sender reviewing traveler.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _submitted = false;

  static const _tags = [
    '📦 Item was intact',
    '⏰ On time',
    '💬 Great communicator',
    '🔒 Followed all rules',
    '✈️ Smooth handoff',
    '⭐ Would use again',
  ];

  final Set<String> _selectedTags = {'📦 Item was intact', '⏰ On time', '💬 Great communicator'};

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  children: [
                    _buildTravelerCard(),
                    const SizedBox(height: 20),
                    _buildRatingSection(),
                    const SizedBox(height: 20),
                    _buildTagsSection(),
                    const SizedBox(height: 20),
                    _buildCommentSection(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () => Navigator.of(context)
                          .pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const HomeScreen()),
                        (route) => false,
                      ),
                      child: Text(
                        context.l10n.skipForNow,
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                context.l10n.leaveAReview,
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildTravelerCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
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
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: ClipOval(
              child: Image.network(
                'https://randomuser.me/api/portraits/women/44.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) =>
                    Container(color: AppColors.secondary),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Amara Kalu',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.foreground,
                        )),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        size: 14, color: Color(0xFF168A68)),
                  ],
                ),
                Text('Delivered your iPhone 15 Pro · Jun 22',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    )),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('28 deliveries · ',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        )),
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFE5A83B)),
                    const SizedBox(width: 2),
                    Text('4.9 avg',
                        style: GoogleFonts.dmSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                          color: AppColors.mutedForeground,
                        )),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            context.l10n.howWasExperience,
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _ratingLabel(_rating, context),
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _rating;
              return GestureDetector(
                onTap: () => setState(() => _rating = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: filled
                        ? const Color(0xFFE5A83B)
                        : AppColors.border,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _ratingLabel(int r, BuildContext context) {
    final l = context.l10n;
    switch (r) {
      case 1: return l.ratingPoor;
      case 2: return l.ratingFair;
      case 3: return l.ratingGood;
      case 4: return l.ratingGreat;
      case 5: return l.ratingExcellent;
      default: return '';
    }
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.whatWentWell,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _tags.map((tag) {
            final sel = _selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => setState(() {
                if (sel) {
                  _selectedTags.remove(tag);
                } else {
                  _selectedTags.add(tag);
                }
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : AppColors.input,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: sel ? AppColors.primary : AppColors.border,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.dmSans(
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 12,
                    color: sel
                        ? AppColors.primary
                        : AppColors.foreground,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCommentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.leaveComment,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _commentCtrl,
          maxLines: 3,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.foreground,
          ),
          decoration: InputDecoration(
            hintText:
                context.l10n.commentHint,
            hintStyle: GoogleFonts.dmSans(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
            filled: true,
            fillColor: AppColors.input,
            isDense: true,
            contentPadding: const EdgeInsets.all(14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.ring, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
        label: Text(
          context.l10n.submitReview,
          style: GoogleFonts.dmSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.accent.withValues(alpha: 0.4),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  // ── Success state ──────────────────────────────────────────────────────────
  Widget _buildSuccessScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F4EE),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_rounded,
                      size: 48, color: Color(0xFF168A68)),
                ),
                const SizedBox(height: 24),
                Text(context.l10n.reviewSubmitted,
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      color: AppColors.foreground,
                    )),
                const SizedBox(height: 8),
                Text(
                  context.l10n.reviewThanks,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: AppColors.mutedForeground,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const CircularProgressIndicator(
                  color: AppColors.accent,
                  strokeWidth: 2,
                ),
                const SizedBox(height: 12),
                Text(context.l10n.returningHome,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.mutedForeground,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
