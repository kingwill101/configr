extension MapExtensions on Map {
  getKey<T>(String key) {
    if (containsKey(key)) {
      return this[key] as T;
    } else {
      throw Exception('Key $key not found');
    }
  }

  Map<String, dynamic> requires(List<String> properties) {
    Map<String, dynamic> props = {};
    for (var property in properties) {
      if (!containsKey(property)) {
        throw Exception('requires the $property  property');
      }
      props[property] = getKey(property);
    }
    return props;
  }
}
