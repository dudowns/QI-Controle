class Result<T> {
  final T? _data;
  final String? _error;
  final bool _isSuccess;
  Result._(this._data, this._error, this._isSuccess);
  factory Result.success(T data) => Result._(data, null, true);
  factory Result.failure(String error) => Result._(null, error, false);
  bool get isSuccess => _isSuccess;
  bool get isFailure => !_isSuccess;
  T get data { if (!isSuccess) throw Exception('Cannot get data from failed result'); return _data as T; }
  String get error { if (isSuccess) throw Exception('Cannot get error from successful result'); return _error!; }
  T? get dataOrNull => _data;
  String? get errorOrNull => _error;
}
