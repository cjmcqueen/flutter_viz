import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart bin/sync_tool.dart <path_to_dart_file>');
    exit(1);
  }

  final filePath = args[0];
  final file = File(filePath);

  if (!file.existsSync()) {
    print('File not found: $filePath');
    exit(1);
  }

  final content = file.readAsStringSync();
  
  // Parse the Dart code into an AST
  final parseResult = parseString(content: content, throwIfDiagnostics: false);
  final unit = parseResult.unit;

  // Visit the AST to find the build method and extract the widget tree
  final visitor = WidgetTreeVisitor();
  unit.visitChildren(visitor);

  if (visitor.rootWidget == null) {
    print('No widget tree found in the file.');
    exit(1);
  }

  // Wrap the root widget in a DownloadModel structure
  final downloadModel = {
    'fileName': file.path.split('/').last,
    'rootView': visitor.rootWidget,
    'selectedWidgetList': [visitor.rootWidget]
  };

  final jsonOutput = JsonEncoder.withIndent('  ').convert(downloadModel);
  
  // Save to a .fviz.json file next to the dart file
  final outputPath = filePath.replaceAll('.dart', '.fviz.json');
  File(outputPath).writeAsStringSync(jsonOutput);
  print('Successfully parsed and saved to: $outputPath');
}

class WidgetTreeVisitor extends RecursiveAstVisitor<void> {
  Map<String, dynamic>? rootWidget;
  bool _inBuildMethod = false;

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    if (node.name.lexeme == 'build') {
      _inBuildMethod = true;
      super.visitMethodDeclaration(node);
      _inBuildMethod = false;
    } else {
      super.visitMethodDeclaration(node);
    }
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    if (_inBuildMethod && node.expression != null) {
      rootWidget = _parseExpression(node.expression!);
    }
    super.visitReturnStatement(node);
  }

  Map<String, dynamic>? _parseExpression(dynamic expression) {
    print('Parsing expression: ${expression.runtimeType}');
    if (expression.runtimeType.toString().contains('MethodInvocation')) {
      final type = expression.methodName.name;
      final arguments = expression.argumentList.arguments;
      return _buildWidgetModel(type, arguments);
    } 
    else if (expression.runtimeType.toString().contains('InstanceCreationExpression')) {
      final type = expression.constructorName.type.toSource();
      final arguments = expression.argumentList.arguments;
      return _buildWidgetModel(type, arguments);
    }
    return null;
  }

  Map<String, dynamic> _buildWidgetModel(String type, dynamic arguments) {
      print('Building widget model for type: $type');
      final widgetModel = <String, dynamic>{
        'type': type,
        'id': 'w_\${DateTime.now().millisecondsSinceEpoch}_\${type.toLowerCase()}',
        'title': type,
        'viewModel': <String, dynamic>{},
        'widgetList': <Map<String, dynamic>>[],
      };

      for (final arg in arguments) {
        print('Processing arg: ${arg.runtimeType}');
        if (arg.runtimeType.toString().contains('NamedExpression') || arg.runtimeType.toString().contains('NamedArgument')) {
          final paramNameStr = arg.toSource();
          final splitIndex = paramNameStr.indexOf(':');
          final paramName = paramNameStr.substring(0, splitIndex).trim();
          final exp = arg.childEntities.last;
          
          print('Named param: $paramName, expression type: ${exp.runtimeType}');
          final childWidget = _parseExpression(exp);
          
          if (childWidget != null) {
              print('Added child widget to $type for param $paramName');
              (widgetModel['widgetList'] as List).add(childWidget);
          } else if (paramName == 'children') {
            if (exp.runtimeType.toString().contains('ListLiteral')) {
              for (final element in exp.elements) {
                final childListItem = _parseExpression(element);
                if (childListItem != null) {
                  (widgetModel['widgetList'] as List).add(childListItem);
                }
              }
            }
          } else {
             print('Processing as view model value: $paramName');
             // For simple values, try to extract them as view models
             if (exp.runtimeType.toString().contains('IntegerLiteral')) {
               widgetModel['viewModel'][paramName] = exp.value;
             } else if (exp.runtimeType.toString().contains('DoubleLiteral')) {
               widgetModel['viewModel'][paramName] = exp.value;
             } else if (exp.runtimeType.toString().contains('StringLiteral')) {
               widgetModel['viewModel'][paramName] = exp.stringValue;
             } else {
               widgetModel['viewModel'][paramName] = exp.toSource();
             }
          }
        }
      }

      return widgetModel;
  }
}
