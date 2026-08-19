import 'package:flutter/material.dart';
import 'package:masar_app/core/theme/app_theme.dart';
import 'package:masar_app/core/data/subjects_data.dart';
import 'package:masar_app/core/widgets/subject_card.dart';
import 'package:masar_app/features/quiz/presentation/screens/quiz_screen.dart';

/// الكويزات والتدريبات — اختيار مادة لبدء اختبار تدريبي، أو اختبار شامل.
class QuizPickerScreen extends StatelessWidget {
  const QuizPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الكويزات والتدريبات')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
          children: [
            SubjectCardTile(
              icon: '🎯',
              title: 'اختبار شامل — جميع المواد',
              subtitle: 'أسئلة عشوائية من كل المواد',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const QuizScreen(
                        subjectFilter: null,
                        testType: 'اختبار تدريبي',
                        axisName: 'جميع المواد')),
              ),
            ),
            const SizedBox(height: 10),
            Text('اختر مادة للتدريب',
                style: AppTheme.displayFont(size: 15)),
            const SizedBox(height: 12),
            ...subjects.map((s) => SubjectCardTile(
                  icon: s.icon,
                  title: s.name,
                  subtitle: 'اختبار تدريبي في ${s.name}',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => QuizScreen(
                            subjectFilter: s.name,
                            testType: 'اختبار تدريبي',
                            axisName: s.name)),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
