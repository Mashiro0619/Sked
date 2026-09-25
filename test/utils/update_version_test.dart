import 'package:flutter_test/flutter_test.dart';
import 'package:sked/utils/update_version.dart';

void main() {
  test(
    'normalization retains prereleases but ignores tag prefix and build',
    () {
      expect(normalizeUpdateVersion(' v1.2.3+5 '), '1.2.3');
      expect(normalizeUpdateVersion('V2.0.0-beta.1+007'), '2.0.0-beta.1');
      expect(normalizeUpdateVersion('2.0.0-rc.1'), '2.0.0-rc.1');
      expect(normalizeUpdateVersion(''), '');
    },
  );

  test(
    'compares numeric core versions and keeps historical short versions',
    () {
      expect(compareUpdateVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareUpdateVersions('1.2', '1.2.0'), 0);
      expect(compareUpdateVersions('v1', '1.0.0'), 0);
      expect(compareUpdateVersions('2.0.0-alpha.1', '1.99.99'), greaterThan(0));
    },
  );

  test('implements the SemVer prerelease precedence sequence', () {
    const ordered = [
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.2',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0-rc.2',
      '1.0.0-rc.10',
      '1.0.0',
    ];
    for (var left = 0; left < ordered.length; left++) {
      expect(compareUpdateVersions(ordered[left], ordered[left]), 0);
      for (var right = left + 1; right < ordered.length; right++) {
        expect(
          compareUpdateVersions(ordered[left], ordered[right]),
          lessThan(0),
          reason: [ordered[left], '<', ordered[right]].join(' '),
        );
        expect(
          compareUpdateVersions(ordered[right], ordered[left]),
          greaterThan(0),
        );
      }
    }
  });

  test(
    'numeric identifiers sort before text; text comparison is case sensitive',
    () {
      expect(compareUpdateVersions('1.0.0-9', '1.0.0-alpha'), lessThan(0));
      expect(
        compareUpdateVersions('1.0.0-alpha.1', '1.0.0-alpha.1.a'),
        lessThan(0),
      );
      expect(compareUpdateVersions('1.0.0-RC.1', '1.0.0-rc.1'), lessThan(0));
    },
  );

  test('build metadata does not affect stable or prerelease precedence', () {
    expect(compareUpdateVersions('v1.2.3+999', '1.2.3+001'), 0);
    expect(compareUpdateVersions('1.2.3-rc.1+9', '1.2.3-rc.1+10'), 0);
    expect(compareUpdateVersions('1.2.3+1', '1.2.3-rc.99+999'), greaterThan(0));
  });

  test(
    'large numeric identifiers do not overflow or lose precision on web',
    () {
      expect(
        compareUpdateVersions(
          '1.0.0-rc.9007199254740993',
          '1.0.0-rc.9007199254740992',
        ),
        greaterThan(0),
      );
      expect(
        compareUpdateVersions(
          '18446744073709551616.0.0',
          '18446744073709551615.0.0',
        ),
        greaterThan(0),
      );
    },
  );

  test('identifies prereleases independently of build metadata', () {
    expect(isPrereleaseUpdateVersion('1.0.0-alpha'), isTrue);
    expect(isPrereleaseUpdateVersion('1.0.0-rc.1+5'), isTrue);
    expect(isPrereleaseUpdateVersion('1.0.0+build-alpha.1'), isFalse);
  });

  for (final invalid in [
    '',
    'future',
    '1.x',
    '1..2',
    '.1.2',
    '1.2.3.4',
    '01.2.3',
    '1.02.3',
    '1.2.03',
    '1.2.3-01',
    '1.2.3-alpha.01',
    '1.2.3-',
    '1.2.3-rc.',
    '1.2.3-alpha..1',
    '1.2.3+',
    '1.2.3+build..1',
    '1.2.3++build',
    '1.2.3-测试',
    'vv1.2.3',
  ]) {
    test('rejects malformed version "$invalid"', () {
      expect(normalizeUpdateVersion(invalid), '');
      expect(
        () => compareUpdateVersions(invalid, '1.0.0'),
        throwsFormatException,
      );
      expect(
        () => compareUpdateVersions('1.0.0', invalid),
        throwsFormatException,
      );
      expect(() => isPrereleaseUpdateVersion(invalid), throwsFormatException);
    });
  }
}
