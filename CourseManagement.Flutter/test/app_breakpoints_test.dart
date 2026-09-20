import 'package:flutter_test/flutter_test.dart';
import 'package:course_management_flutter/core/theme/app_theme.dart';

void main() {
  test('mobile breakpoint covers narrow screens', () {
    expect(AppBreakpoints.isMobile(320), isTrue);
    expect(AppBreakpoints.isMobile(599), isTrue);
    expect(AppBreakpoints.isMobile(600), isFalse);
  });

  test('tablet breakpoint covers the navigation gap', () {
    expect(AppBreakpoints.isTablet(600), isTrue);
    expect(AppBreakpoints.isTablet(760), isTrue);
    expect(AppBreakpoints.isTablet(900), isTrue);
    expect(AppBreakpoints.isTablet(1023), isTrue);
    expect(AppBreakpoints.isTablet(1024), isFalse);
  });

  test('desktop breakpoint starts at 1024', () {
    expect(AppBreakpoints.isDesktop(1023), isFalse);
    expect(AppBreakpoints.isDesktop(1024), isTrue);
    expect(AppBreakpoints.isDesktop(1440), isTrue);
  });
}
