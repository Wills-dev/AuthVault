import 'package:dio/dio.dart';

class BiometricApi {
  BiometricApi(this.dio);
  final Dio dio;
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
    String token,
    CancelToken cancel,
  ) async {
    final result = await dio.post<Map<String, dynamic>>(
      path,
      data: body,
      options: Options(headers: {'X-MFA-Token': token}),
      cancelToken: cancel,
    );
    return result.data ?? {};
  }
}
