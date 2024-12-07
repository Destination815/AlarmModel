// AlarmModel.swift
import Foundation

struct Alarm: Identifiable {
    let id = UUID()
    var time: Date
    var isEnabled: Bool
    var label: String
    var repeatDays: Set<Int> // 0 = Sunday, 1 = Monday, etc.
    
    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}

class AlarmStore: ObservableObject {
    @Published var alarms: [Alarm] = []
    
    func addAlarm(_ alarm: Alarm) {
        alarms.append(alarm)
        scheduleNotification(for: alarm)
    }
    
    func toggleAlarm(_ alarm: Alarm) {
        if let index = alarms.firstIndex(where: { $0.id == alarm.id }) {
            alarms[index].isEnabled.toggle()
            if alarms[index].isEnabled {
                scheduleNotification(for: alarms[index])
            } else {
                cancelNotification(for: alarm)
            }
        }
    }
    
    func deleteAlarm(_ alarm: Alarm) {
        alarms.removeAll(where: { $0.id == alarm.id })
        cancelNotification(for: alarm)
    }
    
    private func scheduleNotification(for alarm: Alarm) {
        let content = UNMutableNotificationContent()
        content.title = "闹钟"
        content.body = alarm.label.isEmpty ? "闹钟时间到" : alarm.label
        content.sound = UNNotificationSound.default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: alarm.time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: !alarm.repeatDays.isEmpty)
        
        let request = UNNotificationRequest(identifier: alarm.id.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotification(for alarm: Alarm) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [alarm.id.uuidString])
    }
}

// ContentView.swift
import SwiftUI

struct ContentView: View {
    @StateObject private var alarmStore = AlarmStore()
    @State private var showingAddAlarm = false
    
    var body: some View {
        NavigationView {
            List {
                ForEach(alarmStore.alarms) { alarm in
                    AlarmRow(alarm: alarm, store: alarmStore)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        alarmStore.deleteAlarm(alarmStore.alarms[index])
                    }
                }
            }
            .navigationTitle("闹钟")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddAlarm = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAlarm) {
                AddAlarmView(store: alarmStore)
            }
        }
    }
}

// AlarmRow.swift
struct AlarmRow: View {
    let alarm: Alarm
    @ObservedObject var store: AlarmStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(alarm.timeString)
                    .font(.title)
                if !alarm.label.isEmpty {
                    Text(alarm.label)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { alarm.isEnabled },
                set: { _ in store.toggleAlarm(alarm) }
            ))
        }
    }
}

// AddAlarmView.swift
struct AddAlarmView: View {
    @ObservedObject var store: AlarmStore
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTime = Date()
    @State private var label = ""
    @State private var selectedDays: Set<Int> = []
    
    let weekDays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    DatePicker("时间", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .labelsHidden()
                }
                
                Section(header: Text("标签")) {
                    TextField("闹钟标签", text: $label)
                }
                
                Section(header: Text("重复")) {
                    ForEach(0..<7) { index in
                        Toggle(weekDays[index], isOn: Binding(
                            get: { selectedDays.contains(index) },
                            set: { isSelected in
                                if isSelected {
                                    selectedDays.insert(index)
                                } else {
                                    selectedDays.remove(index)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("添加闹钟")
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("保存") {
                    let newAlarm = Alarm(
                        time: selectedTime,
                        isEnabled: true,
                        label: label,
                        repeatDays: selectedDays
                    )
                    store.addAlarm(newAlarm)
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

// AppDelegate.swift
import UIKit
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("通知权限获取成功")
            } else {
                print("通知权限获取失败")
            }
        }
        
        return true
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

// @main
import SwiftUI

@main
struct AlarmApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
