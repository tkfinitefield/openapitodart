import 'package:dart_style/dart_style.dart';
import 'package:yaml/yaml.dart';

final formatter = new DartFormatter();

String trimPath(String s) {
  final ind = s.indexOf('#/components/schemas/');
  if (ind < 0) {
    return s;
  }
  return s.substring(ind + '#/components/schemas/'.length);
}

class Tag {
  final String name;
  final String description;

  Tag({
    required this.name,
    required this.description,
  });

  factory Tag.fromMap(YamlMap m) {
    return Tag(name: m['name'], description: m['description']);
  }
}

class Server {
  final String url;
  Server({
    required this.url,
  });

  factory Server.fromMap(YamlMap m) {
    return Server(url: m['url']);
  }
}

class Content {
  final String? mediaType;
  final String? schemaRef;
  final Component? component;
  final List<Property>? properties;

  Content({
    required this.mediaType,
    required this.schemaRef,
    required this.component,
    required this.properties,
  });

  factory Content.fromMap(YamlMap m) {
    if (m['properties'] != null) {
      return Content(
        mediaType: null,
        schemaRef: null,
        component: null,
        properties: (m['properties'] as YamlMap?)
                ?.map((key, value) => MapEntry<String, Property>(
                    key, Property.fromMap(key, value)))
                .values
                .toList() ??
            [],
      );
    }
    final mediaType = m.containsKey('application/json')
        ? 'application/json'
        : 'multipart/form-data';
    final c = trimPath(m[mediaType]['schema'][r'$ref']);
    return Content(
      mediaType: mediaType,
      schemaRef: m[mediaType]['schema'][r'$ref'],
      component: components[c]!,
      properties: null,
    );
  }
}

final components = Map<String, Component>();

class Component {
  final String name;
  final String? xImplements;
  final String? xExtends;
  final List<String> requireds;
  final List<Property> properties;
  final List<XCalculateProperty> xCalculateProperties;

  String get dartType => name.toUpperCamel();
  String get pythonType => name.toUpperCamel();

  Component({
    required this.name,
    required this.xImplements,
    required this.xExtends,
    required this.requireds,
    required this.properties,
    required this.xCalculateProperties,
  });

  factory Component.fromMap(String name, YamlMap m, bool withRef) {
    var component = Component(
      name: name,
      xImplements: m['x-implements'],
      xExtends: m['x-extends'],
      requireds:
          (m['required'] as YamlList?)?.map((e) => e as String).toList() ?? [],
      properties: (m['properties'] as YamlMap?)
              ?.map((key, value) =>
                  MapEntry<String, Property>(key, Property.fromMap(key, value)))
              .values
              .toList() ??
          [],
      xCalculateProperties: (m['x-calculate-properties'] as YamlMap?)
              ?.map((key, value) => MapEntry<String, XCalculateProperty>(
                  key, XCalculateProperty.fromMap(key, value)))
              .values
              .toList() ??
          [],
    );
    if (withRef && m[r'$ref'] != null) {
      final t = trimPath(m[r'$ref']);
      final excepts = m['x-excepts'] == null
          ? []
          : (m['x-excepts'] as YamlList).map((e) => e.toString()).toList();
      final c = components[t];
      if (c == null) {
        throw '$t does not have corresponding component.';
      }
      component = Component(
        name: name,
        xImplements: m['x-implements'],
        xExtends: m['x-extends'],
        requireds: c.requireds..addAll(component.requireds),
        properties:
            c.properties.where((e) => !excepts.contains(e.name)).toList()
              ..addAll(component.properties),
        xCalculateProperties: c.xCalculateProperties
            .where((e) => !excepts.contains(e.name))
            .toList()
          ..addAll(component.xCalculateProperties),
      );
    }
    components[name] = component;
    return component;
  }
}

extension StringExtension on String {
  String get dartTypeDefaultValue {
    if (this.endsWith('?')) {
      return "null";
    } else if (this.startsWith('List<')) {
      return "[]";
    } else if (this == 'String') {
      return "''";
    } else if (this == 'int') {
      return "0";
    } else if (this == 'double') {
      return "0.0";
    } else if (this == 'bool') {
      return "false";
    } else if (this == 'DateTime') {
      return "DateTime.fromMicrosecondsSinceEpoch(0)";
    } else if (this == 'Uint8List') {
      return "Uint8List(0)";
    }
    return "$this.zero";
  }

  String get pythonTypeDefaultValue {
    if (this.startsWith('Optional')) {
      return "None";
    } else if (this.startsWith('List[')) {
      return "[]";
    } else if (this == 'str') {
      return "''";
    } else if (this == 'int') {
      return "0";
    } else if (this == 'float') {
      return "0.0";
    } else if (this == 'bool') {
      return "False";
    }
    throw 'Unknown default value';
  }

  bool get isListType {
    return this.startsWith('List<');
  }

  bool get isObjectType {
    if (this == 'String' ||
        this == 'int' ||
        this == 'double' ||
        this == 'bool') {
      return false;
    }
    return true;
  }

  String toLowerCamel() {
    if (this.contains('_')) {
      final s = this.toLowerCase();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (s[i] == '_') {
          i++;
          buf.write(s[i].toUpperCase());
          continue;
        }
        buf.write(s[i]);
      }
      return buf.toString();
    }
    return this[0].toLowerCase() + this.substring(1);
  }

  String toUpperCamel() {
    if (this.contains('_')) {
      final s = this.toLowerCase();
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (s[i] == '_') {
          i++;
          buf.write(s[i].toUpperCase());
        } else if (i == 0) {
          buf.write(s[i].toUpperCase());
        } else {
          buf.write(s[i]);
        }
      }
      return buf.toString();
    }
    return this[0].toUpperCase() + this.substring(1);
  }

  String toSnake() {
    if (this.contains('_')) {
      return this.toLowerCase();
    }
    final buf = StringBuffer();
    for (var i = 0; i < this.length; i++) {
      if (i == 0) {
        buf.write(this[i].toLowerCase());
      } else if (this[i].toUpperCase() == this[i]) {
        buf.write('_' + this[i].toLowerCase());
      } else {
        buf.write(this[i]);
      }
    }
    return buf.toString();
  }
}

String getDartType(String type, String? format, bool nullable) {
  if (type == 'string') {
    if (format == 'date-time') {
      return nullable ? 'int?' : 'int';
      //return nullable ? 'DateTime?' : 'DateTime';
    } else if (format == 'binary') {
      return nullable ? 'Uint8List?' : 'Uint8List';
    }
    return nullable ? 'String?' : 'String';
  } else if (type == 'integer') {
    return nullable ? 'int?' : 'int';
  } else if (type == 'number') {
    return nullable ? 'double?' : 'double';
  } else if (type == 'boolean') {
    return nullable ? 'bool?' : 'bool';
  }
  throw '$type, $format, $nullable';
}

String getPythonType(String type, String? format, bool nullable) {
  if (type == 'string') {
    if (format == 'date-time') {
      return nullable ? 'Optional[int]' : 'int';
      //return nullable ? 'Optional[datetime]' : 'datetime';
    }
    return nullable ? 'Optional[str]' : 'str';
  } else if (type == 'integer') {
    return nullable ? 'Optional[int]' : 'int';
  } else if (type == 'number') {
    return nullable ? 'Optional[float]' : 'float';
  } else if (type == 'boolean') {
    return nullable ? 'Optional[bool]' : 'bool';
  }
  throw '$type, $format, $nullable';
}

class Property {
  final String name;
  final String? type;
  final String? format;
  final String? ref;
  final String? itemsType;
  final String? itemsFormat;
  final bool itemsNullable;
  final String? itemsRef;
  final bool nullable;
  final int? maxLength;
  final int? minLength;
  final String? pattern;
  final String? title;
  final String? description;

  String dartType(OpenApi openApi) {
    if (ref != null) {
      return openApi.getComponentFromRef(ref!).dartType + (nullable ? '?' : '');
    } else if (type == 'array') {
      if (itemsRef != null) {
        final t = openApi.getComponentFromRef(itemsRef!).dartType;
        return 'List<${itemsNullable ? t + '?' : t}>' + (nullable ? '?' : '');
      } else {
        return 'List<${getDartType(itemsType!, itemsFormat, itemsNullable)}>' +
            (nullable ? '?' : '');
      }
    }
    return getDartType(type!, format, nullable);
  }

  String pythonType(OpenApi openApi) {
    if (ref != null) {
      final t = openApi.getComponentFromRef(ref!).pythonType;
      if (nullable) return 'Optional[$t]';
      return t;
    } else if (type == 'array') {
      if (itemsRef != null) {
        final u = openApi.getComponentFromRef(itemsRef!).pythonType;
        final t = 'List[${itemsNullable ? "Optional[$u]" : u}]';
        if (nullable) return 'Optional[$t]';
        return t;
      } else {
        final t =
            'List[${getPythonType(itemsType!, itemsFormat, itemsNullable)}]';
        if (nullable) return 'Optional[$t]';
        return t;
      }
    }
    return getPythonType(type!, format, nullable);
  }

  String dartListBaseType(OpenApi openApi) {
    if (itemsRef != null) {
      return openApi.getComponentFromRef(itemsRef!).dartType;
    } else {
      return getDartType(itemsType!, itemsFormat, itemsNullable);
    }
  }

  String get dartFieldName => name.toLowerCamel();
  String get jsonFieldName => name.toSnake();
  String get pythonFieldName => jsonFieldName;
  bool get isListType => type == 'array';
  bool get isObjectType => ref != null;
  //bool get isDateTime => format == 'date-time';
  bool get isDateTime => false; // format == 'date-time';
  bool get isBinary => format == 'binary';

  Property({
    required this.name,
    required this.type,
    required this.format,
    required this.ref,
    required this.itemsType,
    required this.itemsFormat,
    required this.itemsNullable,
    required this.itemsRef,
    required this.nullable,
    required this.maxLength,
    required this.minLength,
    required this.pattern,
    required this.title,
    required this.description,
  });

  factory Property.fromMap(String name, YamlMap m) {
    return Property(
      name: name,
      type: m['type'],
      format: m['format'],
      ref: m[r'$ref'],
      itemsType: m['items'] == null ? null : m['items']['type'],
      itemsFormat: m['items'] == null ? null : m['items']['format'],
      itemsNullable:
          m['items'] == null ? false : m['items']['nullable'] ?? false,
      itemsRef: m['items'] == null ? null : m['items'][r'$ref'],
      nullable: m['nullable'] ?? false,
      maxLength: m['maxLength'],
      minLength: m['minLength'],
      pattern: m['pattern'],
      title: m['title'],
      description: m['description'],
    );
  }
}

class XCalculateProperty {
  final String name;
  final String type;
  final String? format;
  final String _calculate;
  final bool nullable;

  String get dartType => getDartType(type, format, nullable);
  String get dartFieldName => name.toLowerCamel();
  String get dartCalculate =>
      _calculate.split(RegExp('\b')).map((e) => e.toLowerCamel()).join('');

  XCalculateProperty({
    required this.name,
    required this.type,
    required this.format,
    required this.nullable,
    required String calculate,
  }) : _calculate = calculate;

  factory XCalculateProperty.fromMap(String name, YamlMap m) {
    return XCalculateProperty(
      name: name,
      type: m['type'],
      format: m['format'],
      calculate: m['calculate'],
      nullable: m['nullable'] ?? false,
    );
  }
}

class RequestBody {
  final String description;
  final Content content;

  RequestBody({
    required this.description,
    required this.content,
  });

  factory RequestBody.fromMap(YamlMap m) {
    return RequestBody(
      description: m['description'] ?? '',
      content: Content.fromMap(m['content']),
    );
  }
}

class Response {
  final int code;
  final String description;
  final Component? component;
  final bool isBinary;

  Response({
    required this.code,
    required this.description,
    required this.component,
    required this.isBinary,
  });

  factory Response.fromMap(int code, YamlMap m) {
    if (m['content'] == null) {
      return Response(
        code: code,
        description: m['description'],
        component: null,
        isBinary: false,
      );
    }
    if (m['content']['application/octet-stream'] != null) {
      return Response(
        code: code,
        description: m['description'],
        component: null,
        isBinary: true,
      );
    }
    final c = trimPath(m['content']['application/json']['schema'][r'$ref']);
    return Response(
      code: code,
      description: m['description'],
      component: components[c]!,
      isBinary: false,
    );
  }
}

class Parameter {
  final String inParam;
  final String name;
  final String description;
  final bool requiredParam;
  final Component? component;
  final Property? property;

  Parameter({
    required this.inParam,
    required this.name,
    required this.description,
    required this.requiredParam,
    required this.component,
    required this.property,
  });

  factory Parameter.fromMap(YamlMap m) {
    final c = trimPath(m['schema'][r'$ref'] ?? '');
    // Required if a parameter is in path.
    final requiredParam = (m['required'] ?? false) || m['in'] == 'path';
    return Parameter(
      inParam: m['in'],
      name: m['name'],
      description: m['description'] ?? '',
      requiredParam: requiredParam,
      component: c.isEmpty ? null : components[c]!,
      property: c.isNotEmpty
          ? null
          : Property(
              name: m['name'],
              type: m['schema']['type'],
              format: m['schema']['format'],
              ref: null,
              itemsType: m['schema']['items'] == null
                  ? null
                  : m['schema']['items']['type'],
              itemsFormat: m['schema']['items'] == null
                  ? null
                  : m['schema']['items']['format'],
              itemsNullable: m['schema']['items'] == null
                  ? false
                  : m['schema']['items']['nullable'] ?? false,
              itemsRef: m['schema']['items'] == null
                  ? null
                  : m['schema']['items'][r'$ref'],
              nullable: !requiredParam,
              maxLength: m['schema']['maxLength'],
              minLength: m['schema']['minLength'],
              pattern: m['schema']['pattern'],
              title: m['schema']['title'],
              description: m['schema']['description'],
            ),
    );
  }
}

class HttpMethod {
  final String path;
  final String method;
  final bool xExclude;
  final List<String> tags;
  final String summary;
  final String operationId;
  final RequestBody? requestBody;
  final List<Parameter> parameters;

  String get pathWithReplacedParameter {
    var s = this.path;
    for (final p in parameters) {
      if (p.inParam == 'path') {
        if (!path.contains('{${p.name}}')) {
          throw 'path parameter not compatible: path: $path, parameter: ${p.name}';
        }
        s = s.replaceAll('{${p.name}}', '\$${p.name.toLowerCamel()}');
      }
    }
    return s;
  }

  List<Parameter> get queryParameters =>
      parameters.where((p) => p.inParam == 'query').toList();

  final List<Response> responses;

  Response get okResponse {
    if (responses.isEmpty) throw 'responses is empty. $path, $method';
    return responses.where((e) => e.code == 200).single;
  }

  List<Property> get deepParameterProperties {
    final ret = List<Property>.empty(growable: true);
    for (final parameter in parameters) {
      if (parameter.component != null) {
        ret.addAll(parameter.component!.properties);
      } else {
        ret.add(parameter.property!);
      }
    }
    return ret;
  }

  HttpMethod({
    required this.path,
    required this.method,
    required this.xExclude,
    required this.tags,
    required this.summary,
    required this.operationId,
    required this.requestBody,
    required this.parameters,
    required this.responses,
  });

  factory HttpMethod.fromMap(String path, String method, YamlMap m) {
    return HttpMethod(
      path: path,
      method: method,
      xExclude: m['x-exclude'] == null ? false : m['x-exclude'],
      tags: m['tags'] == null
          ? []
          : (m['tags'] as YamlList).map((e) => e as String).toList(),
      summary: m['summary'] ?? '',
      operationId: m['operationId'],
      requestBody: m['requestBody'] == null
          ? null
          : RequestBody.fromMap(m['requestBody']),
      parameters: (m['parameters'] as YamlList?)
              ?.map((e) => Parameter.fromMap(e))
              .toList() ??
          [],
      responses: (m['responses'] as YamlMap)
          .map((key, value) =>
              MapEntry<int, Response>(key, Response.fromMap(key, value)))
          .values
          .toList(),
    );
  }
}

class Path {
  final String path;
  final List<HttpMethod> httpMethods;
  Path({
    required this.path,
    required this.httpMethods,
  });

  factory Path.fromMap(String path, YamlMap m) {
    return Path(
      path: path,
      httpMethods: m
          .map((key, value) => MapEntry<String, HttpMethod>(
              key, HttpMethod.fromMap(path, key, value)))
          .values
          .toList(),
    );
  }
}

class OpenApi {
  final List<Server> servers;
  final List<Tag> tags;
  final List<Path> paths;
  final List<Component> components;

  Component getComponentFromRef(String ref) {
    final t = trimPath(ref);
    return components.singleWhere((e) => e.name == t);
  }

  OpenApi({
    required this.servers,
    required this.tags,
    required this.paths,
    required this.components,
  });

  factory OpenApi.fromMap(YamlMap m) {
    (m['components']['schemas'] as YamlMap)
        .map((key, value) => MapEntry<String, Component>(
            key, Component.fromMap(key, value, false)))
        .values
        .toList();
    final cs = (m['components']['schemas'] as YamlMap)
        .map((key, value) => MapEntry<String, Component>(
            key, Component.fromMap(key, value, true)))
        .values
        .toList();
    return OpenApi(
      servers:
          (m['servers'] as YamlList?)?.map((e) => Server.fromMap(e)).toList() ??
              [],
      tags: (m['tags'] as YamlList?)?.map((e) => Tag.fromMap(e)).toList() ?? [],
      paths: (m['paths'] as YamlMap?)
              ?.map((key, value) =>
                  MapEntry<String, Path>(key, Path.fromMap(key, value)))
              .values
              .toList() ??
          [],
      components: cs,
    );
  }
}

String generateDartCode(OpenApi openApi, String serverUrl) {
  return '''
// DO NOT EDIT. AUTO GENERATED FILE.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

${openApi.components.where((c) => c.name.toUpperCase() != c.name).map((c) => '''
class ${c.name.toUpperCamel()} ${c.xExtends == null ? '' : 'extends ${c.xExtends} '}${c.xImplements == null ? '' : 'implements ${c.xImplements} '}{
${c.properties.map((p) {
            final comment = '''
${p.title == null || p.title!.isEmpty ? '' : '  /// ${p.title}'}
${p.description == null || p.description!.isEmpty ? '' : '  /// ${p.description}'}
${p.maxLength == null ? '' : '  /// Maximum length. maxLength = ${p.maxLength}'}
${p.minLength == null ? '' : '  /// Minimum length. minLength = ${p.minLength}'}
${p.pattern == null ? '' : '  /// Regular expression. pattern = ${p.pattern}'}
'''
                .split('\n')
                .where((l) => l.trimRight().isNotEmpty)
                .join('\n');
            return '''
${comment}
  final ${p.dartType(openApi)} ${p.dartFieldName};
''';
          }).join('')}

${c.xCalculateProperties.map((p) => '''
  @override
  ${p.dartType} get ${p.dartFieldName} => ${p.dartCalculate};
''').join('')}

  ${c.name.toUpperCamel()}({
${c.properties.map((p) => '''
    required this.${p.dartFieldName},
''').join('')}
  });

  factory ${c.name.toUpperCamel()}.fromJson(Map<String, dynamic> m) {
    return ${c.name.toUpperCamel()}(
${c.properties.map((p) {
            if (p.isListType) {
              if (p.dartListBaseType(openApi).isObjectType) {
                return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] == null ? ${p.nullable ? 'null' : '[]'} : (m['${p.jsonFieldName}'] as List).map((e) => ${p.dartListBaseType(openApi)}.fromJson(e)).toList(),
''';
              } else {
                return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] == null ? ${p.nullable ? 'null' : '[]'} : (m['${p.jsonFieldName}'] as List).map((e) => e as ${p.dartListBaseType(openApi)}${p.itemsNullable ? '?' : ''}).toList(),
''';
              }
            } else if (p.isObjectType) {
              if (p.nullable) {
                return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] == null ? null : ${p.dartType(openApi)}.fromJson(m['${p.jsonFieldName}']),
''';
              } else {
                return '''
      ${p.dartFieldName}: ${p.dartType(openApi)}.fromJson(m['${p.jsonFieldName}']),
''';
              }
            } else if (p.isDateTime) {
              return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] == null
          ? ${p.dartType(openApi).dartTypeDefaultValue}
          : DateTime.parse(m['${p.jsonFieldName}']),
''';
            } else if (p.isBinary) {
              if (p.nullable) {
                return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] == null
          ? null : base64Decode(m['${p.jsonFieldName}']),
''';
              } else {
                return '''
      ${p.dartFieldName}: base64Decode(m['${p.jsonFieldName}']),
''';
              }
            } else if (p.dartType(openApi).dartTypeDefaultValue != 'null') {
              return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'] ?? ${p.dartType(openApi).dartTypeDefaultValue},
''';
            } else {
              return '''
      ${p.dartFieldName}: m['${p.jsonFieldName}'],
''';
            }
          }).join('')}
    );
  }

  static ${c.name.toUpperCamel()} get zero => ${c.name.toUpperCamel()}(
${c.properties.map((p) => '''
    ${p.dartFieldName}: ${p.dartType(openApi).dartTypeDefaultValue},
''').join('')}
  );

  Map<String, dynamic> toJson() {
    return {
${c.properties.map((p) {
            if (p.isBinary) {
              return '''
      '${p.jsonFieldName}': base64Encode(${p.dartFieldName}),
''';
            } else {
              return '''
      '${p.jsonFieldName}': ${p.dartFieldName}${p.dartType(openApi) == 'DateTime' ? '.toIso8601String()' : ''},
''';
            }
          }).join('')}
    };
  }

  @override
  String toString() {
    return '${c.name.toUpperCamel()}{${c.properties.map((p) => '${p.dartFieldName}: \$${p.dartFieldName}').join(', ')}}';
  }
}

''').join('')}

Uri getUri(String path, Map<String, dynamic>? queryParameters) {
  const url = '$serverUrl';
  final scheme = url.startsWith('https://')
      ? 'https://'
      : url.startsWith('http://')
          ? 'http://'
          : throw 'Scheme should be https or http';
  final u = url.replaceFirst(scheme, '');
  final i = u.indexOf('/');
  final authority = i < 0 ? u : u.substring(0, i);
  final remainedPath = i < 0 ? '' : u.substring(i);
  if (scheme == 'https://') {
    return Uri.https(authority, '\$remainedPath\$path', queryParameters);
  }
  return Uri.http(authority, '\$remainedPath\$path', queryParameters);
}

class HttpRepositories {
  final http.Client _httpClient;

  HttpRepositories(this._httpClient);

${openApi.paths.expand((p) => p.httpMethods).where((m) => !m.xExclude).map((m) => '''
  /// ${m.summary}
  Future<ApiResponse<${m.okResponse.isBinary ? 'Uint8List' : m.okResponse.component == null ? 'Object' : m.okResponse.component!.dartType}>> ${m.operationId.toLowerCamel()}(
${m.parameters.map((p) => p.inParam == 'header' ? '' : p.component != null ? '''
    ${p.component!.dartType} ${p.name.toLowerCamel()},''' : '''
    ${p.property!.dartType(openApi)} ${p.name.toLowerCamel()},''').join('')}
${m.requestBody == null ? '' : '''
    ${m.requestBody!.content.component!.dartType} data,'''}
  ) async {
    ${m.parameters.where((p) => p.inParam == 'path').isEmpty ? 'const' : 'final'} path = '${m.pathWithReplacedParameter}';
    final headers = <String, String>{};
${m.queryParameters.isEmpty ? '' : '''
    final queryParameters = <String, dynamic>{};
'''}
${m.queryParameters.map((p) => p.component != null ? '''
    for (final entry in ${p.name.toLowerCamel()}.toJson().entries) {
      if (entry.value != null) {
        if (entry.value is List) {
          queryParameters[entry.key] = entry.value.map((e) => e.toString()).toList();
        } else {
          queryParameters[entry.key] = entry.value.toString();
        }
      }
    }
''' : p.property!.dartType(openApi).dartTypeDefaultValue == 'null' ? '''
    if (${p.name.toLowerCamel()} != null) {
      ${p.property!.dartType(openApi).isListType ? '''
      queryParameters['${p.name.toSnake()}'] = ${p.name.toLowerCamel()}.map((e) => e.toString()).join(',');
''' : '''
      queryParameters['${p.name.toSnake()}'] = ${p.name.toLowerCamel()}.toString();
'''}
    }
''' : '''
      ${p.property!.dartType(openApi).isListType ? '''
    queryParameters['${p.name.toSnake()}'] = ${p.name.toLowerCamel()}.map((e) => e.toString()).join(',');
      ''' : '''
    queryParameters['${p.name.toSnake()}'] = ${p.name.toLowerCamel()}.toString();
      '''}
''').join('')}
${m.queryParameters.isEmpty ? '''
    Uri uri = getUri(path, null);
''' : '''
    Uri uri = getUri(path, queryParameters);
'''}
    try {
${m.method == 'get' || m.method == 'delete' ? '''
      final response = await _httpClient.${m.method}(uri, headers: headers);
''' : '''
      headers['content-type'] = 'application/json';
      final response = await _httpClient.${m.method}(uri, headers: headers, body: ${m.requestBody == null ? 'null' : 'jsonEncode(data.toJson())'});
'''}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ApiResponse.failed(response.statusCode);
      }
${m.responses.single.isBinary ? '''
      return ApiResponse(response.bodyBytes);
''' : m.responses.single.component == null ? '''
      return ApiResponse({});
''' : '''
      return ApiResponse(${m.responses.single.component!.dartType}.fromJson(jsonDecode(utf8.decode(response.bodyBytes))));
'''}
    } catch (e) {
      print('error in http call: \$e');
      return ApiResponse.apiError();
    }
  }

''').join('')}
}
''';
}
