import 'package:masar_app/core/models/subject.dart';

/// المستويات الدراسية الستة بالتعليم الابتدائي
const List<String> primaryLevels = [
  'المستوى الأول',
  'المستوى الثاني',
  'المستوى الثالث',
  'المستوى الرابع',
  'المستوى الخامس',
  'المستوى السادس',
];

/// قائمة المواد كاملة: مادتان مشتركتان لكل التخصصات + أربع مواد تخصص
/// لكل مستوى من المستويات الستة، حسب متطلبات امتحان الكفاءة المهنية.
final List<Subject> subjects = [
  const Subject(
    name: 'علوم التربية والبيداغوجيا',
    icon: '📘',
    meta: 'مشتركة لجميع التخصصات',
  ),
  const Subject(
    name: 'التشريع المدرسي والإداري',
    icon: '⚖️',
    meta: 'مشتركة لجميع التخصصات',
  ),
  const Subject(
    name: 'اللغة العربية',
    icon: '📗',
    meta: 'من الأول إلى السادس ابتدائي',
    levels: primaryLevels,
  ),
  const Subject(
    name: 'الرياضيات',
    icon: '🧮',
    meta: 'من الأول إلى السادس ابتدائي',
    levels: primaryLevels,
  ),
  const Subject(
    name: 'النشاط العلمي',
    icon: '🔬',
    meta: 'من الأول إلى السادس ابتدائي',
    levels: primaryLevels,
  ),
  const Subject(
    name: 'الفرنسية',
    icon: '🇫🇷',
    meta: 'من الأول إلى السادس ابتدائي',
    levels: primaryLevels,
  ),
];
