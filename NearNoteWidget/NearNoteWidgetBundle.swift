import WidgetKit
import SwiftUI

@main
struct NearNoteWidgetBundle: WidgetBundle {
    var body: some Widget {
        ReminderActivityWidget()
        NearNoteHomeScreenWidget()
    }
}
