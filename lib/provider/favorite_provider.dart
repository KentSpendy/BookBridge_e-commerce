import 'package:flutter/foundation.dart';

class FavoritesProvider with ChangeNotifier {
  final Set<String> _favoriteBookIds = {};

  bool isFavorite(String bookId) {
    return _favoriteBookIds.contains(bookId);
  }

  void toggleFavorite(String bookId) {
    if (_favoriteBookIds.contains(bookId)) {
      _favoriteBookIds.remove(bookId);
    } else {
      _favoriteBookIds.add(bookId);
    }
    notifyListeners();
  }

  List<String> get favoriteBookIds => _favoriteBookIds.toList();
}
