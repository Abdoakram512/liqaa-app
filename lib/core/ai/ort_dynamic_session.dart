import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

typedef _GetApiN = Pointer<Pointer<Void>> Function(Uint32 version);
typedef _GetApiD = Pointer<Pointer<Void>> Function(int version);
typedef _GetVersionN = Pointer<Utf8> Function();
typedef _GetVersionD = Pointer<Utf8> Function();

final class _OrtApiBase extends Struct {
  external Pointer<NativeFunction<_GetApiN>> getApi;
  external Pointer<NativeFunction<_GetVersionN>> getVersionString;
}

typedef _OrtGetApiBaseN = Pointer<_OrtApiBase> Function();
typedef _OrtGetApiBaseD = Pointer<_OrtApiBase> Function();

typedef _GetErrorMessageN = Pointer<Utf8> Function(Pointer<Void> status);
typedef _GetErrorMessageD = Pointer<Utf8> Function(Pointer<Void> status);
typedef _ReleaseStatusN = Void Function(Pointer<Void> status);
typedef _ReleaseStatusD = void Function(Pointer<Void> status);
typedef _CreateEnvN = Pointer<Void> Function(
    Uint32 level, Pointer<Utf8> logid, Pointer<Pointer<Void>> out);
typedef _CreateEnvD = Pointer<Void> Function(
    int level, Pointer<Utf8> logid, Pointer<Pointer<Void>> out);
typedef _CreateSessionOptsN = Pointer<Void> Function(Pointer<Pointer<Void>> out);
typedef _CreateSessionOptsD = Pointer<Void> Function(Pointer<Pointer<Void>> out);
typedef _SetIntraOpN = Pointer<Void> Function(Pointer<Void> opts, Int32 threads);
typedef _SetIntraOpD = Pointer<Void> Function(Pointer<Void> opts, int threads);
typedef _SetGraphOptN = Pointer<Void> Function(Pointer<Void> opts, Int32 level);
typedef _SetGraphOptD = Pointer<Void> Function(Pointer<Void> opts, int level);
typedef _ReleasePtrN = Void Function(Pointer<Void> ptr);
typedef _ReleasePtrD = void Function(Pointer<Void> ptr);
typedef _CreateSessionN = Pointer<Void> Function(
    Pointer<Void> env, Pointer<Void> path, Pointer<Void> opts, Pointer<Pointer<Void>> out);
typedef _CreateSessionD = Pointer<Void> Function(
    Pointer<Void> env, Pointer<Void> path, Pointer<Void> opts, Pointer<Pointer<Void>> out);
typedef _GetAllocatorN = Pointer<Void> Function(Pointer<Pointer<Void>> out);
typedef _GetAllocatorD = Pointer<Void> Function(Pointer<Pointer<Void>> out);
typedef _AllocatorFreeN = Pointer<Void> Function(Pointer<Void> alloc, Pointer<Void> ptr);
typedef _AllocatorFreeD = Pointer<Void> Function(Pointer<Void> alloc, Pointer<Void> ptr);
typedef _SessionGetCountN = Pointer<Void> Function(Pointer<Void> sess, Pointer<Size> out);
typedef _SessionGetCountD = Pointer<Void> Function(Pointer<Void> sess, Pointer<Size> out);
typedef _SessionGetNameN = Pointer<Void> Function(
    Pointer<Void> sess, Size index, Pointer<Void> alloc, Pointer<Pointer<Utf8>> out);
typedef _SessionGetNameD = Pointer<Void> Function(
    Pointer<Void> sess, int index, Pointer<Void> alloc, Pointer<Pointer<Utf8>> out);
typedef _CreateTensorAsOrtValueN = Pointer<Void> Function(
    Pointer<Void> alloc, Pointer<Int64> shape, Size shapeLen, Uint32 elemType, Pointer<Pointer<Void>> out);
typedef _CreateTensorAsOrtValueD = Pointer<Void> Function(
    Pointer<Void> alloc, Pointer<Int64> shape, int shapeLen, int elemType, Pointer<Pointer<Void>> out);
typedef _GetTensorMutableDataN = Pointer<Void> Function(
    Pointer<Void> val, Pointer<Pointer<Void>> out);
typedef _GetTensorMutableDataD = Pointer<Void> Function(
    Pointer<Void> val, Pointer<Pointer<Void>> out);
typedef _GetTensorTypeAndShapeInfoN = Pointer<Void> Function(
    Pointer<Void> val, Pointer<Pointer<Void>> out);
typedef _GetTensorTypeAndShapeInfoD = Pointer<Void> Function(
    Pointer<Void> val, Pointer<Pointer<Void>> out);
typedef _GetDimensionsCountN = Pointer<Void> Function(
    Pointer<Void> info, Pointer<Size> out);
typedef _GetDimensionsCountD = Pointer<Void> Function(
    Pointer<Void> info, Pointer<Size> out);
typedef _GetDimensionsN = Pointer<Void> Function(
    Pointer<Void> info, Pointer<Int64> dimValues, Size len);
typedef _GetDimensionsD = Pointer<Void> Function(
    Pointer<Void> info, Pointer<Int64> dimValues, int len);
typedef _RunN = Pointer<Void> Function(
  Pointer<Void> sess,
  Pointer<Void> runOpts,
  Pointer<Pointer<Utf8>> inputNames,
  Pointer<Pointer<Void>> inputs,
  Size inputLen,
  Pointer<Pointer<Utf8>> outputNames,
  Size outputNamesLen,
  Pointer<Pointer<Void>> outputs,
);
typedef _RunD = Pointer<Void> Function(
  Pointer<Void> sess,
  Pointer<Void> runOpts,
  Pointer<Pointer<Utf8>> inputNames,
  Pointer<Pointer<Void>> inputs,
  int inputLen,
  Pointer<Pointer<Utf8>> outputNames,
  int outputNamesLen,
  Pointer<Pointer<Void>> outputs,
);

/// Result of running a float32 tensor through an [OrtDynamicSession].
class OrtFloatTensorResult {
  final List<int> shape;
  final Float32List data;

  const OrtFloatTensorResult({
    required this.shape,
    required this.data,
  });
}

typedef _SetDllDirectoryWN = Int32 Function(Pointer<Utf16> lpPathName);
typedef _SetDllDirectoryWD = int Function(Pointer<Utf16> lpPathName);

/// Ensures Windows loads `sherpa_onnx`'s bundled ORT 1.28.2 + Sherpa C API DLLs cleanly.
class OrtRuntimeLoader {
  static DynamicLibrary? _ortLib;
  static String? _resolvedVersion;

  static String? get runtimeVersion => _resolvedVersion;

  static void ensureWindowsPreloaded() {
    if (!Platform.isWindows || _ortLib != null) return;
    final candidates = <String>[
      if (Platform.environment['LOCALAPPDATA'] != null)
        '${Platform.environment['LOCALAPPDATA']}\\Pub\\Cache\\hosted\\pub.dev\\sherpa_onnx_windows-2.0.3\\windows\\x64',
      r'E:\pub_cache\hosted\pub.dev\sherpa_onnx_windows-2.0.3\windows\x64',
    ];
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    candidates.insert(0, exeDir);

    for (final dir in candidates) {
      final ortDll = File('$dir\\onnxruntime.dll');
      if (ortDll.existsSync()) {
        try {
          final kernel32 = DynamicLibrary.open('kernel32.dll');
          final setDllDir = kernel32.lookupFunction<_SetDllDirectoryWN, _SetDllDirectoryWD>(
            'SetDllDirectoryW',
          );
          final dirPtr = dir.toNativeUtf16();
          try {
            setDllDir(dirPtr);
          } finally {
            calloc.free(dirPtr);
          }
        } catch (_) {}

        final shared = File('$dir\\onnxruntime_providers_shared.dll');
        if (shared.existsSync()) {
          DynamicLibrary.open(shared.path);
        }
        _ortLib = DynamicLibrary.open(ortDll.path);
        final sherpaCxx = File('$dir\\sherpa-onnx-cxx-api.dll');
        if (sherpaCxx.existsSync()) {
          DynamicLibrary.open(sherpaCxx.path);
        }
        final sherpaC = File('$dir\\sherpa-onnx-c-api.dll');
        if (sherpaC.existsSync()) {
          DynamicLibrary.open(sherpaC.path);
        }
        return;
      }
    }
  }

  static DynamicLibrary openOnnxRuntime() {
    if (_ortLib != null) return _ortLib!;
    if (Platform.isWindows) {
      ensureWindowsPreloaded();
      _ortLib ??= DynamicLibrary.open('onnxruntime.dll');
    } else if (Platform.isAndroid || Platform.isLinux) {
      _ortLib = DynamicLibrary.open('libonnxruntime.so');
    } else if (Platform.isMacOS || Platform.isIOS) {
      _ortLib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform for ONNX Runtime FFI: ${Platform.operatingSystem}');
    }
    return _ortLib!;
  }
}

/// Pure Dart FFI ONNX Runtime session reusing `sherpa_onnx`'s bundled ONNX Runtime (v1.28.2).
/// Supports quantized ONNX models including MatMulNBits (`model_q4f16.onnx`).
class OrtDynamicSession {
  static const int _ortApiVersion = 22;
  static const int _onnxTensorFloat = 1;

  final Pointer<Void> _env;
  final Pointer<Void> _opts;
  final Pointer<Void> _sess;
  final Pointer<Void> _alloc;
  final Pointer<Pointer<Utf8>> _inNamesPtr;
  final Pointer<Pointer<Utf8>> _outNamesPtr;

  final _GetErrorMessageD _getErr;
  final _ReleaseStatusD _relStatus;
  final _CreateTensorAsOrtValueD _createTensor;
  final _GetTensorMutableDataD _getTensorData;
  final _GetTensorTypeAndShapeInfoD _getShapeInfo;
  final _GetDimensionsCountD _getDimsCount;
  final _GetDimensionsD _getDims;
  final _RunD _run;
  final _ReleasePtrD _relSess;
  final _ReleasePtrD _relVal;
  final _ReleasePtrD _relInfo;
  final _ReleasePtrD _relOpts;
  final _ReleasePtrD _relEnv;

  final String inputName;
  final String outputName;
  final String runtimeVersion;
  bool _disposed = false;

  OrtDynamicSession._({
    required Pointer<Void> env,
    required Pointer<Void> opts,
    required Pointer<Void> sess,
    required Pointer<Void> alloc,
    required Pointer<Pointer<Utf8>> inNamesPtr,
    required Pointer<Pointer<Utf8>> outNamesPtr,
    required _GetErrorMessageD getErr,
    required _ReleaseStatusD relStatus,
    required _CreateTensorAsOrtValueD createTensor,
    required _GetTensorMutableDataD getTensorData,
    required _GetTensorTypeAndShapeInfoD getShapeInfo,
    required _GetDimensionsCountD getDimsCount,
    required _GetDimensionsD getDims,
    required _RunD run,
    required _ReleasePtrD relSess,
    required _ReleasePtrD relVal,
    required _ReleasePtrD relInfo,
    required _ReleasePtrD relOpts,
    required _ReleasePtrD relEnv,
    required this.inputName,
    required this.outputName,
    required this.runtimeVersion,
  })  : _env = env,
        _opts = opts,
        _sess = sess,
        _alloc = alloc,
        _inNamesPtr = inNamesPtr,
        _outNamesPtr = outNamesPtr,
        _getErr = getErr,
        _relStatus = relStatus,
        _createTensor = createTensor,
        _getTensorData = getTensorData,
        _getShapeInfo = getShapeInfo,
        _getDimsCount = getDimsCount,
        _getDims = getDims,
        _run = run,
        _relSess = relSess,
        _relVal = relVal,
        _relInfo = relInfo,
        _relOpts = relOpts,
        _relEnv = relEnv;

  static void _check(
    Pointer<Void> status,
    _GetErrorMessageD getErr,
    _ReleaseStatusD relStatus,
  ) {
    if (status != nullptr) {
      final msg = getErr(status).toDartString();
      relStatus(status);
      throw StateError('ONNX Runtime error: $msg');
    }
  }

  /// Opens an ONNX model from [modelPath] with [numThreads] intra-op threads.
  static OrtDynamicSession fromFile(String modelPath, {int numThreads = 2}) {
    if (!File(modelPath).existsSync()) {
      throw FileSystemException('ONNX model file does not exist', modelPath);
    }

    final ort = OrtRuntimeLoader.openOnnxRuntime();
    final base = ort.lookupFunction<_OrtGetApiBaseN, _OrtGetApiBaseD>('OrtGetApiBase')();
    final version = base.ref.getVersionString.asFunction<_GetVersionD>()().toDartString();
    OrtRuntimeLoader._resolvedVersion = version;

    final table = base.ref.getApi.asFunction<_GetApiD>()(_ortApiVersion);
    if (table == nullptr) {
      throw StateError('OrtGetApiBase->GetApi($_ortApiVersion) returned null (ORT v$version)');
    }

    // Verified vtable indices against ORT 1.28.2 / 1.29 headers
    final getErr = table[2].cast<NativeFunction<_GetErrorMessageN>>().asFunction<_GetErrorMessageD>();
    final relStatus = table[93].cast<NativeFunction<_ReleaseStatusN>>().asFunction<_ReleaseStatusD>();
    final createEnv = table[3].cast<NativeFunction<_CreateEnvN>>().asFunction<_CreateEnvD>();
    final createOpts = table[10].cast<NativeFunction<_CreateSessionOptsN>>().asFunction<_CreateSessionOptsD>();
    final setGraphOpt = table[23].cast<NativeFunction<_SetGraphOptN>>().asFunction<_SetGraphOptD>();
    final setIntra = table[24].cast<NativeFunction<_SetIntraOpN>>().asFunction<_SetIntraOpD>();
    final createSess = table[7].cast<NativeFunction<_CreateSessionN>>().asFunction<_CreateSessionD>();
    final getAlloc = table[78].cast<NativeFunction<_GetAllocatorN>>().asFunction<_GetAllocatorD>();
    final allocFree = table[76].cast<NativeFunction<_AllocatorFreeN>>().asFunction<_AllocatorFreeD>();
    final getInCount = table[30].cast<NativeFunction<_SessionGetCountN>>().asFunction<_SessionGetCountD>();
    final getOutCount = table[31].cast<NativeFunction<_SessionGetCountN>>().asFunction<_SessionGetCountD>();
    final getInName = table[36].cast<NativeFunction<_SessionGetNameN>>().asFunction<_SessionGetNameD>();
    final getOutName = table[37].cast<NativeFunction<_SessionGetNameN>>().asFunction<_SessionGetNameD>();
    final createTensor = table[48].cast<NativeFunction<_CreateTensorAsOrtValueN>>().asFunction<_CreateTensorAsOrtValueD>();
    final getTensorData = table[51].cast<NativeFunction<_GetTensorMutableDataN>>().asFunction<_GetTensorMutableDataD>();
    final getShapeInfo = table[65].cast<NativeFunction<_GetTensorTypeAndShapeInfoN>>().asFunction<_GetTensorTypeAndShapeInfoD>();
    final getDimsCount = table[61].cast<NativeFunction<_GetDimensionsCountN>>().asFunction<_GetDimensionsCountD>();
    final getDims = table[62].cast<NativeFunction<_GetDimensionsN>>().asFunction<_GetDimensionsD>();
    final run = table[9].cast<NativeFunction<_RunN>>().asFunction<_RunD>();
    final relEnv = table[92].cast<NativeFunction<_ReleasePtrN>>().asFunction<_ReleasePtrD>();
    final relSess = table[95].cast<NativeFunction<_ReleasePtrN>>().asFunction<_ReleasePtrD>();
    final relVal = table[96].cast<NativeFunction<_ReleasePtrN>>().asFunction<_ReleasePtrD>();
    final relInfo = table[99].cast<NativeFunction<_ReleasePtrN>>().asFunction<_ReleasePtrD>();
    final relOpts = table[100].cast<NativeFunction<_ReleasePtrN>>().asFunction<_ReleasePtrD>();

    final pEnv = calloc<Pointer<Void>>();
    final pOpts = calloc<Pointer<Void>>();
    final pSess = calloc<Pointer<Void>>();
    final pAlloc = calloc<Pointer<Void>>();

    Pointer<Void> envPtr = nullptr;
    Pointer<Void> optsPtr = nullptr;
    Pointer<Void> sessPtr = nullptr;

    try {
      final logId = 'liqaa_ort'.toNativeUtf8();
      try {
        _check(createEnv(3 /* ORT_LOGGING_LEVEL_ERROR */, logId, pEnv), getErr, relStatus);
        envPtr = pEnv.value;
      } finally {
        calloc.free(logId);
      }

      _check(createOpts(pOpts), getErr, relStatus);
      optsPtr = pOpts.value;
      _check(setIntra(optsPtr, numThreads), getErr, relStatus);
      _check(setGraphOpt(optsPtr, 99 /* ORT_ENABLE_ALL */), getErr, relStatus);

      final Pointer<Void> pathPtr = Platform.isWindows
          ? modelPath.toNativeUtf16().cast<Void>()
          : modelPath.toNativeUtf8().cast<Void>();
      try {
        _check(createSess(envPtr, pathPtr, optsPtr, pSess), getErr, relStatus);
        sessPtr = pSess.value;
      } finally {
        calloc.free(pathPtr);
      }

      _check(getAlloc(pAlloc), getErr, relStatus);
      final allocPtr = pAlloc.value;

      final pCount = calloc<Size>();
      final pName = calloc<Pointer<Utf8>>();
      late final String inName;
      late final String outName;
      try {
        _check(getInCount(sessPtr, pCount), getErr, relStatus);
        if (pCount.value < 1) {
          throw const FormatException('ONNX model exposes 0 inputs.');
        }
        _check(getInName(sessPtr, 0, allocPtr, pName), getErr, relStatus);
        inName = pName.value.toDartString();
        _check(allocFree(allocPtr, pName.value.cast()), getErr, relStatus);

        _check(getOutCount(sessPtr, pCount), getErr, relStatus);
        if (pCount.value < 1) {
          throw const FormatException('ONNX model exposes 0 outputs.');
        }
        _check(getOutName(sessPtr, 0, allocPtr, pName), getErr, relStatus);
        outName = pName.value.toDartString();
        _check(allocFree(allocPtr, pName.value.cast()), getErr, relStatus);
      } finally {
        calloc.free(pCount);
        calloc.free(pName);
      }

      final inNamesPtr = calloc<Pointer<Utf8>>(1)..[0] = inName.toNativeUtf8();
      final outNamesPtr = calloc<Pointer<Utf8>>(1)..[0] = outName.toNativeUtf8();

      return OrtDynamicSession._(
        env: envPtr,
        opts: optsPtr,
        sess: sessPtr,
        alloc: allocPtr,
        inNamesPtr: inNamesPtr,
        outNamesPtr: outNamesPtr,
        getErr: getErr,
        relStatus: relStatus,
        createTensor: createTensor,
        getTensorData: getTensorData,
        getShapeInfo: getShapeInfo,
        getDimsCount: getDimsCount,
        getDims: getDims,
        run: run,
        relSess: relSess,
        relVal: relVal,
        relInfo: relInfo,
        relOpts: relOpts,
        relEnv: relEnv,
        inputName: inName,
        outputName: outName,
        runtimeVersion: version,
      );
    } catch (_) {
      if (sessPtr != nullptr) relSess(sessPtr);
      if (optsPtr != nullptr) relOpts(optsPtr);
      if (envPtr != nullptr) relEnv(envPtr);
      rethrow;
    } finally {
      calloc.free(pEnv);
      calloc.free(pOpts);
      calloc.free(pSess);
      calloc.free(pAlloc);
    }
  }

  /// Runs float32 inference for a 1D/ND tensor shaped by [inputShape] and returns output tensor data & shape.
  OrtFloatTensorResult runFloat32(Float32List inputData, List<int> inputShape) {
    if (_disposed) {
      throw StateError('OrtDynamicSession has already been disposed.');
    }

    final shapePtr = calloc<Int64>(inputShape.length);
    for (int i = 0; i < inputShape.length; i++) {
      shapePtr[i] = inputShape[i];
    }

    final pInVal = calloc<Pointer<Void>>();
    final pData = calloc<Pointer<Void>>();
    final inArr = calloc<Pointer<Void>>(1);
    final outArr = calloc<Pointer<Void>>(1)..[0] = nullptr;
    final pInfo = calloc<Pointer<Void>>();
    final pDimsN = calloc<Size>();
    final pOutData = calloc<Pointer<Void>>();

    Pointer<Void> inValPtr = nullptr;
    Pointer<Void> outValPtr = nullptr;
    Pointer<Void> infoPtr = nullptr;
    Pointer<Int64>? outDimsPtr;

    try {
      _check(
        _createTensor(_alloc, shapePtr, inputShape.length, _onnxTensorFloat, pInVal),
        _getErr,
        _relStatus,
      );
      inValPtr = pInVal.value;

      _check(_getTensorData(inValPtr, pData), _getErr, _relStatus);
      pData.value.cast<Float>().asTypedList(inputData.length).setAll(0, inputData);

      inArr[0] = inValPtr;
      _check(
        _run(_sess, nullptr, _inNamesPtr, inArr, 1, _outNamesPtr, 1, outArr),
        _getErr,
        _relStatus,
      );
      outValPtr = outArr[0];

      _check(_getShapeInfo(outValPtr, pInfo), _getErr, _relStatus);
      infoPtr = pInfo.value;
      _check(_getDimsCount(infoPtr, pDimsN), _getErr, _relStatus);

      final int rank = pDimsN.value;
      outDimsPtr = calloc<Int64>(rank);
      _check(_getDims(infoPtr, outDimsPtr, rank), _getErr, _relStatus);

      final outShape = <int>[];
      int totalElements = 1;
      for (int i = 0; i < rank; i++) {
        final d = outDimsPtr[i];
        outShape.add(d);
        totalElements *= d;
      }

      _check(_getTensorData(outValPtr, pOutData), _getErr, _relStatus);
      final Float32List copiedOut = Float32List.fromList(
        pOutData.value.cast<Float>().asTypedList(totalElements),
      );

      return OrtFloatTensorResult(shape: outShape, data: copiedOut);
    } finally {
      if (infoPtr != nullptr) _relInfo(infoPtr);
      if (inValPtr != nullptr) _relVal(inValPtr);
      if (outValPtr != nullptr) _relVal(outValPtr);
      if (outDimsPtr != null) calloc.free(outDimsPtr);
      calloc.free(shapePtr);
      calloc.free(pInVal);
      calloc.free(pData);
      calloc.free(inArr);
      calloc.free(outArr);
      calloc.free(pInfo);
      calloc.free(pDimsN);
      calloc.free(pOutData);
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    calloc.free(_inNamesPtr[0]);
    calloc.free(_outNamesPtr[0]);
    calloc.free(_inNamesPtr);
    calloc.free(_outNamesPtr);
    _relSess(_sess);
    _relOpts(_opts);
    _relEnv(_env);
  }
}
