import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "SDM 工具箱"
    self.minSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // 注册 macOS Vision OCR 通道
    OcrPlugin.register(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()

    // 设置窗口大小（必须在 super.awakeFromNib() 之后，否则 Flutter 会重置窗口尺寸）
    let windowWidth: CGFloat = 1280
    let windowHeight: CGFloat = 800
    let screenSize = NSScreen.main?.frame.size ?? CGSize(width: 1920, height: 1080)
    let originX = (screenSize.width - windowWidth) / 2
    let originY = (screenSize.height - windowHeight) / 2

    self.setFrame(
      NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight),
      display: true
    )
  }
}

/// 基于 Vision 框架的本地 OCR，供 Dart 侧 MacosOcr 调用。
/// 返回结构与 Windows 实现一致：{width,height,lines:[{words:[{t,x,y,w,h}]}],error}
class OcrPlugin {
  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sdm/ocr", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "recognize",
        let args = call.arguments as? [String: Any],
        let path = args["path"] as? String
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      let langs = args["langs"] as? [String] ?? ["zh-Hans", "en-US"]
      OcrPlugin.recognize(path: path, langs: langs, result: result)
    }
  }

  static func recognize(path: String, langs: [String], result: @escaping FlutterResult) {
    guard let image = NSImage(contentsOfFile: path),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    else {
      result(["error": "cannot_load_image"])
      return
    }
    let width = cgImage.width
    let height = cgImage.height

    let request = VNRecognizeTextRequest { req, err in
      if let err = err {
        DispatchQueue.main.async { result(["error": err.localizedDescription]) }
        return
      }
      var lines: [[String: Any]] = []
      if let observations = req.results as? [VNRecognizedTextObservation] {
        for obs in observations {
          guard let top = obs.topCandidates(1).first, !top.string.isEmpty else { continue }
          let bb = obs.boundingBox  // 归一化，原点在左下
          let x = Double(bb.minX) * Double(width)
          let y = (1.0 - Double(bb.maxY)) * Double(height)
          let w = Double(bb.width) * Double(width)
          let h = Double(bb.height) * Double(height)
          let word: [String: Any] = ["t": top.string, "x": x, "y": y, "w": w, "h": h]
          lines.append(["words": [word]])
        }
      }
      let payload: [String: Any] = [
        "width": width,
        "height": height,
        "lines": lines,
        "error": NSNull(),
      ]
      DispatchQueue.main.async { result(payload) }
    }
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    if #available(macOS 11.0, *) {
      request.recognitionLanguages = langs
    }

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async { result(["error": error.localizedDescription]) }
      }
    }
  }
}
