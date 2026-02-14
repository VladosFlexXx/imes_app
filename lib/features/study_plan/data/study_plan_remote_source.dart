import '../models.dart';

abstract class StudyPlanRemoteSource {
  Future<List<StudyPlanItem>> fetchItems();
}
