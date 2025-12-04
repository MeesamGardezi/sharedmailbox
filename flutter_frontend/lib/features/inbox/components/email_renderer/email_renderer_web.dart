import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/material.dart';

class EmailRenderer extends StatefulWidget {
  final String htmlContent;
  
  const EmailRenderer({super.key, required this.htmlContent});

  @override
  State<EmailRenderer> createState() => _EmailRendererState();
}

class _EmailRendererState extends State<EmailRenderer> {
  late String _viewId;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  @override
  void didUpdateWidget(EmailRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.htmlContent != widget.htmlContent) {
      _registerView();
    }
  }

  void _registerView() {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _viewId = 'email-view-$id';
    
    // Create a complete HTML document structure
    final fullHtml = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            margin: 0;
            padding: 16px;
            font-family: Roboto, sans-serif;
            font-size: 14px;
            color: #202124;
            overflow-y: auto;
          }
          a { color: #1a73e8; text-decoration: none; }
          blockquote { border-left: 4px solid #e0e0e0; padding-left: 16px; margin: 8px 0; color: #5f6368; }
          img { max-width: 100%; height: auto; }
          /* Hide scrollbar for cleaner look if desired, but allow scrolling */
          ::-webkit-scrollbar { width: 8px; height: 8px; }
          ::-webkit-scrollbar-thumb { background: #dadce0; border-radius: 4px; }
          ::-webkit-scrollbar-track { background: transparent; }
        </style>
      </head>
      <body>
        ${widget.htmlContent}
        <script>
          // Open links in new tab
          document.addEventListener('click', function(e) {
            if (e.target.tagName === 'A') {
              e.preventDefault();
              window.open(e.target.href, '_blank');
            }
          });
        </script>
      </body>
      </html>
    ''';

    ui_web.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.border = 'none';
      iframe.style.width = '100%';
      iframe.style.height = '100%';
      iframe.srcdoc = fullHtml.toJS;
      return iframe;
    });
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewId);
  }
}
