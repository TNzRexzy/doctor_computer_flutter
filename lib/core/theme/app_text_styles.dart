import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';

/// Defines all text styles used in the app.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle get heading1 => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading2 => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static TextStyle get heading3 => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleSmall => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    color: AppColors.textSecondary,
  );

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11,
    color: AppColors.textTertiary,
  );

  static TextStyle get price => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );

  static TextStyle get priceSmall => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: AppColors.accent,
  );

  static TextStyle get priceOriginal => GoogleFonts.inter(
    fontSize: 14,
    decoration: TextDecoration.lineThrough,
    color: AppColors.textTertiary,
  );
}


