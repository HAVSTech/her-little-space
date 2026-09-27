import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const rose=Color(0xFFB95763), roseSoft=Color(0xFFF4E0E3), lightBg=Color(0xFFF7F7F5),
      lightText=Color(0xFF252326), lightMuted=Color(0xFF777278), darkBg=Color(0xFF171619),
      darkSurface=Color(0xFF211F22), darkText=Color(0xFFF5EEF0), darkMuted=Color(0xFFAAA2A8);
}
ThemeData buildTheme(Brightness b){
  final dark=b==Brightness.dark;
  final base=ThemeData(useMaterial3:true,brightness:b,scaffoldBackgroundColor:dark?AppColors.darkBg:AppColors.lightBg,
    colorScheme:ColorScheme.fromSeed(seedColor:AppColors.rose,brightness:b,surface:dark?AppColors.darkSurface:Colors.white));
  return base.copyWith(textTheme:GoogleFonts.dmSansTextTheme(base.textTheme).apply(
    bodyColor:dark?AppColors.darkText:AppColors.lightText,displayColor:dark?AppColors.darkText:AppColors.lightText));
}