import 'dart:convert';
import 'dart:typed_data';

class GlbPrimitive {
  final Float32List positions;
  final Uint16List indices;
  final double r;
  final double g;
  final double b;
  final double a;

  const GlbPrimitive({
    required this.positions,
    required this.indices,
    required this.r,
    required this.g,
    required this.b,
    required this.a,
  });
}

class GlbModel {
  final List<GlbPrimitive> primitives;

  const GlbModel({required this.primitives});
}

GlbModel parseGlb(ByteData data) {
  final header = _GlbHeader._read(data);
  if (header.magic != 0x46546C67) {
    throw FormatException('Not a GLB file (bad magic)');
  }

  String? jsonStr;
  Uint8List? bin;

  int offset = 12;
  while (offset < data.lengthInBytes) {
    final chunkLen = data.getUint32(offset, Endian.little);
    final chunkType = data.getUint32(offset + 4, Endian.little);
    final chunkData = data.buffer.asUint8List(offset + 8, chunkLen);

    if (chunkType == 0x4E4F534A) {
      jsonStr = utf8.decode(chunkData);
    } else if (chunkType == 0x004E4942) {
      bin = chunkData;
    }

    offset += 8 + chunkLen;
  }

  if (jsonStr == null) throw FormatException('No JSON chunk in GLB');
  if (bin == null) throw FormatException('No BIN chunk in GLB');

  return _parseGltf(jsonStr, bin);
}

GlbModel _parseGltf(String jsonStr, Uint8List bin) {
  final Map<String, dynamic> root = json.decode(jsonStr) as Map<String, dynamic>;
  final List<dynamic>? accessors = root['accessors'] as List<dynamic>?;
  final List<dynamic>? bufferViews = root['bufferViews'] as List<dynamic>?;
  final List<dynamic>? meshes = root['meshes'] as List<dynamic>?;
  final List<dynamic>? materials = root['materials'] as List<dynamic>?;
  final List<dynamic>? nodes = root['nodes'] as List<dynamic>?;

  if (accessors == null || bufferViews == null || meshes == null) {
    throw FormatException('GLTF missing required arrays');
  }

  // Build mesh-index → node transform mapping
  final meshScale = <int, double>{};
  if (nodes != null) {
    for (final node in nodes) {
      final n = node as Map<String, dynamic>;
      final meshIdx = n['mesh'] as int?;
      if (meshIdx == null) continue;
      final scaleArr = n['scale'] as List<dynamic>?;
      if (scaleArr != null && scaleArr.length >= 3) {
        // Use average of x,y,z scale
        final sx = (scaleArr[0] as num).toDouble();
        final sy = (scaleArr[1] as num).toDouble();
        final sz = (scaleArr[2] as num).toDouble();
        meshScale[meshIdx] = (sx + sy + sz) / 3.0;
      }
    }
  }

  final primitives = <GlbPrimitive>[];

  for (var meshIdx = 0; meshIdx < meshes.length; meshIdx++) {
    final mesh = meshes[meshIdx] as Map<String, dynamic>;
    final meshPrimitives = mesh['primitives'] as List<dynamic>;

    // Get node scale for this mesh (default 1.0)
    final nodeScale = meshScale[meshIdx] ?? 1.0;

    for (final prim in meshPrimitives) {
      final p = prim as Map<String, dynamic>;
      final attrs = p['attributes'] as Map<String, dynamic>;
      final indicesIdx = p['indices'] as int?;
      final materialIdx = p['material'] as int?;

      final posAccessorIdx = attrs['POSITION'] as int;
      final posAccessor = accessors[posAccessorIdx] as Map<String, dynamic>;
      final posData = _readAccessorData(posAccessor, bufferViews, bin);
      final vertexCount = posData.length ~/ 3;
      final posFloat32 = Float32List(vertexCount * 3);
      for (var i = 0; i < vertexCount; i++) {
        posFloat32[i * 3] = posData[i * 3] * nodeScale;
        posFloat32[i * 3 + 1] = posData[i * 3 + 1] * nodeScale;
        posFloat32[i * 3 + 2] = posData[i * 3 + 2] * nodeScale;
      }

      Uint16List indices;
      if (indicesIdx != null) {
        final idxAccessor = accessors[indicesIdx] as Map<String, dynamic>;
        final compType = (idxAccessor['componentType'] as num).toInt();
        final idxCount = (idxAccessor['count'] as num).toInt();
        final bvIdx = (idxAccessor['bufferView'] as num).toInt();
        final bv = bufferViews[bvIdx] as Map<String, dynamic>;
        final bvOff = (bv['byteOffset'] as num?)?.toInt() ?? 0;
        final accOff = (idxAccessor['byteOffset'] as num?)?.toInt() ?? 0;
        final byteOff = bvOff + accOff;
        final rawSlice = Uint8List.view(bin.buffer, byteOff);

        if (compType == 5125) {
          final raw = Uint32List.view(rawSlice.buffer, rawSlice.offsetInBytes, idxCount);
          indices = Uint16List(idxCount);
          for (var i = 0; i < idxCount; i++) {
            indices[i] = raw[i] & 0xFFFF;
          }
        } else {
          indices = Uint16List.view(rawSlice.buffer, rawSlice.offsetInBytes, idxCount);
        }
      } else {
        final count = posFloat32.length ~/ 3;
        indices = Uint16List(count);
        for (var i = 0; i < count; i++) {
          indices[i] = i;
        }
      }

      // Extract color from material; fallback green if texture-based
      double r = 0.5, g = 0.7, b = 0.3, a = 1.0;
      bool hasTexture = false;
      if (materialIdx != null && materials != null && materialIdx < materials.length) {
        final mat = materials[materialIdx] as Map<String, dynamic>;
        final pbr = mat['pbrMetallicRoughness'] as Map<String, dynamic>?;
        if (pbr != null) {
          hasTexture = pbr['baseColorTexture'] != null;
          final colorFactor = pbr['baseColorFactor'] as List<dynamic>?;
          if (!hasTexture && colorFactor != null && colorFactor.length >= 3) {
            r = (colorFactor[0] as num).toDouble();
            g = (colorFactor[1] as num).toDouble();
            b = (colorFactor[2] as num).toDouble();
            a = colorFactor.length > 3 ? (colorFactor[3] as num).toDouble() : 1.0;
          }
        }
      }

      primitives.add(GlbPrimitive(
        positions: posFloat32,
        indices: indices,
        r: r,
        g: g,
        b: b,
        a: a,
      ));
    }
  }

  return GlbModel(primitives: primitives);
}

Float64List _readAccessorData(
  Map<String, dynamic> accessor,
  List<dynamic> bufferViews,
  Uint8List bin,
) {
  final bvIdx = (accessor['bufferView'] as num).toInt();
  final bv = bufferViews[bvIdx] as Map<String, dynamic>;
  final bvOffset = (bv['byteOffset'] as num?)?.toInt() ?? 0;
  final bvLength = (bv['byteLength'] as num).toInt();
  final accOffset = (accessor['byteOffset'] as num?)?.toInt() ?? 0;
  final byteOffset = bvOffset + accOffset;

  final compType = (accessor['componentType'] as num).toInt();
  final typeStr = accessor['type'] as String;
  final count = (accessor['count'] as num).toInt();

  final numComponents = _typeComponentCount(typeStr);
  final compByteSize = _componentByteSize(compType);

  final rawBytes = bin.sublist(byteOffset, byteOffset + bvLength);
  final result = Float64List(count * numComponents);

  for (var i = 0; i < count; i++) {
    for (var c = 0; c < numComponents; c++) {
      final bytePos = i * numComponents * compByteSize + c * compByteSize;
      double val;
      if (compType == 5126) {
        val = ByteData.sublistView(rawBytes).getFloat32(bytePos, Endian.little).toDouble();
      } else if (compType == 5123) {
        val = ByteData.sublistView(rawBytes).getUint16(bytePos, Endian.little).toDouble();
      } else if (compType == 5125) {
        val = ByteData.sublistView(rawBytes).getUint32(bytePos, Endian.little).toDouble();
      } else if (compType == 5120) {
        val = ByteData.sublistView(rawBytes).getInt8(bytePos).toDouble();
      } else if (compType == 5121) {
        val = ByteData.sublistView(rawBytes).getUint8(bytePos).toDouble();
      } else if (compType == 5122) {
        val = ByteData.sublistView(rawBytes).getInt16(bytePos, Endian.little).toDouble();
      } else {
        val = 0.0;
      }
      result[i * numComponents + c] = val;
    }
  }

  return result;
}

int _typeComponentCount(String type) {
  switch (type) {
    case 'SCALAR': return 1;
    case 'VEC2': return 2;
    case 'VEC3': return 3;
    case 'VEC4': return 4;
    case 'MAT2': return 4;
    case 'MAT3': return 9;
    case 'MAT4': return 16;
    default: return 3;
  }
}

int _componentByteSize(int componentType) {
  switch (componentType) {
    case 5120: return 1; // BYTE
    case 5121: return 1; // UNSIGNED_BYTE
    case 5122: return 2; // SHORT
    case 5123: return 2; // UNSIGNED_SHORT
    case 5125: return 4; // UNSIGNED_INT
    case 5126: return 4; // FLOAT
    default: return 4;
  }
}

class _GlbHeader {
  final int magic;
  final int version;
  final int length;

  _GlbHeader._(this.magic, this.version, this.length);

  static _GlbHeader _read(ByteData data) {
    return _GlbHeader._(
      data.getUint32(0, Endian.little),
      data.getUint32(4, Endian.little),
      data.getUint32(8, Endian.little),
    );
  }
}
