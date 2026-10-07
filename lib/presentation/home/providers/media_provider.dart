import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/data/services/device_media_service.dart';

/// State notifier provider for device media scanning
final mediaLoadingProvider = StateProvider<bool>((ref) => false);

final deviceMediaProvider = FutureProvider<DeviceMediaResult>((ref) async {
  return await DeviceMediaService.fetchDeviceMedia();
});
