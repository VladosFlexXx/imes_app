import '../models.dart';
import 'recordbook_remote_source.dart';

class ApiRecordbookRemoteSource implements RecordbookRemoteSource {
  @override
  Future<List<RecordbookGradebook>> fetchGradebooks() {
    throw UnimplementedError(
      'API source for recordbook is not implemented yet.',
    );
  }
}
