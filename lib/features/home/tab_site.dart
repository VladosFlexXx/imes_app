import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:vuz_app/ui/shimmer_skeleton.dart';

class SiteTab extends StatefulWidget {
  const SiteTab({super.key});

  @override
  State<SiteTab> createState() => _SiteTabState();
}

class _SiteTabState extends State<SiteTab> {
  static const startUrl = 'https://eos.imes.su/';

  InAppWebViewController? _controller;
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Сайт'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller?.reload(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_progress < 1) const LoadingSkeletonStrip(),
          Expanded(
            child: InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(startUrl)),
              onWebViewCreated: (c) => _controller = c,
              onProgressChanged: (_, p) => setState(() => _progress = p / 100),
            ),
          ),
        ],
      ),
    );
  }
}
