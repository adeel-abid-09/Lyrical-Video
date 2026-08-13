import 'dart:io';

void main() async {
  final Map<String, String> fonts = {
    'Outfit-Regular.ttf': 'https://github.com/googlefonts/Outfit/raw/main/fonts/ttf/Outfit-Regular.ttf',
    'Outfit-Bold.ttf': 'https://github.com/googlefonts/Outfit/raw/main/fonts/ttf/Outfit-Bold.ttf',
    'Roboto-Regular.ttf': 'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Regular.ttf',
    'Roboto-Bold.ttf': 'https://github.com/google/fonts/raw/main/apache/roboto/static/Roboto-Bold.ttf'
  };

  final client = HttpClient();

  for (final entry in fonts.entries) {
    try {
      print('Downloading ${entry.key}...');
      final request = await client.getUrl(Uri.parse(entry.value));
      final response = await request.close();
      if (response.statusCode == 200) {
        final file = File('assets/fonts/${entry.key}');
        if (!file.parent.existsSync()) {
          file.parent.createSync(recursive: true);
        }
        await response.pipe(file.openWrite());
        print('Saved ${entry.key}');
      } else {
        print('Failed to download ${entry.key}: ${response.statusCode}');
      }
    } catch (e) {
      print('Error downloading ${entry.key}: $e');
    }
  }
}
