import 'package:flutter/material.dart';
import '../theme.dart';

class Kicker extends StatelessWidget {
  final String text;
  const Kicker(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(color: AppColors.rose, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 2),
  );
}

class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(24)});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface.withValues(alpha: .88) : Colors.white.withValues(alpha: .76),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .82)),
      ),
      child: child,
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  const PrimaryButton({super.key, required this.label, required this.icon, required this.onPressed, this.loading = false});
  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: loading
        ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Icon(icon, size: 15),
    label: Text(loading ? 'Saving…' : label),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.rose,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class SectionHeading extends StatelessWidget {
  final String kicker;
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const SectionHeading({super.key, required this.kicker, required this.title, this.action, this.onAction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Kicker(kicker),
              const SizedBox(height: 7),
              Text(title, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w500, letterSpacing: -1.1)),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            child: Text(action!, style: const TextStyle(color: AppColors.rose, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
      ],
    ),
  );
}
