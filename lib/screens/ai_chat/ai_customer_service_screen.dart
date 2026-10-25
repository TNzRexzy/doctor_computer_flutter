import 'package:flutter/material.dart';
import 'package:doctor_computer/core/theme/app_colors.dart';
import 'package:doctor_computer/widgets/ai_chat/doctor_ai_floating.dart';

/// Doctor AI is now a floating round chat (see `DoctorAiFloatingHost`).
/// This screen only exists so the `/ai-chat` route keeps working: it opens the
/// floating chat and immediately returns to the previous screen.
class AiCustomerServiceScreen extends StatefulWidget {
  const AiCustomerServiceScreen({super.key});

  @override
  State<AiCustomerServiceScreen> createState() =>
      _AiCustomerServiceScreenState();
}

class _AiCustomerServiceScreenState extends State<AiCustomerServiceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      DoctorAiController.instance.open();
      Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: AppColors.background);
  }
}
