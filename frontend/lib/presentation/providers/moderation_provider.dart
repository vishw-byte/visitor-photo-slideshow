import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/admin_models.dart';
import '../../data/repositories/admin_repository.dart';

class ModerationState {
  final DashboardStatsModel? stats;
  final List<AdminPhotoDetailModel> pendingPhotos;
  final List<AdminPhotoDetailModel> approvedPhotos;
  final List<AdminPhotoDetailModel> rejectedPhotos;
  final bool isLoadingStats;
  final bool isLoadingPhotos;
  final String? actionLoadingPhotoId;
  final String? errorMessage;
  final String? successMessage;

  const ModerationState({
    this.stats,
    this.pendingPhotos = const [],
    this.approvedPhotos = const [],
    this.rejectedPhotos = const [],
    this.isLoadingStats = false,
    this.isLoadingPhotos = false,
    this.actionLoadingPhotoId,
    this.errorMessage,
    this.successMessage,
  });

  ModerationState copyWith({
    DashboardStatsModel? stats,
    List<AdminPhotoDetailModel>? pendingPhotos,
    List<AdminPhotoDetailModel>? approvedPhotos,
    List<AdminPhotoDetailModel>? rejectedPhotos,
    bool? isLoadingStats,
    bool? isLoadingPhotos,
    String? actionLoadingPhotoId,
    bool clearActionLoading = false,
    String? errorMessage,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
  }) {
    return ModerationState(
      stats: stats ?? this.stats,
      pendingPhotos: pendingPhotos ?? this.pendingPhotos,
      approvedPhotos: approvedPhotos ?? this.approvedPhotos,
      rejectedPhotos: rejectedPhotos ?? this.rejectedPhotos,
      isLoadingStats: isLoadingStats ?? this.isLoadingStats,
      isLoadingPhotos: isLoadingPhotos ?? this.isLoadingPhotos,
      actionLoadingPhotoId: clearActionLoading ? null : (actionLoadingPhotoId ?? this.actionLoadingPhotoId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

class ModerationNotifier extends StateNotifier<ModerationState> {
  final AdminRepository _repository;

  ModerationNotifier({AdminRepository? repository})
      : _repository = repository ?? AdminRepository(),
        super(const ModerationState());

  /// Refreshes dashboard counters.
  Future<void> loadDashboardStats() async {
    state = state.copyWith(isLoadingStats: true, clearError: true);
    try {
      final stats = await _repository.getDashboardStats();
      state = state.copyWith(stats: stats, isLoadingStats: false);
    } catch (e) {
      state = state.copyWith(
        isLoadingStats: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Refreshes all moderation tabs.
  Future<void> loadAllPhotos() async {
    state = state.copyWith(isLoadingPhotos: true, clearError: true);
    try {
      final pending = await _repository.getPendingPhotos();
      final approved = await _repository.getApprovedPhotos();
      final rejected = await _repository.getRejectedPhotos();
      state = state.copyWith(
        pendingPhotos: pending,
        approvedPhotos: approved,
        rejectedPhotos: rejected,
        isLoadingPhotos: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingPhotos: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Approves a photo if visitor consent was given.
  Future<bool> approvePhoto(String photoId) async {
    state = state.copyWith(
      actionLoadingPhotoId: photoId,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final updatedPhoto = await _repository.approvePhoto(photoId);

      // Move photo from pending to approved list
      final newPending = state.pendingPhotos.where((p) => p.id != photoId).toList();
      final newApproved = [updatedPhoto, ...state.approvedPhotos.where((p) => p.id != photoId)];

      state = state.copyWith(
        pendingPhotos: newPending,
        approvedPhotos: newApproved,
        clearActionLoading: true,
        successMessage: 'Photo approved successfully for slideshow display.',
      );

      // Refresh stats in background
      loadDashboardStats();
      return true;
    } catch (e) {
      state = state.copyWith(
        clearActionLoading: true,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Rejects a photo with a mandatory reason.
  Future<bool> rejectPhoto(String photoId, String reason) async {
    if (reason.trim().isEmpty) {
      state = state.copyWith(errorMessage: 'A reason is required to reject a photo.');
      return false;
    }

    state = state.copyWith(
      actionLoadingPhotoId: photoId,
      clearError: true,
      clearSuccess: true,
    );
    try {
      final updatedPhoto = await _repository.rejectPhoto(photoId, reason.trim());

      // Move photo from pending/approved to rejected list
      final newPending = state.pendingPhotos.where((p) => p.id != photoId).toList();
      final newApproved = state.approvedPhotos.where((p) => p.id != photoId).toList();
      final newRejected = [updatedPhoto, ...state.rejectedPhotos.where((p) => p.id != photoId)];

      state = state.copyWith(
        pendingPhotos: newPending,
        approvedPhotos: newApproved,
        rejectedPhotos: newRejected,
        clearActionLoading: true,
        successMessage: 'Photo rejected.',
      );

      // Refresh stats in background
      loadDashboardStats();
      return true;
    } catch (e) {
      state = state.copyWith(
        clearActionLoading: true,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final moderationProvider = StateNotifierProvider<ModerationNotifier, ModerationState>((ref) {
  return ModerationNotifier();
});
