import 'package:flutter/material.dart';

class MyTestUI extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test'),
      ),
      body: Container(
        color: 'red',
        child: Column(
          children: [
            Text('Hello'),
            Text('World'),
          ],
        ),
      ),
    );
  }
}
