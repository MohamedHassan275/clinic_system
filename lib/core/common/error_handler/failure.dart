import 'app_logger.dart';

enum TypeMsg { ok, error, warning }

class Failure {
  final int code;
  final String message;
  final TypeMsg type;

  const Failure(this.code, this.message, [this.type = TypeMsg.error]);

  @override
  String toString() => 'Failure{code: $code, message: $message, type: $type}';

  void printInfo(String from) {
    AppLogger.error('from => $from : Failure{code: $code, message: $message}');
  }
}
