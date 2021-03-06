library duty.hashmap;

import 'dart:core' as core;
import 'dart:collection' show IterableMixin;

import 'package:duty/monad.dart';
import 'package:duty/match.dart';
import 'package:duty/tuple.dart';

/** Custom map implementation supporting iterable style and
 * monad computations */
abstract class Map<K, V> implements core.Iterable<Tuple2<K, V>> {
  factory Map() = WrappedMap;

  /** Creates a new map. If there is no value for a key, the default
   * function is called. */
  factory Map.withDefault(V defaultFn(K key)) = DefaultMap;

  /** Instatiates a new empty map. Same as
   *
   *     new Map()
   */
  factory Map.empty() = Map;

  /** Instantiates a new map from a default dart map */
  factory Map.fromMap(core.Map<K, V> map) {
    final target = new Map();
    map.forEach((K key, V value) => target[key] = value);
    return target;
  }

  /** Returns an [Option]. If there is a value for the key, it
   * is wrapped inside a [Some]. Else, it is [None]. */
  Option<V> get(K key);

  /** Returns a default dart map from this map */
  core.Map<K, V> toMap();

  /** Directly accesses the underlying value. Might throw an exception
   * if there is no key-value mapping */
  V operator [](K key);

  /** Checks if the specified key-value binding is contained */
  core.bool containsKey(K key);

  /** Assigns the specified value to the specified key */
  operator []=(K key, V value);

  /** Checks if the two maps have the same content */
  core.bool sameContent(Map<K, V> other);

  /** Maps the keys of this map with a mapping function. Returns a new map. */
  Map<dynamic, V> mapKeys(f(K key));

  /** Maps the values of this map with a mapping function. Returns a new map. */
  Map<K, dynamic> mapValues(f(V value));

  /** Inserts the tuple into this map. */
  void put(Tuple2<K, V> tuple);

  /** Retrieves the key or evaluates orElse, inserts and returns it */
  V getOrElseUpdate(K key, orElse);

  /** Gets the value associated with the key or evaluates orElse and
   * returns it */
  V getOrElse(K key, orElse);

  /** Returns this map with the specified default function. */
  Map<K, V> defaulting(V defaultFn(K key));
}

class WrappedMap<K, V> extends core.Object with IterableMixin<Tuple2<K, V>>
    implements Map<K, V> {
  final _values = new core.Map<K, Tuple2<K, V>>();

  Option<V> get(K key) {
    final value = _values[key];
    if (null == value) return None;
    return new Some(value.v2);
  }

  V operator [](K key) => _values[key].v2;

  operator []=(K key, V value) => _values[key] = tuple.two(key, value);

  V getOrElse(K key, orElse) => get(key).getOrElse(orElse);

  V getOrElseUpdate(K key, orElse) {
    return get(key).getOrElse(() {
      final newElem = new Evaluatable(orElse).evaluate();
      this[key] = newElem;
      return newElem;
    });
  }

  Map<dynamic, V> mapKeys(f(K key)) {
    var result = new WrappedMap<dynamic, V>();
    forEach((Tuple2<K, V> tuple) {
      var mappedKey = f(tuple.v1);
      result[mappedKey] = tuple.v2;
    });
    return result;
  }

  Map<dynamic, V> mapValues(f(V value)) {
    var result = new WrappedMap<dynamic, V>();
    forEach((Tuple2<K, V> tuple) {
      var mappedValue = f(tuple.v2);
      result[tuple.v1] = mappedValue;
    });
    return result;
  }

  void put(Tuple2<K, V> tuple) {
    _values[tuple.v1] = tuple;
  }

  core.Map<K, V> toMap() {
    var result = new Map<K, V>();
    this.forEach((tuple) => result[tuple.v1] = tuple.v2);
    return result;
  }

  core.bool containsKey(K key) => _values.containsKey(key);

  core.Iterator<Tuple2<K, V>> get iterator => _values.values.iterator;

  core.bool operator ==(other) {
    if (other is! WrappedMap) return false;
    return sameContent(other);
  }

  core.bool sameContent(Map<K, V> other) {
    return this.every((tuple) {
      return other.get(tuple.v1) == new Some(tuple.v2);
    });
  }

  Map<K, V> defaulting(V defaultFn(K key)) =>
      new DefaultMap(defaultFn, map: this);

  core.String toString() =>
      "WrappedMap(${map((tuple) => "${tuple.v1}, ${tuple.v2}").join(", ")})";
}

class DefaultMap<K, V> extends core.Object with IterableMixin<Tuple2<K, V>>
    implements Map<K, V> {
  final Map<K, V> _wrapped;
  final _defaultFn;

  DefaultMap(V defaultFn(K key), {Map<K, V> map})
      : _defaultFn = defaultFn,
        _wrapped = null == map ? new WrappedMap<K, V>() : map;

  Option<V> get(K key) =>
      _wrapped.get(key).orElse(() => new Some(_defaultFn(key)));

  V operator [](K key) => get(key).get;

  operator []=(K key, V value) => _wrapped[key] = value;

  V getOrElse(K key, orElse) => _wrapped.getOrElse(key, orElse);

  V getOrElseUpdate(K key, orElse) => _wrapped.getOrElseUpdate(key, orElse);

  core.Map<K, V> toMap() => _wrapped.toMap();

  core.Iterator<Tuple2<K, V>> get iterator => _wrapped.iterator;

  core.bool containsKey(K key) => _wrapped.containsKey(key);

  Map<dynamic, V> mapKeys(f(K key)) => _wrapped.mapKeys(f);

  Map<K, dynamic> mapValues(f(V value)) => _wrapped.mapValues(f);

  void put(Tuple2<K, V> tuple) => _wrapped.put(tuple);

  Map<K, V> defaulting(V defaultFn(K key)) =>
      new DefaultMap(defaultFn, map: this);

  core.bool operator ==(other) {
    if (other is! DefaultMap) return false;
    return _wrapped == other._wrapped;
  }

  core.bool sameContent(Map<K, V> other) {
    return this._wrapped.sameContent(other);
  }

  core.String toString() =>
      "DefaultMap(${map((tuple) => "${tuple.v1}, ${tuple.v2}").join(", ")})";
}
