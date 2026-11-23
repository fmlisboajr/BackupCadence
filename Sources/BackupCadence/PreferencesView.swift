import SwiftUI
import BackupCadenceCore

struct PreferencesView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            Section {
                Toggle("Scheduling on", isOn: Binding(get: { model.config.enabled }, set: { model.setEnabled($0) }))
                Toggle("Open at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
                if let e = model.errorMessage { Text(e).foregroundStyle(.red) }
            }
            Section("Schedule") {
                Picker("Mode", selection: $model.config.mode) {
                    Text("Interval").tag(ScheduleMode.interval)
                    Text("Specific times").tag(ScheduleMode.times)
                    Text("When idle").tag(ScheduleMode.idle)
                }
                switch model.config.mode {
                case .interval:
                    Stepper("Every \(model.config.intervalHours) hours", value: $model.config.intervalHours, in: 1...168)
                case .times:
                    TimesEditor(times: $model.config.times)
                case .idle:
                    Stepper("Idle for \(model.config.idleMinutes) minutes", value: $model.config.idleMinutes, in: 5...120, step: 5)
                    Stepper("At most once every \(model.config.idleMinHoursBetween) hours", value: $model.config.idleMinHoursBetween, in: 1...168)
                }
            }
            Section("Restrictions") {
                Toggle("Don't back up on battery", isOn: $model.config.skipOnBattery)
                Toggle("Forbidden time window", isOn: Binding(
                    get: { model.config.forbiddenWindow != nil },
                    set: { model.config.forbiddenWindow = $0 ? TimeWindow(startMinute: 9 * 60, endMinute: 17 * 60) : nil }))
                if let w = model.config.forbiddenWindow {
                    DatePicker("From", selection: minuteBinding(w.startMinute) { model.config.forbiddenWindow?.startMinute = $0 },
                               displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: minuteBinding(w.endMinute) { model.config.forbiddenWindow?.endMinute = $0 },
                               displayedComponents: .hourAndMinute)
                }
            }
            Section("Destination") {
                Picker("Back up to", selection: $model.config.destinationID) {
                    Text("All destinations").tag(String?.none)
                    ForEach(model.destinations) { d in Text(d.name).tag(Optional(d.id)) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .padding(.vertical, 8)
    }
}

@MainActor func minuteBinding(_ minute: Int, set: @escaping @MainActor (Int) -> Void) -> Binding<Date> {
    let cal = Calendar.current
    return Binding(
        get: { cal.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date() },
        set: { set(cal.component(.hour, from: $0) * 60 + cal.component(.minute, from: $0)) })
}
