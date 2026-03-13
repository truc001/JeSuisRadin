import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../database/app_database.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

class LocationService {
  /// Demande les permissions et retourne la position actuelle.
  /// Lance une exception si la permission est refusée ou si le service est désactivé.
  Future<Position> getCurrentPosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionDeniedException('Location permission permanently denied');
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  /// Retourne le magasin le plus proche parmi [stores] par rapport à [position].
  /// Retourne null si aucun magasin n'a de coordonnées GPS.
  Store? findNearestStore(List<Store> stores, Position position) {
    Store? nearest;
    double minDistance = double.infinity;

    for (final store in stores) {
      if (store.latitude == null || store.longitude == null) continue;
      final distance = _haversineDistance(
        position.latitude,
        position.longitude,
        store.latitude!,
        store.longitude!,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = store;
      }
    }
    return nearest;
  }

  /// Distance en mètres entre deux points GPS (formule de Haversine).
  double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const R = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;
}
