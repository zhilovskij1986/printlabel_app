import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiClient {
  // static const String _host = '192.168.3.144';
  // static const String _publication = 'begliy_test';
  // static const int _port = 80;

  static const String _host = '192.168.3.8';
  static const String _publication = 'BegAuto';
  static const int _port = 8090;

  static const String _serviceName = 'apiv2';
  static const String _login = 'tradev2';
  static const String _password = 'Fnjdew-nqnyIDNB+df812NNjao';

  Map<String, String> get _headers {
    final String credentials = '$_login:$_password';
    final String encodedCredentials = base64Encode(utf8.encode(credentials));

    return {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Basic $encodedCredentials',
    };
  }

  // Універсальний метод для виконання POST-запитів
  Future<dynamic> post(
    String endpoint, {
    required Map<String, dynamic> body,
  }) async {
    final Uri url = Uri.http(
      '$_host:$_port',
      '/$_publication/hs/$_serviceName$endpoint',
    );

    try {
      final response = await http
          .post(
            url,
            headers: _headers,
            body: jsonEncode(body), // Перетворюємо Map у JSON-рядок
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoderBody = utf8.decode(response.bodyBytes);
        if (decoderBody.isEmpty) return null;
        return jsonDecode(decoderBody);
      } else {
        throw Exception('Сервер повернув код: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Помилка зєднання: $e');
    }
  }

  // Універсальний метод для виконання GET-запитів з query-параметрами
  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    final Uri url = Uri.http(
      '$_host:$_port',
      '/$_publication/hs/$_serviceName$endpoint',
      queryParameters,
    );

    try {
      final response = await http
          .get(url, headers: _headers)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final decoderBody = utf8.decode(response.bodyBytes);

        if (decoderBody.isEmpty) {
          throw Exception('Сервер повернув порожню відповідь');
        }

        return jsonDecode(decoderBody);
      } else {
        throw Exception('Сервер повернув код: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Сервер не відповідає. Перевірте зєднання');
    } catch (e) {
      throw Exception('Помилка зєднання: $e');
    }
  }
}
