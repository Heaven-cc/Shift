import 'package:flutter_test/flutter_test.dart';
import 'package:shift_mobile/core/cloud/media_validation.dart';

void main(){
  test('recognizes JPEG from real header, not filename',(){
    final x=ShiftImageType.fromHeader([0xff,0xd8,0xff,0xe1,0x00,0x00]);
    expect(x?.mime,'image/jpeg');
    expect(x?.extension,'jpg');
  });
  test('recognizes PNG and WebP signatures',(){
    final png=ShiftImageType.fromHeader([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a]);
    expect(png?.mime,'image/png');
    final webp=ShiftImageType.fromHeader([0x52,0x49,0x46,0x46,1,2,3,4,0x57,0x45,0x42,0x50]);
    expect(webp?.mime,'image/webp');
  });
  test('rejects fake and unsupported upload payloads',(){
    expect(ShiftImageType.fromHeader([]),isNull);
    expect(ShiftImageType.fromHeader([0x3c,0x73,0x76,0x67]),isNull);
    expect(ShiftImageType.fromHeader([0xff,0xd8]),isNull);
  });
}
