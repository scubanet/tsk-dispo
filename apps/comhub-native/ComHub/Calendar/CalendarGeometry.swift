import Foundation
import AtollHub

/// Reine Geometrie fürs Zeitgitter: minutenbasierte y-Position und Höhe.
struct CalendarGeometry {
  let startHour: Int
  let endHour: Int
  let pxPerMin: CGFloat
  let calendar: Calendar

  var totalHeight: CGFloat { CGFloat((endHour - startHour) * 60) * pxPerMin }

  func minutes(_ date: Date) -> Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }

  func y(_ date: Date) -> CGFloat {
    CGFloat(minutes(date) - startHour * 60) * pxPerMin
  }

  func height(start: Date, end: Date) -> CGFloat {
    max(CGFloat(minutes(end) - minutes(start)) * pxPerMin, 16)
  }
}
