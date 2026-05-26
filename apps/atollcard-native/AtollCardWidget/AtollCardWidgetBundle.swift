import SwiftUI
import WidgetKit

/// Widget Extension entry — registers all WidgetKit configurations.
/// Today: only the Lock-Screen rectangular widget.
@main
struct AtollCardWidgetBundle: WidgetBundle {
  var body: some Widget {
    LockScreenCardWidget()
  }
}
