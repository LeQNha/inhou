import '../entities/motel.dart';

abstract class MotelRepository {
  Future<List<Motel>> getMotelsByOwner(String ownerId);
  Future<Motel?> getMotelById(String id);
  Future<void> addMotel(Motel motel);
  Future<void> updateMotel(Motel motel);
  Future<void> deleteMotel(String id);
}
