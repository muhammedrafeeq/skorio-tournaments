import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio dio;
  
  // Update this with your actual deployed backend URL
  static const String defaultBaseUrl = 'http://localhost:5000/api';

  ApiClient({String baseUrl = defaultBaseUrl}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    // Request/Response logging and JWT authorization attachment interceptors
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Token retrieval code will go here, e.g.:
        // final token = await secureStorage.read(key: 'jwt_token');
        // if (token != null) {
        //   options.headers['Authorization'] = 'Bearer $token';
        // }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        // Global error interceptor
        debugPrint("Dio Network Error: [${e.response?.statusCode}] ${e.message}");
        return handler.next(e);
      },
    ));
  }
}
