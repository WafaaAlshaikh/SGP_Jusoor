import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class StripeCheckoutScreen extends StatefulWidget {
  final String checkoutUrl;
  final String? sessionId;
  final int? institutionId;
  final String institutionName;
  final double amount;

  const StripeCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    this.sessionId,
    this.institutionId,
    required this.institutionName,
    required this.amount,
  });

  @override
  State<StripeCheckoutScreen> createState() => _StripeCheckoutScreenState();
}

class _StripeCheckoutScreenState extends State<StripeCheckoutScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _paymentCompleted = false;
  bool _openedExternal = false;
  bool _useExternalFlow = false;

  @override
  void initState() {
    super.initState();
    _useExternalFlow = true;
    _isLoading = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openInExternalBrowser();
    });
  }

  Future<void> _initWebView() async {
    // تهيئة WebViewController
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);

    // تفعيل JavaScript
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    
    // إعداد الشفافية
    await controller.setBackgroundColor(const Color(0x00000000));
    
    // معالجة التنقل
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onProgress: (int progress) {
          print('WebView loading: $progress%');
        },
        onPageStarted: (String url) {
          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (String url) {
          setState(() {
            _isLoading = false;
          });
          
          // التحقق مما إذا كانت صفحة النجاح
          _checkForSuccess(url);
        },
        onWebResourceError: (WebResourceError error) {
          print('WebView error: ${error.description}');
        },
        onNavigationRequest: (NavigationRequest request) {
          // السماح بجميع الروابط
          print('Navigating to: ${request.url}');
          return NavigationDecision.navigate;
        },
        onUrlChange: (UrlChange change) {
          print('URL changed to: ${change.url}');
          _checkForSuccess(change.url ?? '');
        },
      ),
    );

    // تحميل رابط Stripe
    await controller.loadRequest(Uri.parse(widget.checkoutUrl));

    // إعدادات خاصة بـ Android
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    if (!mounted) return;
    setState(() {
      _controller = controller;
    });
  }

  void _checkForSuccess(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;

    final path = uri.path.toLowerCase();

    // Only treat as complete when Stripe redirects to OUR known endpoints.
    // Avoid false-positives because the initial Stripe checkout URL contains success_url=.../donations/success
    if (path.endsWith('/donations/success')) {
      if (!_paymentCompleted) {
        _paymentCompleted = true;
        _showSuccessMessage();
      }
      return;
    }

    if (path.endsWith('/donations/cancel')) {
      if (mounted) {
        Navigator.pop(context, false);
      }
    }
  }

  void _showSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Payment completed successfully!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Close',
          onPressed: () {
            Navigator.pop(context, true);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Complete Payment'),
            Text(
              '${widget.amount} JOD to ${widget.institutionName}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller?.reload();
            },
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              // بديل: فتح في متصفح خارجي
              _openInExternalBrowser();
            },
            tooltip: 'Open in browser',
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_useExternalFlow)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'We opened Stripe Checkout in your browser to complete the payment.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _openInExternalBrowser,
                      icon: const Icon(Icons.open_in_browser),
                      label: const Text('Open Stripe Checkout Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, true);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('I Completed Payment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, false);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_controller != null)
            WebViewWidget(controller: _controller!)
          else
            const Center(child: CircularProgressIndicator()),
          if (_isLoading)
            IgnorePointer(
              ignoring: true,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Do not close this window until payment is complete',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_paymentCompleted) {
                        Navigator.pop(context, true);
                      } else {
                        _showExitWarning();
                      }
                    },
                    icon: const Icon(Icons.done_all),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _paymentCompleted
                          ? Colors.green
                          : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showExitWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Payment Not Completed'),
        content: const Text(
          'Your payment may not be fully processed yet. '
          'Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close WebView
            },
            child: const Text('Exit Anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInExternalBrowser() async {
    try {
      if (_openedExternal) {
        // allow re-open via button
      } else {
        _openedExternal = true;
      }
      final uri = Uri.parse(widget.checkoutUrl);
      final mode = kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication;
      final ok = await launchUrl(uri, mode: mode, webOnlyWindowName: '_blank');
      if (!ok) {
        throw Exception('Could not open Stripe checkout');
      }
    } catch (e) {
      print('Error opening in browser: $e');
    }
  }
}