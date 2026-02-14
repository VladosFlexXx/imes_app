import '../models.dart';
import 'profile_remote_source.dart';

class ApiProfileRemoteSource implements ProfileRemoteSource {
  @override
  Future<UserProfile?> fetchProfile() {
    throw UnimplementedError('API source for profile is not implemented yet.');
  }
}
