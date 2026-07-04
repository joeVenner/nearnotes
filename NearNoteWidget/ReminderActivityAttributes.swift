import ActivityKit
import WidgetKit
import SwiftUI

struct ReminderActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ReminderActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            RadarLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "location.north.line.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                        .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.distanceString)
                        .font(.headline)
                        .foregroundStyle(context.state.isClose ? .green : .primary)
                        .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.attributes.reminderTitle)
                            .font(.headline)
                        Text(context.attributes.placeName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(context.state.distanceString)
                    .font(.caption2.bold())
            } minimal: {
                Image(systemName: "location.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

// Custom Radar Style UI
struct RadarLockScreenView: View {
    let context: ActivityViewContext<ReminderActivityAttributes>
    
    var body: some View {
        HStack(spacing: 16) {
            // Radar Icon Simulation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 50, height: 50)
                
                Circle()
                    .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
                    .frame(width: 50, height: 50)
                
                Circle()
                    .strokeBorder(Color.green.opacity(0.5), lineWidth: 1)
                    .frame(width: 30, height: 30)
                
                Image(systemName: "location.north.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 16))
                    // The icon pulses when you're close!
                    .symbolEffect(.pulse, options: .repeating, isActive: context.state.isClose)
            }
            .padding(.leading, 16)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.reminderTitle)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(context.attributes.placeName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(context.state.distanceString)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(context.state.isClose ? .green : .primary)
                
                if context.state.isClose {
                    Text("Nearby")
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 16)
    }
}
