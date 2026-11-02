import 'package:fa/src/device/launcher.dart';
import 'package:flutter_test/flutter_test.dart';

/// The links the launcher opens.
void main() {
  test('call: tel with the digits', () {
    expect(LaunchLinks.call('98480 12345').toString(), 'tel:9848012345');
    expect(LaunchLinks.call('+91 98480-12345').toString(), 'tel:+919848012345');
    expect(LaunchLinks.call('1800 123 4567').toString(), 'tel:18001234567');
  });

  test('WhatsApp: wa.me with the country code', () {
    expect(
      LaunchLinks.whatsApp('98480 12345').toString(),
      'https://wa.me/919848012345',
    );
    expect(
      LaunchLinks.whatsApp('+919848012345').toString(),
      'https://wa.me/919848012345',
    );
    expect(
      LaunchLinks.whatsApp('9848012345', text: 'Namaste').toString(),
      'https://wa.me/919848012345?text=Namaste',
    );
  });

  test('directions: a geo pin', () {
    expect(
      LaunchLinks.directions(17.46, 78.36).toString(),
      'geo:17.460000,78.360000?q=17.460000,78.360000',
    );
  });
}
