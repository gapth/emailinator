import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AnalyticsService {
  AnalyticsService._();

  static String _platformForAnalytics() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'web';
    }
  }

  static Future<void> logEvent({
    required String eventType,
    Map<String, dynamic>? metadata,
    String? platform,
    String? appVersion,
    String? ingestType,
    String? ingestId,
    String? taskId,
    String? setupStage,
    DateTime? occurredAt,
    String? idempotencyKey,
  }) async {
    try {
      final client = Supabase.instance.client;
      final params = <String, dynamic>{
        '_platform': platform ?? _platformForAnalytics(),
        '_event_type': eventType,
        '_metadata': metadata ?? <String, dynamic>{},
        '_idempotency_key': idempotencyKey ?? const Uuid().v4(),
      };

      if (appVersion != null) params['_app_version'] = appVersion;
      if (ingestType != null) params['_ingest_type'] = ingestType;
      if (ingestId != null) params['_ingest_id'] = ingestId;
      if (taskId != null) params['_task_id'] = taskId;
      if (setupStage != null) params['_setup_stage'] = setupStage;
      if (occurredAt != null) {
        params['_occurred_at'] = occurredAt.toUtc().toIso8601String();
      }

      await client.rpc('log_analytics_event', params: params);
    } catch (_) {
      // Never allow analytics to break UX.
    }
  }

  static Future<void> logAppEntered({
    Map<String, dynamic>? metadata,
    String? appVersion,
  }) async {
    await logEvent(
      eventType: 'app_entered',
      metadata: metadata ?? const {'screen': 'home'},
      appVersion: appVersion,
    );
  }
}
