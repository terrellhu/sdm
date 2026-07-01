import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'ocr_types.dart';

/// 基于 Windows.Media.Ocr 的本地 OCR（经 PowerShell/WinRT 调用，离线免费）。
class WindowsOcr {
  static String? _scriptPath;
  static int _seq = 0;

  static Future<String> _ensureScript() async {
    if (_scriptPath != null && File(_scriptPath!).existsSync()) {
      return _scriptPath!;
    }
    final dir = await getTemporaryDirectory();
    final f = File(p.join(dir.path, 'sdm_win_ocr.ps1'));
    await f.writeAsString(_script);
    _scriptPath = f.path;
    return f.path;
  }

  /// 对图片文件执行 OCR。[imagePath] 应为常规图片（png/jpg/bmp/tiff）。
  static Future<OcrPageResult> recognizeImageFile(
    String imagePath, {
    String lang = 'zh-Hans-CN',
  }) async {
    final script = await _ensureScript();
    final tmp = await getTemporaryDirectory();
    final outPath = p.join(tmp.path, 'sdm_ocr_out_${_seq++}.json');
    final outFile = File(outPath);
    if (await outFile.exists()) await outFile.delete();

    final res = await Process.run('powershell.exe', [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script,
      '-ImagePath',
      imagePath,
      '-OutPath',
      outPath,
      '-Lang',
      lang,
    ]);

    if (!await outFile.exists()) {
      throw Exception('OCR 执行失败：${res.stderr}'.trim());
    }
    var content = await outFile.readAsString(encoding: utf8);
    try {
      await outFile.delete();
    } catch (_) {}

    if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
      content = content.substring(1); // 去掉 UTF-8 BOM
    }
    final map = jsonDecode(content) as Map<String, dynamic>;

    final err = map['error'];
    if (err != null) {
      if (err == 'no_engine') {
        final avail = (map['available'] as List?)?.cast<String>() ?? const [];
        throw OcrUnavailableException(avail);
      }
      throw Exception('OCR 出错：$err');
    }

    return ocrResultFromMap(map);
  }

  /// 内嵌的 PowerShell 脚本：用 WinRT 调用系统 OCR，结果以 UTF-8 写入文件。
  static const String _script = r'''
param([string]$ImagePath, [string]$OutPath, [string]$Lang = "")
$ErrorActionPreference = "Stop"
function Write-Result($obj) {
  $json = ConvertTo-Json $obj -Depth 8 -Compress
  [System.IO.File]::WriteAllText($OutPath, $json, (New-Object System.Text.UTF8Encoding($false)))
}
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
  $asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
      $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  function Await($op, $type) {
    $t = $asTaskGeneric.MakeGenericMethod($type)
    $net = $t.Invoke($null, @($op))
    $net.Wait(-1) | Out-Null
    $net.Result
  }
  [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
  [Windows.Graphics.Imaging.BitmapDecoder,Windows.Graphics.Imaging,ContentType=WindowsRuntime] | Out-Null
  [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
  [Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime] | Out-Null

  $file = Await ([Windows.Storage.StorageFile]::GetFileFromPathAsync($ImagePath)) ([Windows.Storage.StorageFile])
  $stream = Await ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
  $decoder = Await ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
  $bitmap = Await ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])

  $engine = $null
  if ($Lang -ne "") {
    try {
      $language = New-Object Windows.Globalization.Language($Lang)
      if ([Windows.Media.Ocr.OcrEngine]::IsLanguageSupported($language)) {
        $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
      }
    } catch {}
  }
  if ($null -eq $engine) { $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages() }
  if ($null -eq $engine) {
    $langs = @([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | ForEach-Object { $_.LanguageTag })
    Write-Result @{ error = "no_engine"; available = $langs }
    return
  }

  $result = Await ($engine.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])

  $lines = @()
  foreach ($line in $result.Lines) {
    $lw = @()
    foreach ($wd in $line.Words) {
      $r = $wd.BoundingRect
      $lw += @{ t = $wd.Text; x = $r.X; y = $r.Y; w = $r.Width; h = $r.Height }
    }
    $lines += @{ words = $lw }
  }
  Write-Result @{ width = $bitmap.PixelWidth; height = $bitmap.PixelHeight; lines = $lines; error = $null }
} catch {
  try { Write-Result @{ error = $_.Exception.Message } } catch {}
}
''';
}
