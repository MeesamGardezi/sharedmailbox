import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';

class EmailRenderer extends StatelessWidget {
  final String htmlContent;
  
  const EmailRenderer({super.key, required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      htmlContent,
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.6,
        color: Color(0xFF202124),
        fontFamily: 'Roboto',
      ),
      onTapUrl: (url) async {
        return true;
      },
    );
  }
}
