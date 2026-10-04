import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppGradients {
  const AppGradients._();

  static const LinearGradient signature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.gradStart,
      AppColors.gradMid1,
      AppColors.gradMid2,
      AppColors.gradEnd,
    ],
  );
}