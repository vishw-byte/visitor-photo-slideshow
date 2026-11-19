import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/models/photo_model.dart';
import '../../data/repositories/visitor_repository.dart';

class PhotoState {
  final List<PhotoModel> photos;
  final bool isLoading;
  final bool isUploading;
  final double uploadProgress;
  final String? errorMessage;
  final String? successMessage;

  const PhotoState({
    this.photos = const [],
    this.isLoading = false,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.successMessage,
  });

  PhotoState copyWith({
    List<PhotoModel>? photos,
    bool? isLoading,
    bool? isUploading,
    double? uploadProgress,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return PhotoState(
      photos: photos ?? this.photos,
      isLoading: isLoading ?? this.isLoading,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class PhotoNotifier extends StateNotifier<PhotoState> {
  final VisitorRepository _repository;

  PhotoNotifier([VisitorRepository? repository])
      : _repository = repository ?? VisitorRepository(),
        super(const PhotoState());

  /// Loads photos previously uploaded by the visitor.
  Future<void> loadMyPhotos() async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final list = await _repository.getMyPhotos();
      state = state.copyWith(photos: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Uploads selected images with progress feedback.
  Future<bool> uploadPhotos({
    required List<XFile> files,
    required bool consentGiven,
  }) async {
    state = state.copyWith(
      isUploading: true,
      uploadProgress: 0.0,
      clearMessages: true,
    );

    try {
      final uploadedList = await _repository.uploadPhotos(
        files: files,
        consentGiven: consentGiven,
        onProgress: (sent, total) {
          if (total > 0) {
            state = state.copyWith(uploadProgress: sent / total);
          }
        },
      );

      // Prepend newly uploaded pending photos to state list
      final updatedPhotos = [...uploadedList, ...state.photos];
      state = state.copyWith(
        photos: updatedPhotos,
        isUploading: false,
        uploadProgress: 1.0,
        successMessage: 'Successfully uploaded ${uploadedList.length} photo(s)! Awaiting host review.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        uploadProgress: 0.0,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  /// Requests deletion of an uploaded photo.
  Future<bool> deletePhoto(String photoId) async {
    state = state.copyWith(isLoading: true, clearMessages: true);
    try {
      final success = await _repository.deletePhoto(photoId);
      if (success) {
        final remaining = state.photos.where((p) => p.id != photoId).toList();
        state = state.copyWith(
          photos: remaining,
          isLoading: false,
          successMessage: 'Photo deleted successfully.',
        );
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }
}

final photoProvider = StateNotifierProvider<PhotoNotifier, PhotoState>((ref) {
  return PhotoNotifier();
});
