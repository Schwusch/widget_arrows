import 'package:flutter/material.dart';
import 'package:widget_arrows/widget_arrows.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MaterialApp(
        home: MyHomePage(),
      );
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool showArrows = true;

  @override
  Widget build(BuildContext context) => ArrowContainer(
        child: Scaffold(
          appBar: AppBar(
            title: ArrowElement(
              show: showArrows,
              color: Colors.red,
              id: 'title',
              targetId: 'text2',
              targetAnchor: Alignment.topCenter,
              sourceAnchor: Alignment.bottomCenter,
              child: Text('Arrows everywhere'),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: ArrowElement(
                    show: showArrows,
                    id: 'text',
                    targetIds: ['fab', 'title'],
                    sourceAnchor: Alignment.bottomCenter,
                    color: Colors.green,
                    child: Text('Arrows and stuff'),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ArrowElement(
                    show: showArrows,
                    id: 'text2',
                    targetId: 'text',
                    targetAnchor: Alignment.centerRight,
                    child: Text(
                      'Arrow here please',
                      style: Theme.of(context).textTheme.headline4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: ArrowElement(
            id: 'fab',
            child: FloatingActionButton(
              onPressed: () => setState(() {
                showArrows = !showArrows;
              }),
              tooltip: 'hide/show',
              child: Icon(Icons.remove_red_eye),
            ),
          ),
        ),
      );
}
