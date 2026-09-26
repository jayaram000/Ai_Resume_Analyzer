import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/core/di/injection.dart';
import 'package:frontend/core/network/api_client.dart';

class UsageState {
  final int usageRemaining;
  final DateTime? resetAt;
  final bool isUnlimited;
  final bool isLoading;

  const UsageState({
    this.usageRemaining = 3,
    this.resetAt,
    this.isUnlimited = false,
    this.isLoading = false,
  });

  UsageState copyWith({
    int? usageRemaining,
    DateTime? resetAt,
    bool? isUnlimited,
    bool? isLoading,
  }) {
    return UsageState(
      usageRemaining: usageRemaining ?? this.usageRemaining,
      resetAt: resetAt ?? this.resetAt,
      isUnlimited: isUnlimited ?? this.isUnlimited,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class UsageCubit extends Cubit<UsageState> {
  UsageCubit() : super(const UsageState());

  Future<void> fetchUsageStatus() async {
    try {
      final res = await sl<ApiClient>().get('common/usage-status/');
      if (res.statusCode == 200 && res.data is Map && res.data['success'] == true) {
        final data = res.data['data'];
        final resetStr = data['reset_at'] as String?;
        emit(state.copyWith(
          usageRemaining: data['usage_remaining'] ?? 3,
          resetAt: resetStr != null ? DateTime.tryParse(resetStr)?.toLocal() : null,
          isUnlimited: data['is_unlimited'] ?? false,
          isLoading: false,
        ));
      }
    } catch (_) {}
  }

  void updateFromApiResponse(Map<String, dynamic> responseData) {
    if (responseData.containsKey('usage_remaining')) {
      final int remaining = responseData['usage_remaining'] is int
          ? responseData['usage_remaining']
          : int.tryParse(responseData['usage_remaining'].toString()) ?? 3;
      final String? resetStr = responseData['reset_at'];
      emit(state.copyWith(
        usageRemaining: remaining,
        resetAt: resetStr != null ? DateTime.tryParse(resetStr)?.toLocal() : null,
      ));
    }
  }

  void setUnlimited(bool unlimited) {
    emit(state.copyWith(isUnlimited: unlimited));
  }
}
