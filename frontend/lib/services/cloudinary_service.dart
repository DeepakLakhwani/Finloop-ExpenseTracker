import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {
  static const String _cloudName = 'dauzb01sn';
  static const String _uploadPreset = 'rrbaobm9';

  /// Uploads an image file from the given [filePath] to Cloudinary.
  /// Returns the secure URL of the uploaded image if successful.
  Future<String?> uploadImage(String filePath) async {
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', url);

      request.fields['upload_preset'] = _uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonMap = json.decode(responseData);
        return jsonMap['secure_url'] as String?;
      } else {
        throw Exception(
          'Cloudinary upload failed with status ${response.statusCode}: $responseData',
        );
      }
    } catch (e) {
      throw Exception('Cloudinary upload error: $e');
    }
  }
}
