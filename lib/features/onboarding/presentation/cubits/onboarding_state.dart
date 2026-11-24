import 'package:equatable/equatable.dart';
import '../../data/models/onboarding_item_model.dart';

class OnboardingState extends Equatable {
  final int currentIndex;
  final List<OnboardingItemModel> items;
  final bool isCompleted;

  const OnboardingState({
    this.currentIndex = 0,
    required this.items,
    this.isCompleted = false,
  });

  bool get isLastPage => currentIndex == items.length - 1;
  bool get isFirstPage => currentIndex == 0;
  int get totalPages => items.length;

  OnboardingItemModel get currentItem => items[currentIndex];

  OnboardingState copyWith({
    int? currentIndex,
    List<OnboardingItemModel>? items,
    bool? isCompleted,
  }) {
    return OnboardingState(
      currentIndex: currentIndex ?? this.currentIndex,
      items: items ?? this.items,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [currentIndex, items, isCompleted];
}
