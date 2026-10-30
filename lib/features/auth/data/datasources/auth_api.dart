import 'package:dio/dio.dart';

class AuthApi {
  AuthApi(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> submit(
    String path,
    Map<String, String> input,
    CancelToken cancel,
  ) async {
    final response = await dio.post<Map<String, dynamic>>(
      path,
      data: input,
      cancelToken: cancel,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> status(
    String id,
    String token,
    CancelToken cancel,
  ) async {
    final response = await dio.get<Map<String, dynamic>>(
      '/auth/pending/${Uri.encodeComponent(id)}',
      options: Options(headers: {'X-MFA-Token': token}),
      cancelToken: cancel,
    );
    return response.data ?? <String, dynamic>{};
  }

  Future<void> revoke(String id, String token, CancelToken cancel) =>
      dio.delete<void>(
        '/auth/pending/${Uri.encodeComponent(id)}',
        options: Options(headers: {'X-MFA-Token': token}),
        cancelToken: cancel,
      );
}
