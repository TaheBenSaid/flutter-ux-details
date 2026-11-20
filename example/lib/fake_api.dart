class Place {
  const Place(this.id, this.name, this.city);

  final int id;
  final String name;
  final String city;
}

class FakeApiException implements Exception {
  const FakeApiException();
}

/// Stands in for a backend. Every call waits a little, and throws when
/// [fail] is on, so the error paths in the demo can be seen.
class FakeApi {
  bool fail = false;

  static const _places = [
    Place(1, 'Harbor Bakery', 'Sousse'),
    Place(2, 'Old Town Library', 'Tunis'),
    Place(3, 'Cliffside Trail', 'Tabarka'),
    Place(4, 'Night Market', 'Sfax'),
    Place(5, 'Olive Press Museum', 'Monastir'),
    Place(6, 'Lagoon Viewpoint', 'Bizerte'),
  ];

  Future<List<Place>> fetchPlaces() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    return [..._places];
  }

  Future<void> send({Duration delay = const Duration(milliseconds: 800)}) async {
    await Future<void>.delayed(delay);
    if (fail) throw const FakeApiException();
  }
}
