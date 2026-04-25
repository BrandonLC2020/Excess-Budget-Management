/// A wrapper class to distinguish between "not provided" (null wrapper)
/// and "explicitly null" (wrapper with null value).
class Wrapped<T> {
  final T value;
  const Wrapped(this.value);
}
