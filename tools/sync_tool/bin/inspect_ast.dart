import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

void main() {
  final content = '''
    var x = Scaffold(appBar: AppBar());
  ''';
  final result = parseString(content: content, throwIfDiagnostics: false);
  final unit = result.unit;
  
  unit.visitChildren(Visitor());
}

class Visitor extends RecursiveAstVisitor<void> {
  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    print('Type: \${node.constructorName.type.toSource()}');
    for (var arg in node.argumentList.arguments) {
      print('Arg type: \${arg.runtimeType}');
    }
    super.visitInstanceCreationExpression(node);
  }
}
