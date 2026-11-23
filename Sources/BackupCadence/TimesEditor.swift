import SwiftUI
import BackupCadenceCore

struct TimesEditor: View {
    @Binding var times: [ScheduledTime]
    private let cal = Calendar.current

    var body: some View {
        ForEach($times) { $t in
            VStack(alignment: .leading) {
                HStack {
                    DatePicker("Time", selection: minuteBinding(t.hour * 60 + t.minute) { t.hour = $0 / 60; t.minute = $0 % 60 },
                               displayedComponents: .hourAndMinute)
                    Button(role: .destructive) { times.removeAll { $0.id == t.id } } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                }
                HStack(spacing: 4) {
                    ForEach(orderedWeekdays, id: \.self) { day in
                        Toggle(cal.veryShortWeekdaySymbols[day - 1], isOn: Binding(
                            get: { t.weekdays.contains(day) },
                            set: { if $0 { t.weekdays.insert(day) } else { t.weekdays.remove(day) } }))
                            .toggleStyle(.button)
                    }
                }
            }
        }
        Button("Add time") { times.append(ScheduledTime(hour: 2)) }
    }

    private var orderedWeekdays: [Int] {
        let first = cal.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }
}
