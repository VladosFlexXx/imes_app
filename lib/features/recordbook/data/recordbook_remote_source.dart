import '../models.dart';

abstract class RecordbookRemoteSource {
  Future<List<RecordbookGradebook>> fetchGradebooks();
}
