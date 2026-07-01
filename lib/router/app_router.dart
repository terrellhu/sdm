import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/home_page.dart';
import '../pages/pdf_to_image_page.dart';
import '../pages/image_viewer_page.dart';
import '../pages/batch_print_page.dart';
import '../pages/pdf_merge_page.dart';
import '../pages/image_to_pdf_page.dart';
import '../pages/pdf_watermark_page.dart';
import '../pages/image_compress_page.dart';
import '../pages/pdf_split_page.dart';
import '../pages/pdf_encrypt_page.dart';
import '../pages/image_convert_page.dart';
import '../pages/image_watermark_page.dart';
import '../pages/pdf_extract_text_page.dart';
import '../pages/pdf_organize_page.dart';
import '../pages/ocr_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/pdf-to-image',
      name: 'pdfToImage',
      builder: (context, state) => const PdfToImagePage(),
    ),
    GoRoute(
      path: '/image-viewer',
      name: 'imageViewer',
      builder: (context, state) => const ImageViewerPage(),
    ),
    GoRoute(
      path: '/batch-print',
      name: 'batchPrint',
      builder: (context, state) => BatchPrintPage(
        initialFiles: state.extra as List<File>?,
      ),
    ),
    GoRoute(
      path: '/pdf-merge',
      name: 'pdfMerge',
      builder: (context, state) => const PdfMergePage(),
    ),
    GoRoute(
      path: '/image-to-pdf',
      name: 'imageToPdf',
      builder: (context, state) => const ImageToPdfPage(),
    ),
    GoRoute(
      path: '/pdf-watermark',
      name: 'pdfWatermark',
      builder: (context, state) => const PdfWatermarkPage(),
    ),
    GoRoute(
      path: '/image-compress',
      name: 'imageCompress',
      builder: (context, state) => const ImageCompressPage(),
    ),
    GoRoute(
      path: '/pdf-split',
      name: 'pdfSplit',
      builder: (context, state) => const PdfSplitPage(),
    ),
    GoRoute(
      path: '/pdf-encrypt',
      name: 'pdfEncrypt',
      builder: (context, state) => const PdfEncryptPage(),
    ),
    GoRoute(
      path: '/image-convert',
      name: 'imageConvert',
      builder: (context, state) => const ImageConvertPage(),
    ),
    GoRoute(
      path: '/image-watermark',
      name: 'imageWatermark',
      builder: (context, state) => const ImageWatermarkPage(),
    ),
    GoRoute(
      path: '/pdf-extract-text',
      name: 'pdfExtractText',
      builder: (context, state) => const PdfExtractTextPage(),
    ),
    GoRoute(
      path: '/pdf-organize',
      name: 'pdfOrganize',
      builder: (context, state) => const PdfOrganizePage(),
    ),
    GoRoute(
      path: '/ocr',
      name: 'ocr',
      builder: (context, state) => const OcrPage(),
    ),
  ],
);
