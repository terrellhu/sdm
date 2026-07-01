import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:path/path.dart' as p;
import '../utils/app_prefs.dart';
import '../utils/file_utils.dart';
import '../utils/pdf_ops.dart';
import '../widgets/result_dialog.dart';
import '../widgets/tool_widgets.dart';

class PdfEncryptPage extends StatefulWidget {
  const PdfEncryptPage({super.key});

  @override
  State<PdfEncryptPage> createState() => _PdfEncryptPageState();
}

class _PdfEncryptPageState extends State<PdfEncryptPage> {
  File? _pdfFile;
  String? _pdfName;
  String _mode = 'encrypt'; // encrypt | decrypt
  String _password = '';
  String _confirm = '';
  String? _outputDirectory = AppPrefs.outputDir;
  bool _isWorking = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pdfFile = File(result.files.single.path!);
      _pdfName = result.files.single.name;
    });
  }

  Future<void> _pickOutputDirectory() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _outputDirectory = result);
      await AppPrefs.rememberOutputDir(result);
    }
  }

  Future<void> _run() async {
    if (_pdfFile == null) return;
    if (_password.isEmpty) {
      showErrorDialog(context, '请输入密码');
      return;
    }
    if (_mode == 'encrypt' && _password != _confirm) {
      showErrorDialog(context, '两次输入的密码不一致');
      return;
    }
    setState(() => _isWorking = true);
    try {
      final inputBytes = await _pdfFile!.readAsBytes();
      final dir = await resolveOutputDir(preferred: _outputDirectory);
      final base = p.basenameWithoutExtension(_pdfName ?? 'document');
      late List<int> outBytes;
      late String outPath;

      if (_mode == 'encrypt') {
        final doc = sf.PdfDocument(inputBytes: inputBytes);
        doc.security.algorithm = sf.PdfEncryptionAlgorithm.aesx256Bit;
        doc.security.userPassword = _password;
        doc.security.ownerPassword = _password;
        outBytes = await doc.save();
        doc.dispose();
        outPath = uniquePath(dir, '${base}_加密', '.pdf');
      } else {
        // 用正确密码打开后，通过模板重建为一份不含加密的新 PDF。
        final doc = sf.PdfDocument(inputBytes: inputBytes, password: _password);
        final count = doc.pages.count;
        outBytes =
            await buildPdfFromPages(doc, List.generate(count, (i) => i));
        doc.dispose();
        outPath = uniquePath(dir, '${base}_解密', '.pdf');
      }

      await File(outPath).writeAsBytes(outBytes);
      if (!mounted) return;
      setState(() => _isWorking = false);
      showResultDialog(
        context,
        title: _mode == 'encrypt' ? '加密完成' : '解密完成',
        message: _mode == 'encrypt'
            ? '已使用 AES-256 加密，打开需输入密码。\n\n$outPath'
            : '已移除密码保护。\n\n$outPath',
        outputPath: outPath,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWorking = false);
      final msg = _mode == 'decrypt'
          ? '解密失败：密码错误或文件无法打开'
          : '加密失败：$e';
      showErrorDialog(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final encrypt = _mode == 'encrypt';
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: toolAppBar(
        context,
        title: 'PDF 加密 / 解密',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _isWorking
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5))
                : ShadButton(
                    onPressed: _pdfFile != null ? _run : null,
                    leading: Icon(
                        encrypt ? Icons.lock_rounded : Icons.lock_open_rounded,
                        size: 18),
                    child: Text(encrypt ? '加密导出' : '解密导出'),
                  ),
          ),
        ],
      ),
      body: ToolBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader('源文件', Icons.picture_as_pdf_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: _pdfFile == null
                        ? Center(
                            child: ShadButton.outline(
                              onPressed: _pickPdf,
                              leading: const Icon(Icons.add_rounded, size: 18),
                              child: const Text('点击选择 PDF'),
                            ),
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.picture_as_pdf_rounded,
                                    color: Colors.red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(_pdfName ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600, fontSize: 13),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              ShadIconButton.ghost(
                                onPressed: _pickPdf,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 32),
                  const SectionHeader('操作', Icons.security_rounded),
                  const SizedBox(height: 16),
                  ShadCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ToolChip(
                              label: '加密',
                              icon: Icons.lock_rounded,
                              selected: encrypt,
                              onTap: () => setState(() => _mode = 'encrypt'),
                            ),
                            const SizedBox(width: 8),
                            ToolChip(
                              label: '解密',
                              icon: Icons.lock_open_rounded,
                              selected: !encrypt,
                              onTap: () => setState(() => _mode = 'decrypt'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Text(encrypt ? '设置密码' : '输入当前密码',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        ShadInput(
                          placeholder: const Text('请输入密码'),
                          obscureText: true,
                          onChanged: (v) => setState(() => _password = v),
                        ),
                        if (encrypt) ...[
                          const SizedBox(height: 12),
                          ShadInput(
                            placeholder: const Text('再次输入密码'),
                            obscureText: true,
                            onChanged: (v) => setState(() => _confirm = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ShadCard(
                    padding: const EdgeInsets.all(16),
                    child: SettingTile(
                      title: '保存位置',
                      icon: Icons.folder_special_rounded,
                      child: OutputDirRow(
                        directory: _outputDirectory,
                        onPick: _pickOutputDirectory,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!encrypt)
                    Text('提示：解密会重建文档内容，书签与批注可能不被保留。',
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.mutedForeground)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
