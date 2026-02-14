import '../models.dart';
import 'study_plan_remote_source.dart';

class ApiStudyPlanRemoteSource implements StudyPlanRemoteSource {
  @override
  Future<List<StudyPlanItem>> fetchItems() {
    throw UnimplementedError(
      'API source for study plan is not implemented yet.',
    );
  }
}
