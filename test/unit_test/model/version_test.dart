import 'package:flutter_test/flutter_test.dart';
import 'package:marty_authenticator/model/version.dart';

void main() {
  group('Token Version Test', () {
    test('parse, compare, and stringify use semantic version ordering', () {
      final version = Version.parse('2.0.1');

      expect(version.toString(), '2.0.1');
      expect(version, const Version(2, 0, 1));
      expect(version.hashCode, const Version(2, 0, 1).hashCode);
      expect(version > const Version(1, 99, 99), isTrue);
      expect(version >= const Version(2, 0, 1), isTrue);
      expect(version < const Version(2, 1, 0), isTrue);
      expect(version <= const Version(2, 0, 1), isTrue);
      expect(version.compareTo(const Version(2, 0, 2)), isNegative);
      expect(version.compareTo(const Version(2, 1, 0)), isNegative);
      expect(version.compareTo(const Version(3, 0, 0)), isNegative);
      final dynamic unrelated = '2.0.1';
      expect(version == unrelated, isFalse);
      expect(version < '2.0.2', isFalse);
      expect(version > '1.0.0', isFalse);
      expect(version <= '2.0.1', isFalse);
      expect(version >= '2.0.1', isFalse);
    });

    test('rejects malformed versions', () {
      expect(() => Version.parse('1.2'), throwsFormatException);
      expect(() => Version.parse('one.2.3'), throwsFormatException);
    });

    group('serialzation', () {
      test('toJson', () {
        // Arrange
        const version = Version(1, 2, 3);
        // Act
        final result = version.toJson();
        // Assert
        expect(result, {'major': 1, 'minor': 2, 'patch': 3});
      });
      test('fromJson', () {
        // Arrange
        const json = {'major': 1, 'minor': 2, 'patch': 3};
        // Act
        final result = Version.fromJson(json);
        // Assert
        expect(result, const Version(1, 2, 3));
      });
    });
  });
}
