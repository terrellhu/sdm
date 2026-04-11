import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.title = "SDM 工具箱"
    self.minSize = NSSize(width: 900, height: 600)

    RegisterGeneratedPlugins(registry: flutterViewController)

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
