/// Minimal signature validation before uploading a user-selected image.
/// Client-side checks are a UX safeguard; provider workers must still validate
/// decoded media and enforce platform-specific limits server-side.
class ShiftImageType {
  const ShiftImageType(this.mime,this.extension);
  final String mime;
  final String extension;

  static ShiftImageType? fromHeader(List<int> header) {
    if (header.length>=3 && header[0]==0xff && header[1]==0xd8 && header[2]==0xff) {
      return const ShiftImageType('image/jpeg','jpg');
    }
    if(header.length>=8 &&
       header[0]==0x89 && header[1]==0x50 && header[2]==0x4e &&
       header[3]==0x47 && header[4]==0x0d && header[5]==0x0a &&
       header[6]==0x1a && header[7]==0x0a) {
      return const ShiftImageType('image/png','png');
    }
    if(header.length>=12 &&
       header[0]==0x52 && header[1]==0x49 && header[2]==0x46 && header[3]==0x46 &&
       header[8]==0x57 && header[9]==0x45 && header[10]==0x42 && header[11]==0x50) {
      return const ShiftImageType('image/webp','webp');
    }
    return null;
  }
}
