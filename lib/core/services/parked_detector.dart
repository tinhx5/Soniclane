import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class VehicleMotionState {
  final double speedKmh;
  final bool isParked;
  final bool isMovingOverThreshold;

  const VehicleMotionState({
    required this.speedKmh,
    required this.isParked,
    required this.isMovingOverThreshold,
  });

  static const desktopDefault = VehicleMotionState(
    speedKmh: 0,
    isParked: true,
    isMovingOverThreshold: false,
  );
}

/// Detects vehicle speed via GPS.
/// `0 km/h` for >= 15s -> Parked (`P-GEAR • VIDEO READY`).
/// `> 5 km/h` -> Moving (enforces safety lockout if enabled).
/// On Windows Desktop, safely defaults to Parked mode.
class ParkedDetector {
  ParkedDetector._();
  static final ParkedDetector instance = ParkedDetector._();

  final _controller = StreamController<VehicleMotionState>.broadcast();
  StreamSubscription<Position>? _sub;
  DateTime? _stationarySince;
  VehicleMotionState _current = VehicleMotionState.desktopDefault;

  VehicleMotionState get current => _current;
  Stream<VehicleMotionState> get stream => _controller.stream;

  Future<void> startMonitoring({bool enabled = true}) async {
    await stop();
    if (!enabled || kIsWeb || Platform.isWindows || Platform.isLinux) {
      _current = VehicleMotionState.desktopDefault;
      _controller.add(_current);
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final locationSettings = Platform.isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 3,
              forceLocationManager: true,
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.medium,
              distanceFilter: 3,
            );

      _sub = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen((pos) {
        final kmh = (pos.speed < 0 ? 0.0 : pos.speed) * 3.6;
        if (kmh <= 1.0) {
          _stationarySince ??= DateTime.now();
          final elapsed = DateTime.now().difference(_stationarySince!).inSeconds;
          _current = VehicleMotionState(
            speedKmh: 0,
            isParked: elapsed >= 15,
            isMovingOverThreshold: false,
          );
        } else {
          _stationarySince = null;
          _current = VehicleMotionState(
            speedKmh: kmh,
            isParked: false,
            isMovingOverThreshold: kmh > 5.0,
          );
        }
        _controller.add(_current);
      });
    } catch (_) {
      // Safe fallback to parked default if GPS unavailable
      _current = VehicleMotionState.desktopDefault;
      _controller.add(_current);
    }
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }
}
