import '../models.dart';
import 'grades_remote_source.dart';

class ApiGradesRemoteSource implements GradesRemoteSource {
  @override
  Future<List<GradeCourse>> fetchCourses() {
    throw UnimplementedError('API source for grades is not implemented yet.');
  }

  @override
  Future<CourseGradeReport> fetchCourseReport(GradeCourse course) {
    throw UnimplementedError(
      'API source for course report is not implemented yet.',
    );
  }
}
