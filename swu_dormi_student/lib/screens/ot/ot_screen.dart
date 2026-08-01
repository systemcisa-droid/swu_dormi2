import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class OtScreen extends StatefulWidget {
  const OtScreen({super.key});

  @override
  State<OtScreen> createState() => _OtScreenState();
}

class _OtScreenState extends State<OtScreen> {
  final PdfViewerController _pdfController = PdfViewerController();

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('기숙사 OT자료'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _pdfController.zoomLevel =
                  (_pdfController.zoomLevel + 0.25).clamp(0.5, 3.0);
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () {
              _pdfController.zoomLevel =
                  (_pdfController.zoomLevel - 0.25).clamp(0.5, 3.0);
            },
          ),
        ],
      ),
      body: SfPdfViewer.asset(
        'assets/pdfs/dormitory_ot_2026_1.pdf',
        controller: _pdfController,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}
