extension MapExtensions on Map {
  getKey<T>(String key) {
    if (containsKey(key)) {
      return this[key] as T;
    } else {
      throw Exception('Key $key not found');
    }
  }

  Map<String, dynamic> except(List<String> properties) {
    Map<String, dynamic> mod = {};

    for (final entry in entries) {
      if (properties.contains(entry.key)) continue;
      mod[entry.key] = entry.value;
    }
    return mod;
  }

  Map<String, dynamic> requires(List<String> properties,
      {String? errorMessage}) {
    Map<String, dynamic> props = {};
    for (var property in properties) {
      if (!containsKey(property)) {
        throw ArgumentError(errorMessage ?? 'requires the $property property');
      }
      props[property] = getKey(property);
    }
    return props;
  }
}
