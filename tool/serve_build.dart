// Minimal static file server for build/web, used only to preview the release
// bundle locally. Not part of the app.
// ignore_for_file: avoid_print
import 'dart:io';

const _types = <String, String>{
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript',
  '.mjs': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.wasm': 'application/wasm',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff2': 'font/woff2',
  '.bin': 'application/octet-stream',
  '.symbols': 'application/octet-stream',
};

Future<void> main(List<String> args) async {
  final rootPath = args.isNotEmpty ? args[0] : 'build/web';
  final port = args.length > 1 ? int.parse(args[1]) : 8080;
  final root = Directory(rootPath).absolute;

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('serving ${root.path} on http://localhost:$port');

  await for (final request in server) {
    var rel = Uri.decodeComponent(request.uri.path);
    if (rel.startsWith('/')) rel = rel.substring(1);
    if (rel.isEmpty) rel = 'index.html';

    var file = File('${root.path}${Platform.pathSeparator}'
        '${rel.replaceAll('/', Platform.pathSeparator)}');

    // SPA fallback: unknown paths serve the shell so hash routes still load.
    if (!file.existsSync()) file = File('${root.path}/index.html');

    final ext = file.path.contains('.')
        ? file.path.substring(file.path.lastIndexOf('.'))
        : '';
    request.response.headers.contentType =
        ContentType.parse(_types[ext] ?? 'application/octet-stream');
    // No caching, so a rebuild is picked up on reload.
    request.response.headers.set('Cache-Control', 'no-store');

    try {
      await request.response.addStream(file.openRead());
    } catch (_) {
      request.response.statusCode = HttpStatus.notFound;
    }
    await request.response.close();
  }
}
