import '../models.dart';
import 'schedule_remote_source.dart';

class ApiScheduleRemoteSource implements ScheduleRemoteSource {
  @override
  Future<List<Lesson>> fetchLessons() {
    throw UnimplementedError(
      'API source for schedule is not implemented yet.',
    );
  }
}
