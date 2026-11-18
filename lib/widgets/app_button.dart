import 'package:flutter/material.dart';

import '../configuracion/tema/app_tokens.dart';

enum AppButtonVariant { primary, secondary }

enum AppButtonSize { medium, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool showTrailingIcon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leadingIcon,
    this.trailingIcon = Icons.arrow_forward,
    this.showTrailingIcon = true,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.large,
    this.isLoading = false,
  });

  factory AppButton.primary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon = Icons.arrow_forward,
    bool showTrailingIcon = true,
    AppButtonSize size = AppButtonSize.large,
    bool isLoading = false,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      showTrailingIcon: showTrailingIcon,
      variant: AppButtonVariant.primary,
      size: size,
      isLoading: isLoading,
    );
  }

  factory AppButton.secondary({
    Key? key,
    required String label,
    required VoidCallback? onPressed,
    IconData? leadingIcon,
    IconData? trailingIcon = Icons.arrow_forward,
    bool showTrailingIcon = true,
    AppButtonSize size = AppButtonSize.large,
    bool isLoading = false,
  }) {
    return AppButton(
      key: key,
      label: label,
      onPressed: onPressed,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      showTrailingIcon: showTrailingIcon,
      variant: AppButtonVariant.secondary,
      size: size,
      isLoading: isLoading,
    );
  }

  bool get _isEnabled => onPressed != null && !isLoading;

  double get _height {
    switch (size) {
      case AppButtonSize.medium:
        return AppSizes.touchTargetMin; // 48dp
      case AppButtonSize.large:
        return AppSizes.buttonHeight; // 54dp
    }
  }

  Color get _backgroundColor {
    if (!_isEnabled) {
      return variant == AppButtonVariant.primary
          ? AppColors.border
          : AppColors.transparent;
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.primary;
      case AppButtonVariant.secondary:
        return AppColors.transparent;
    }
  }

  Color get _foregroundColor {
    if (!_isEnabled) {
      return AppColors.textSecondary.withValues(alpha: 0.6);
    }
    switch (variant) {
      case AppButtonVariant.primary:
        return AppColors.onPrimary;
      case AppButtonVariant.secondary:
        return AppColors.primary;
    }
  }

  BorderSide get _borderSide {
    if (variant == AppButtonVariant.secondary) {
      final Color borderColor = _isEnabled
          ? AppColors.primary
          : AppColors.border;
      return BorderSide(color: borderColor, width: 1.5);
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final Color contentColor = _foregroundColor;

    return Material(
      color: _backgroundColor,
      shape: StadiumBorder(side: _borderSide),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: _isEnabled ? onPressed : null,
        child: SizedBox(
          height: _height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(contentColor),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      if (leadingIcon != null)
                        Icon(leadingIcon, color: contentColor, size: 22),
                      Expanded(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: AppTypography.titleMedium.copyWith(
                            color: contentColor,
                          ),
                        ),
                      ),
                      if (showTrailingIcon && trailingIcon != null)
                        Icon(trailingIcon, color: contentColor, size: 22),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
