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

  Map<String, dynamic>? _parseExpression(Expression expression) {
    if (expression is InstanceCreationExpression) {
      final type = expression.constructorName.type.name2.lexeme;
      final arguments = expression.argumentList.arguments;

      final widgetModel = <String, dynamic>{
        'type': type,
        'id': 'w_${DateTime.now().millisecondsSinceEpoch}_${type.toLowerCase()}',
        'title': type,
        'viewModel': <String, dynamic>{},
        'widgetList': <Map<String, dynamic>>[],
      };

      for (final arg in arguments) {
        if (arg is NamedExpression) {
          final paramName = arg.name.label.name;
          if (paramName == 'child' || paramName == 'body') {
            final childWidget = _parseExpression(arg.expression);
            if (childWidget != null) {
              (widgetModel['widgetList'] as List).add(childWidget);
            }
          } else if (paramName == 'children') {
            if (arg.expression is ListLiteral) {
              final list = arg.expression as ListLiteral;
              for (final element in list.elements) {
                if (element is Expression) {
                  final childWidget = _parseExpression(element);
                  if (childWidget != null) {
                    (widgetModel['widgetList'] as List).add(childWidget);
                  }
                }
              }
            }
          } else {
             // For simple values, try to extract them as view models
             if (arg.expression is IntegerLiteral) {
               widgetModel['viewModel'][paramName] = (arg.expression as IntegerLiteral).value;
             } else if (arg.expression is DoubleLiteral) {
               widgetModel['viewModel'][paramName] = (arg.expression as DoubleLiteral).value;
             } else if (arg.expression is StringLiteral) {
               widgetModel['viewModel'][paramName] = (arg.expression as StringLiteral).stringValue;
             }
          }
        }
      }

      return widgetModel;
    }
    return null;
  }
}
