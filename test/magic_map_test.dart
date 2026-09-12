import 'dart:convert';

import 'package:test/test.dart';
import 'package:magic_map/magic_map.dart';

Map<String, dynamic> sample() => {
  'user': {
    'profile': {'name': 'Alice', 'age': 30},
    'hobbies': ['reading', 'traveling'],
    'friends': [
      {'name': 'Bob', 'age': 31},
      {'name': 'Carol', 'age': 29},
    ],
  },
  'nullable': null,
};

void main() {
  group('construction', () {
    test('defaults to an empty map', () {
      final map = MagicMap();
      expect(map.raw, isEmpty);
      expect(map.raw, isA<Map<String, dynamic>>());
    });

    test('deep-copies the input so the original is never mutated', () {
      final original = {
        'user': {
          'tags': ['a'],
        },
      };
      final map = MagicMap(original);
      map.set('user.tags.0', 'z');
      map.set('user.name', 'Alice');
      expect(original['user']!['tags'], ['a']);
      expect(original['user']!.containsKey('name'), isFalse);
    });

    test('normalizes narrowly typed literals so any value can be written', () {
      final map = MagicMap({
        'user': {'name': 'Alice'},
        'count': 1,
        'ids': [1, 2],
      });
      map.set('user.name', 42);
      map.set('count', null);
      map.set('ids.0', 'one');
      expect(map.getPath('user.name'), 42);
      expect(map.hasPath('count'), isTrue);
      expect(map.getPath('count', 'default'), 'default');
      expect(map.getPath('ids.0'), 'one');
    });

    test('converts non-string keys with toString', () {
      final map = MagicMap({1: 'one', true: 'yes'});
      expect(map.getPath('1'), 'one');
      expect(map.getPath('true'), 'yes');
    });

    test('accepts another MagicMap and copies it', () {
      final a = MagicMap({'x': 1});
      final b = MagicMap(a);
      b.set('x', 2);
      expect(a.getPath('x'), 1);
      expect(b.getPath('x'), 2);
    });

    test('rejects non-map input with a clear error', () {
      expect(() => MagicMap([1, 2]), throwsA(isA<MagicMapException>()));
      expect(() => MagicMap(42), throwsA(isA<MagicMapException>()));
      expect(() => MagicMap('x'), throwsA(isA<MagicMapException>()));
    });

    test('rejects cyclic input instead of looping forever', () {
      final cyclic = <String, dynamic>{};
      cyclic['self'] = cyclic;
      expect(() => MagicMap(cyclic), throwsA(isA<MagicMapException>()));

      final list = <dynamic>[];
      list.add(list);
      expect(() => MagicMap({'l': list}), throwsA(isA<MagicMapException>()));
    });
  });

  group('dynamic member access', () {
    test('reads nested maps and lists', () {
      final map = MagicMap(sample()) as dynamic;
      expect(map.user.profile.name, 'Alice');
      expect(map.user.hobbies[0], 'reading');
      expect(map.user.friends[1].name, 'Carol');
    });

    test('returns null for a missing key', () {
      final map = MagicMap(sample()) as dynamic;
      expect(map.user.missing, isNull);
      expect(map.nope, isNull);
    });

    test('writes existing and new keys', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.user.profile.name = 'Bob';
      map.user.profile.city = 'Lagos';
      expect(map.user.profile.name, 'Bob');
      expect(map.user.profile.city, 'Lagos');
      expect(base.raw['user']['profile']['city'], 'Lagos');
    });

    test('list index writes go through to the underlying data', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.user.hobbies[1] = 'swimming';
      expect(base.raw['user']['hobbies'], ['reading', 'swimming']);
    });

    test('list mutations (add, removeAt) go through', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.user.hobbies.add('coding');
      map.user.hobbies.removeAt(0);
      expect(base.raw['user']['hobbies'], ['traveling', 'coding']);
    });

    test('maps inside lists are writable views', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.user.friends[0].age = 32;
      expect(base.raw['user']['friends'][0]['age'], 32);
    });

    test('spread reassignment works', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.user.hobbies = [...?map.user.hobbies, 'coding'];
      expect(base.raw['user']['hobbies'], ['reading', 'traveling', 'coding']);
    });

    test('assigning a view stores a copy, not an alias', () {
      final base = MagicMap(sample());
      final map = base as dynamic;
      map.profileCopy = map.user.profile;
      map.profileCopy.name = 'Zed';
      expect(map.user.profile.name, 'Alice');
      expect(base.raw['profileCopy'], isA<Map<String, dynamic>>());
    });

    test('assigning a raw map stores a copy', () {
      final external = {'a': 1};
      final map = MagicMap() as dynamic;
      map.ext = external;
      external['a'] = 2;
      expect(map.ext.a, 1);
    });

    test('API methods are available on nested views', () {
      final map = MagicMap(sample()) as dynamic;
      expect(map.user.getPath('profile.name'), 'Alice');
      expect(map.user.hobbies.getPath('1'), 'traveling');
      map.user.set('profile.age', 31);
      expect(map.user.profile.age, 31);
    });

    test('unknown method calls still throw NoSuchMethodError', () {
      final map = MagicMap(sample()) as dynamic;
      expect(() => map.user.explode(), throwsNoSuchMethodError);
    });
  });

  group('bracket operators', () {
    test('read and write direct keys', () {
      final map = MagicMap({'a': 1});
      expect(map['a'], 1);
      map['b'] = {'c': 2};
      expect(map['b'], isA<MagicMap>());
      expect(map['b']['c'], 2);
      expect(map['missing'], isNull);
    });

    test('keys are literal, not paths', () {
      final map = MagicMap(sample());
      expect(map['user.profile'], isNull);
      map['dotted.key'] = 1;
      expect(map.raw['dotted.key'], 1);
      expect(map.getPath(r'dotted\.key'), 1);
    });
  });

  group('getPath', () {
    test('reads nested keys', () {
      final map = MagicMap(sample());
      expect(map.getPath('user.profile.name'), 'Alice');
    });

    test('supports list indices in dot and bracket notation', () {
      final map = MagicMap(sample());
      expect(map.getPath('user.hobbies.1'), 'traveling');
      expect(map.getPath('user.hobbies[1]'), 'traveling');
      expect(map.getPath('user.friends[0].name'), 'Bob');
      expect(map.getPath('user.friends.1.name'), 'Carol');
    });

    test('returns the default for missing paths', () {
      final map = MagicMap(sample());
      expect(map.getPath('user.contact.email', 'N/A'), 'N/A');
      expect(map.getPath('user.hobbies.9', 'none'), 'none');
      expect(map.getPath('user.hobbies.x', 'none'), 'none');
      expect(map.getPath('user.profile.name.first', 'none'), 'none');
      expect(map.getPath('missing'), isNull);
    });

    test('returns the default for a null value', () {
      final map = MagicMap(sample());
      expect(map.getPath('nullable', 'fallback'), 'fallback');
    });

    test('returns views for containers', () {
      final map = MagicMap(sample());
      final profile = map.getPath('user.profile');
      final hobbies = map.getPath('user.hobbies');
      expect(profile, isA<MagicMap>());
      expect(hobbies, isA<MagicList>());
      expect(hobbies, ['reading', 'traveling']);
      profile.set('name', 'Bob');
      expect(map.getPath('user.profile.name'), 'Bob');
    });

    test('an empty path returns the root', () {
      final map = MagicMap(sample());
      expect(map.getPath(''), equals(map));
    });

    test('supports escaped dots and brackets in keys', () {
      final map = MagicMap({
        'a.b': {'c[0]': 'v'},
      });
      expect(map.getPath(r'a\.b.c\[0]'), 'v');
    });

    test('numeric segments are keys on maps and indices on lists', () {
      final map = MagicMap({
        '0': 'key zero',
        'list': ['index zero'],
      });
      expect(map.getPath('0'), 'key zero');
      expect(map.getPath('[0]'), 'key zero');
      expect(map.getPath('list.0'), 'index zero');
      expect(map.getPath('list[0]'), 'index zero');
    });

    test('never throws on odd input', () {
      final map = MagicMap(sample());
      for (final path in [
        '.',
        '..',
        'user.',
        '.user',
        'user[',
        'user]',
        'user[]',
        'user[x]',
        'user[-1]',
        'user.hobbies[99999999999999999999]',
        r'\',
      ]) {
        expect(() => map.getPath(path, 'd'), returnsNormally, reason: path);
      }
      expect(map.getPath('.user.profile.name'), 'Alice');
    });
  });

  group('hasPath', () {
    test('distinguishes missing keys from null values', () {
      final map = MagicMap(sample());
      expect(map.hasPath('nullable'), isTrue);
      expect(map.hasPath('missing'), isFalse);
      expect(map.hasPath('user.hobbies.1'), isTrue);
      expect(map.hasPath('user.hobbies.2'), isFalse);
      expect(map.hasPath(''), isTrue);
    });
  });

  group('set', () {
    test('updates existing values', () {
      final map = MagicMap(sample());
      map.set('user.profile.age', 31);
      expect(map.getPath('user.profile.age'), 31);
    });

    test('creates intermediate maps', () {
      final map = MagicMap();
      map.set('a.b.c', 1);
      expect(map.raw, {
        'a': {
          'b': {'c': 1},
        },
      });
    });

    test('creates intermediate lists for integer segments', () {
      final map = MagicMap();
      map.set('items.0.name', 'first');
      map.set('items[1].name', 'second');
      expect(map.raw, {
        'items': [
          {'name': 'first'},
          {'name': 'second'},
        ],
      });
    });

    test('writes and appends to lists', () {
      final map = MagicMap(sample());
      map.set('user.hobbies.0', 'coding');
      map.set('user.hobbies[2]', 'chess');
      expect(map.getPath('user.hobbies'), ['coding', 'traveling', 'chess']);
    });

    test('rejects out-of-range list indices', () {
      final map = MagicMap(sample());
      expect(
        () => map.set('user.hobbies.5', 'x'),
        throwsA(isA<MagicMapException>()),
      );
      expect(map.getPath('user.hobbies'), ['reading', 'traveling']);
    });

    test('rejects a non-integer segment on a list', () {
      final map = MagicMap(sample());
      expect(
        () => map.set('user.hobbies.first', 'x'),
        throwsA(
          isA<MagicMapException>().having(
            (e) => e.path,
            'path',
            'user.hobbies.first',
          ),
        ),
      );
      expect(map.getPath('user.hobbies'), ['reading', 'traveling']);
    });

    test('never replaces a list or scalar with an intermediate map', () {
      final map = MagicMap(sample());
      expect(
        () => map.set('user.profile.name.first', 'A'),
        throwsA(isA<MagicMapException>()),
      );
      expect(map.getPath('user.profile.name'), 'Alice');
    });

    test('replaces a null intermediate with a container', () {
      final map = MagicMap(sample());
      map.set('nullable.child', 1);
      expect(map.getPath('nullable.child'), 1);
    });

    test('rejects an empty path', () {
      final map = MagicMap();
      expect(() => map.set('', 1), throwsA(isA<MagicMapException>()));
    });

    test('stores plain copies of maps, lists and views', () {
      final map = MagicMap();
      final other = MagicMap({'nested': true});
      map.set('a', other);
      map.set('b', [
        {'x': 1},
      ]);
      map.set('c', MagicList([1, 2]));
      expect(map.raw['a'], isA<Map<String, dynamic>>());
      expect(map.raw['b'], isA<List<dynamic>>());
      expect(map.raw['b'][0], isA<Map<String, dynamic>>());
      expect(map.raw['c'], isA<List<dynamic>>());
      other.set('nested', false);
      expect(map.getPath('a.nested'), isTrue);
      expect(() => map.toJsonString(), returnsNormally);
    });
  });

  group('removePath', () {
    test('removes map keys and list items', () {
      final map = MagicMap(sample());
      expect(map.removePath('user.profile.age'), 30);
      expect(map.hasPath('user.profile.age'), isFalse);
      expect(map.removePath('user.hobbies.0'), 'reading');
      expect(map.getPath('user.hobbies'), ['traveling']);
      expect(map.removePath('user.friends[0]'), isA<MagicMap>());
      expect(map.getPath('user.friends.0.name'), 'Carol');
    });

    test('returns null for missing paths and rejects an empty one', () {
      final map = MagicMap(sample());
      expect(map.removePath('nope.nope'), isNull);
      expect(map.removePath('user.hobbies.7'), isNull);
      expect(() => map.removePath(''), throwsA(isA<MagicMapException>()));
    });
  });

  group('getWithGlob', () {
    final map = MagicMap({
      'user': {
        'profile': {'name': 'Alice'},
        'hobbies': ['reading', 'traveling'],
      },
      'company': {
        'departments': {
          'engineering': {'manager': 'Bob'},
          'sales': {'manager': 'Carol'},
        },
      },
      'items': [
        {'name': 'a'},
        {'name': 'b'},
      ],
    });

    test('matches a whole segment with *', () {
      expect(map.getWithGlob('user.*.name'), ['Alice']);
      expect(map.getWithGlob('user.hobbies.*'), ['reading', 'traveling']);
      expect(map.getWithGlob('company.departments.*.manager'), [
        'Bob',
        'Carol',
      ]);
    });

    test('supports [*] and explicit indices', () {
      expect(map.getWithGlob('items[*].name'), ['a', 'b']);
      expect(map.getWithGlob('items[1].name'), ['b']);
      expect(map.getWithGlob('items.0.name'), ['a']);
    });

    test('supports partial wildcards and ?', () {
      expect(map.getWithGlob('company.departments.eng*.manager'), ['Bob']);
      expect(map.getWithGlob('company.departments.s?les.manager'), ['Carol']);
      expect(map.getWithGlob('user.hob*'), [
        ['reading', 'traveling'],
      ]);
    });

    test('supports ** for any depth', () {
      expect(map.getWithGlob('**.manager'), ['Bob', 'Carol']);
      expect(map.getWithGlob('**.name'), ['Alice', 'a', 'b']);
      expect(map.getWithGlob('company.**.manager'), ['Bob', 'Carol']);
    });

    test('returns an empty list when nothing matches', () {
      expect(map.getWithGlob('nope.*'), isEmpty);
      expect(map.getWithGlob('user.hobbies.x'), isEmpty);
    });

    test('returns writable views', () {
      final copy = map.clone();
      final profile = copy.getWithGlob('user.profile').single;
      profile.set('name', 'Zed');
      expect(copy.getPath('user.profile.name'), 'Zed');
    });
  });

  group('immutability helpers', () {
    test('setImmutable leaves the original untouched', () {
      final map = MagicMap(sample());
      final updated = map.setImmutable('user.profile.age', 35);
      expect(updated.getPath('user.profile.age'), 35);
      expect(map.getPath('user.profile.age'), 30);
      expect(updated, isNot(equals(map)));
    });

    test('setImmutable can be chained', () {
      final map = MagicMap(sample());
      final updated = map
          .setImmutable('user.profile.name', 'Alicia')
          .setImmutable('user.profile.age', 32);
      expect(updated.getPath('user.profile.name'), 'Alicia');
      expect(updated.getPath('user.profile.age'), 32);
      expect(map.getPath('user.profile.name'), 'Alice');
    });

    test('setImmutable works on nested views via dynamic', () {
      final map = MagicMap(sample()) as dynamic;
      final clone = map.setImmutable('user.profile.age', 35);
      expect(clone.user.profile.age, 35);
      expect(map.user.profile.age, 30);
    });

    test('clone is fully independent', () {
      final map = MagicMap(sample());
      final copy = map.clone();
      copy.set('user.hobbies.0', 'x');
      (copy as dynamic).user.friends[0].name = 'y';
      expect(map.getPath('user.hobbies.0'), 'reading');
      expect(map.getPath('user.friends.0.name'), 'Bob');
    });
  });

  group('JSON', () {
    test('encodes compactly and with indentation', () {
      final map = MagicMap({
        'a': 1,
        'b': [1, 2],
      });
      expect(map.toJsonString(), '{"a":1,"b":[1,2]}');
      expect(
        map.toJsonString(indent: 2),
        '{\n  "a": 1,\n  "b": [\n    1,\n    2\n  ]\n}',
      );
    });

    test('encodes after set with map and list values', () {
      final map = MagicMap({'a': 1});
      map.set('contact', {'email': 'x@y.z'});
      map.set('items', [
        {'id': 1},
      ]);
      (map as dynamic).more = MagicMap({'k': 'v'});
      expect(
        map.toJsonString(),
        '{"a":1,"contact":{"email":"x@y.z"},"items":[{"id":1}],"more":{"k":"v"}}',
      );
    });

    test('works with jsonEncode directly', () {
      final map = MagicMap(sample());
      expect(jsonEncode(map), jsonEncode(sample()));
      expect(
        jsonEncode(map.getPath('user.hobbies')),
        '["reading","traveling"]',
      );
    });

    test('applies a JS-style replacer', () {
      final map = MagicMap({
        'name': 'alice',
        'tags': ['x', 'y'],
        'nested': {'k': 'v'},
      });
      final out = map.toJsonString(
        replacer: (key, value) => value is String ? value.toUpperCase() : value,
      );
      expect(out, '{"name":"ALICE","tags":["X","Y"],"nested":{"k":"V"}}');
    });

    test('replacer can omit entries', () {
      final map = MagicMap({
        'keep': 1,
        'secret': 2,
        'list': [1, 2],
      });
      final out = map.toJsonString(
        replacer: (key, value) => key == 'secret' ? MagicMap.omit : value,
      );
      expect(out, '{"keep":1,"list":[1,2]}');

      final listOut = map.toJsonString(
        replacer: (key, value) => key == '0' ? MagicMap.omit : value,
      );
      expect(listOut, '{"keep":1,"secret":2,"list":[null,2]}');
    });

    test('replacer receives the root with an empty key', () {
      final map = MagicMap({'a': 1});
      final keys = <String>[];
      map.toJsonString(
        replacer: (key, value) {
          keys.add(key);
          return value;
        },
      );
      expect(keys, ['', 'a']);
    });

    test('toEncodable handles non-JSON values', () {
      final map = MagicMap({'when': DateTime.utc(2020, 1, 2)});
      expect(
        () => map.toJsonString(),
        throwsA(isA<JsonUnsupportedObjectError>()),
      );
      expect(
        map.toJsonString(
          toEncodable: (v) => v is DateTime ? v.toIso8601String() : v,
        ),
        '{"when":"2020-01-02T00:00:00.000Z"}',
      );
    });

    test('decodes JSON objects', () {
      final map = MagicMap.fromJsonString(
        '{"system": {"version": "1.0.0", "config": {"darkMode": true}}}',
      );
      expect(map.getPath('system.config.darkMode'), isTrue);
      expect((map as dynamic).system.version, '1.0.0');
    });

    test('round-trips', () {
      final map = MagicMap(sample());
      final again = MagicMap.fromJsonString(map.toJsonString());
      expect(again.raw, sample());
    });

    test('rejects invalid JSON and non-object roots', () {
      expect(
        () => MagicMap.fromJsonString('{not json'),
        throwsA(isA<MagicMapException>()),
      );
      expect(
        () => MagicMap.fromJsonString('[1, 2]'),
        throwsA(isA<MagicMapException>()),
      );
      expect(
        () => MagicMap.fromJsonString('null'),
        throwsA(isA<MagicMapException>()),
      );
    });
  });

  group('equality and printing', () {
    test('views over the same data are equal', () {
      final map = MagicMap(sample()) as dynamic;
      expect(map.user, equals(map.user));
      expect(map.user.hashCode, map.user.hashCode);
      expect(map.user.hobbies, equals(map.user.hobbies));
      expect(map.user, isNot(equals(map.user.profile)));
    });

    test('distinct maps with equal content are not equal', () {
      expect(MagicMap({'a': 1}), isNot(equals(MagicMap({'a': 1}))));
    });

    test('prints like plain collections', () {
      final map = MagicMap({
        'a': {
          'b': [1, 2],
        },
      });
      expect(map.toString(), '{a: {b: [1, 2]}}');
      expect(map.getPath('a').toString(), '{b: [1, 2]}');
      expect(map.getPath('a.b').toString(), '[1, 2]');
    });

    test('exception message includes the path', () {
      expect(
        const MagicMapException('boom', 'a.b').toString(),
        'MagicMapException: boom (at path: a.b)',
      );
      expect(
        const MagicMapException('boom').toString(),
        'MagicMapException: boom',
      );
    });
  });

  group('MagicList', () {
    test('behaves like a list and wraps elements', () {
      final list = MagicList([
        1,
        {'a': 1},
        [2],
      ]);
      expect(list.length, 3);
      expect(list[0], 1);
      expect(list[1], isA<MagicMap>());
      expect(list[2], isA<MagicList>());
      expect(list.first, 1);
      expect([for (final e in list) e.runtimeType], [int, MagicMap, MagicList]);
    });

    test('copies input and rejects cycles', () {
      final source = [1, 2];
      final list = MagicList(source);
      source.add(3);
      expect(list, [1, 2]);

      final cyclic = <dynamic>[];
      cyclic.add(cyclic);
      expect(() => MagicList(cyclic), throwsA(isA<MagicMapException>()));
    });

    test('write operations go through to raw', () {
      final list = MagicList([1, 2]);
      list.add(3);
      list.addAll([4, 5]);
      list.insert(0, 0);
      list[1] = 'one';
      list.removeLast();
      expect(list.raw, [0, 'one', 2, 3, 4]);
      expect(list.raw, isA<List<dynamic>>());
      list.length = 2;
      expect(list.raw, [0, 'one']);
      list.clear();
      expect(list.raw, isEmpty);
    });

    test('stores normalized copies of inserted containers', () {
      final list = MagicList();
      final other = MagicMap({'x': 1});
      list.add(other);
      list.insert(0, [other]);
      list.addAll([other]);
      other.set('x', 2);
      expect(list.raw[0], isA<List<dynamic>>());
      expect(list.raw[1], isA<Map<String, dynamic>>());
      expect(jsonEncode(list), '[[{"x":1}],{"x":1},{"x":1}]');
    });

    test('addAll with itself does not loop', () {
      final list = MagicList([1, 2]);
      list.addAll(list);
      expect(list, [1, 2, 1, 2]);
    });

    test('sort and shuffle operate on the underlying list', () {
      final list = MagicList([3, 1, 2]);
      list.sort();
      expect(list.raw, [1, 2, 3]);

      final people = MagicList([
        {'age': 30},
        {'age': 20},
      ]);
      people.sort((a, b) => (a.raw['age'] as int).compareTo(b.raw['age']));
      expect(people.raw, [
        {'age': 20},
        {'age': 30},
      ]);

      final shuffled = MagicList([1, 2, 3, 4, 5]);
      shuffled.shuffle();
      expect(shuffled.raw, unorderedEquals([1, 2, 3, 4, 5]));
    });

    test('supports the path API', () {
      final list = MagicList([
        {'name': 'a'},
        {'name': 'b'},
      ]);
      expect(list.getPath('1.name'), 'b');
      expect(list.getPath('[0].name'), 'a');
      expect(list.hasPath('2'), isFalse);
      list.set('2.name', 'c');
      expect(list.length, 3);
      expect(list.getWithGlob('*.name'), ['a', 'b', 'c']);
      expect(list.removePath('0'), isA<MagicMap>());
      expect(list.getWithGlob('*.name'), ['b', 'c']);
      expect(() => list.set('x', 1), throwsA(isA<MagicMapException>()));
    });

    test('setImmutable and clone are independent', () {
      final list = MagicList([1, 2]);
      final updated = list.setImmutable('0', 9);
      expect(updated, [9, 2]);
      expect(list, [1, 2]);
      final copy = list.clone();
      copy.add(3);
      expect(list, [1, 2]);
    });

    test('JSON helpers', () {
      final list = MagicList.fromJsonString('[{"a": 1}, 2]');
      expect(list.getPath('0.a'), 1);
      expect(list.toJsonString(), '[{"a":1},2]');
      expect(list.toJsonString(indent: 1), '[\n {\n  "a": 1\n },\n 2\n]');
      expect(
        () => MagicList.fromJsonString('{}'),
        throwsA(isA<MagicMapException>()),
      );
      expect(
        () => MagicList.fromJsonString('nope'),
        throwsA(isA<MagicMapException>()),
      );
    });

    test('equality is by underlying list', () {
      final map = MagicMap(sample());
      final a = map.getPath('user.hobbies');
      final b = map.getPath('user.hobbies');
      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
      // Structurally equal, but different underlying lists.
      expect(MagicList([1]) == MagicList([1]), isFalse);
    });
  });

  group('typed access', () {
    const json = '''
    {
      "server": {
        "port": 8080, "host": "localhost", "ratio": 1, "big": 1e20,
        "started": "2024-05-01T10:00:00Z", "debug": "true",
        "retries": "3", "timeout": "2.5", "whole": 3.0, "frac": 3.5
      },
      "tags": ["a", "b"],
      "mixed": ["a", 1, null],
      "limits": {"cpu": 2, "mem": 512},
      "users": [{"name": "Bob"}, {"name": "Carol"}],
      "nothing": null
    }
    ''';
    late MagicMap config;
    setUp(() => config = MagicMap.fromJsonString(json));

    group('getAs', () {
      test('returns exact matches and null otherwise', () {
        expect(config.getAs<int>('server.port'), 8080);
        expect(config.getAs<String>('server.host'), 'localhost');
        expect(config.getAs<String>('server.port'), isNull);
        expect(config.getAs<int>('missing'), isNull);
        expect(config.getAs<int>('nothing'), isNull);
        expect(config.getAs<int>('server.port.deeper'), isNull);
      });

      test('combines with ?? for a typed default', () {
        final port = config.getAs<int>('server.port') ?? 8080;
        final other = config.getAs<int>('server.other') ?? 9090;
        expect(port + other, 17170);
      });

      test('returns views for containers and raw collections on request', () {
        final server = config.getAs<MagicMap>('server');
        expect(server, isNotNull);
        server!.set('port', 1);
        expect(config.getPath('server.port'), 1);
        expect(config.getAs<MagicList>('tags'), ['a', 'b']);
        expect(config.getAs<List>('tags'), isA<MagicList>());
        expect(
          config.getAs<Map<String, dynamic>>('server'),
          same(config.raw['server']),
        );
        // A MagicList already is a List<dynamic>, so the view is returned.
        final asList = config.getAs<List<dynamic>>('tags');
        expect(asList, isA<MagicList>());
        expect((asList as MagicList).raw, same(config.raw['tags']));
        expect(config.getAs<Map<String, int>>('limits'), isNull);
        expect(config.getAs<List<String>>('tags'), isNull);
      });

      test('widens int to double and narrows whole doubles to int', () {
        expect(config.getAs<double>('server.ratio'), 1.0);
        expect(config.getAs<double>('server.ratio'), isA<double>());
        expect(config.getAs<int>('server.whole'), 3);
        expect(config.getAs<int>('server.whole'), isA<int>());
        expect(config.getAs<int>('server.frac'), isNull);
        expect(config.getAs<num>('server.frac'), 3.5);
      });

      test('rejects doubles outside int range and non-finite values', () {
        expect(config.getAs<int>('server.big'), isNull);
        config.set('inf', double.infinity);
        config.set('nan', double.nan);
        expect(config.getAs<int>('inf'), isNull);
        expect(config.getAs<int>('nan'), isNull);
        expect(config.getAs<double>('inf'), double.infinity);
      });

      test('parses ISO-8601 strings into DateTime', () {
        expect(
          config.getAs<DateTime>('server.started'),
          DateTime.utc(2024, 5, 1, 10),
        );
        expect(config.getAs<DateTime>('server.host'), isNull);
        expect(config.getAs<DateTime>('server.port'), isNull);
        expect(config.getAs<String>('server.started'), '2024-05-01T10:00:00Z');
      });

      test('does not parse numbers or booleans out of strings by default', () {
        expect(config.getAs<int>('server.retries'), isNull);
        expect(config.getAs<bool>('server.debug'), isNull);
      });

      test('parses strings when asked', () {
        expect(config.getAs<int>('server.retries', parseStrings: true), 3);
        expect(config.getAs<double>('server.retries', parseStrings: true), 3.0);
        expect(config.getAs<double>('server.timeout', parseStrings: true), 2.5);
        expect(config.getAs<int>('server.timeout', parseStrings: true), isNull);
        expect(config.getAs<num>('server.timeout', parseStrings: true), 2.5);
        expect(config.getAs<bool>('server.debug', parseStrings: true), isTrue);
        config.set('flag', ' FALSE ');
        expect(config.getAs<bool>('flag', parseStrings: true), isFalse);
        expect(config.getAs<bool>('server.host', parseStrings: true), isNull);
        expect(config.getAs<int>('server.host', parseStrings: true), isNull);
      });

      test('supports nullable type arguments', () {
        expect(config.getAs<int?>('server.port'), 8080);
        expect(config.getAs<int?>('nothing'), isNull);
        expect(config.getAs<double?>('server.ratio'), 1.0);
      });

      test('works on nested views and on MagicList', () {
        final server = config.getPath('server') as MagicMap;
        expect(server.getAs<int>('port'), 8080);
        final users = config.getPath('users') as MagicList;
        expect(users.getAs<String>('1.name'), 'Carol');
        expect(users.getAs<MagicMap>('[0]')!.getAs<String>('name'), 'Bob');
      });
    });

    group('requireAs', () {
      test('returns converted values', () {
        expect(config.requireAs<int>('server.port'), 8080);
        expect(config.requireAs<double>('server.port'), 8080.0);
        expect(config.requireAs<MagicMap>('server'), isA<MagicMap>());
      });

      test('throws for a missing path with the path in the message', () {
        expect(
          () => config.requireAs<int>('server.missing'),
          throwsA(
            isA<MagicMapException>()
                .having((e) => e.path, 'path', 'server.missing')
                .having((e) => e.message, 'message', contains('No value')),
          ),
        );
      });

      test('throws for null unless T is nullable', () {
        expect(
          () => config.requireAs<int>('nothing'),
          throwsA(
            isA<MagicMapException>().having(
              (e) => e.message,
              'message',
              contains('null'),
            ),
          ),
        );
        expect(config.requireAs<int?>('nothing'), isNull);
      });

      test('throws for a wrong type naming both types', () {
        expect(
          () => config.requireAs<int>('server.host'),
          throwsA(
            isA<MagicMapException>()
                .having((e) => e.message, 'message', contains('Expected int'))
                .having((e) => e.message, 'message', contains('String'))
                .having((e) => e.message, 'message', contains('localhost'))
                .having((e) => e.path, 'path', 'server.host'),
          ),
        );
        expect(
          () => config.requireAs<int>('server'),
          throwsA(
            isA<MagicMapException>().having(
              (e) => e.message,
              'message',
              contains('MagicMap'),
            ),
          ),
        );
      });

      test('truncates long values in the message', () {
        config.set('long', 'x' * 500);
        expect(
          () => config.requireAs<int>('long'),
          throwsA(
            isA<MagicMapException>().having(
              (e) => e.message.length,
              'message length',
              lessThan(120),
            ),
          ),
        );
      });

      test('honours parseStrings', () {
        expect(
          () => config.requireAs<int>('server.retries'),
          throwsA(isA<MagicMapException>()),
        );
        expect(config.requireAs<int>('server.retries', parseStrings: true), 3);
      });
    });

    group('getListOf', () {
      test('rebuilds the list with the requested element type', () {
        final tags = config.getListOf<String>('tags');
        expect(tags, ['a', 'b']);
        expect(tags, isA<List<String>>());
        // The motivating failure: the decoded list has the wrong reified type.
        expect(
          () => config.getPath('tags') as List<String>,
          throwsA(isA<TypeError>()),
        );
      });

      test('returns null for missing, non-list and unconvertible content', () {
        expect(config.getListOf<String>('missing'), isNull);
        expect(config.getListOf<String>('server'), isNull);
        expect(config.getListOf<String>('nothing'), isNull);
        expect(config.getListOf<int>('tags'), isNull);
        expect(config.getListOf<String>('mixed'), isNull);
      });

      test('skipInvalid drops bad elements', () {
        expect(config.getListOf<String>('mixed', skipInvalid: true), ['a']);
        expect(config.getListOf<int>('mixed', skipInvalid: true), [1]);
      });

      test('nullable T keeps null elements', () {
        expect(config.getListOf<String?>('mixed', skipInvalid: true), [
          'a',
          null,
        ]);
        expect(config.getListOf<Object?>('mixed'), ['a', 1, null]);
      });

      test('applies conversions and parseStrings per element', () {
        config.set('nums', [1, 2.0, '3']);
        expect(config.getListOf<double>('nums'), isNull);
        expect(config.getListOf<double>('nums', parseStrings: true), [
          1.0,
          2.0,
          3.0,
        ]);
        expect(config.getListOf<int>('nums', parseStrings: true), [1, 2, 3]);
      });

      test('returns writable views for map elements', () {
        final users = config.getListOf<MagicMap>('users')!;
        users[1].set('name', 'Dave');
        expect(config.getPath('users.1.name'), 'Dave');
        final rawUsers = config.getListOf<Map<String, dynamic>>('users')!;
        expect(rawUsers[0], same(config.raw['users'][0]));
      });

      test('the returned list is detached from the data', () {
        final tags = config.getListOf<String>('tags')!;
        tags.add('c');
        expect(config.getPath('tags'), ['a', 'b']);
      });

      test('works on MagicList', () {
        final users = config.getPath('users') as MagicList;
        expect(users.getListOf<MagicMap>('')!.length, 2);
        expect(MagicList([1, 2]).getListOf<double>(''), [1.0, 2.0]);
      });
    });

    group('getMapOf', () {
      test('rebuilds the map with the requested value type', () {
        final limits = config.getMapOf<int>('limits');
        expect(limits, {'cpu': 2, 'mem': 512});
        expect(limits, isA<Map<String, int>>());
        expect(config.getMapOf<double>('limits'), {'cpu': 2.0, 'mem': 512.0});
      });

      test('returns null for missing, non-map and unconvertible content', () {
        expect(config.getMapOf<int>('missing'), isNull);
        expect(config.getMapOf<int>('tags'), isNull);
        expect(config.getMapOf<int>('server'), isNull);
      });

      test('skipInvalid keeps the convertible entries', () {
        expect(config.getMapOf<int>('server', skipInvalid: true), {
          'port': 8080,
          'ratio': 1,
          'whole': 3,
        });
        expect(
          config.getMapOf<int>('server', skipInvalid: true, parseStrings: true),
          {'port': 8080, 'ratio': 1, 'retries': 3, 'whole': 3},
        );
      });

      test('returns views for nested maps and is detached from the data', () {
        config.set('groups', {
          'a': {'n': 1},
          'b': {'n': 2},
        });
        final groups = config.getMapOf<MagicMap>('groups')!;
        groups['a']!.set('n', 10);
        expect(config.getPath('groups.a.n'), 10);
        groups.remove('b');
        expect(config.hasPath('groups.b'), isTrue);
      });
    });
  });

  group('view constructors', () {
    test('MagicMap.view wraps without copying', () {
      final data =
          jsonDecode('{"user": {"tags": ["a"]}}') as Map<String, dynamic>;
      final map = MagicMap.view(data);
      map.set('user.tags[1]', 'b');
      (map as dynamic).user.name = 'Alice';
      expect(data['user']['tags'], ['a', 'b']);
      expect(data['user']['name'], 'Alice');
      expect(map.raw, same(data));
    });

    test('MagicList.view wraps without copying', () {
      final data = <dynamic>[
        1,
        {'a': 1},
      ];
      final list = MagicList.view(data);
      list.add(3);
      list.set('1.a', 2);
      expect(data, [
        1,
        {'a': 2},
        3,
      ]);
      expect(list.raw, same(data));
    });

    test('a narrowly typed nested container throws on a mismatched write', () {
      final data = <String, dynamic>{
        'user': <String, String>{'name': 'Alice'},
      };
      final map = MagicMap.view(data);
      expect(map.getPath('user.name'), 'Alice');
      map.set('user.name', 'Bob'); // same type, fine
      expect(() => map.set('user.age', 30), throwsA(isA<TypeError>()));
    });

    test('the copying constructor is immune to that', () {
      final data = <String, dynamic>{
        'user': <String, String>{'name': 'Alice'},
      };
      final map = MagicMap(data);
      map.set('user.age', 30);
      expect(map.getPath('user.age'), 30);
    });
  });
}
