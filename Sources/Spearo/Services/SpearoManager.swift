import AppKit
import Foundation

class SpearoManager: ObservableObject {
    static let shared = SpearoManager()
    static let maxSlots = 12

    @Published var slots: [SpearoSlot?] = Array(repeating: nil, count: maxSlots)

    /// Number of slots to display: occupied count + 1 empty slot (minimum 1, max 12)
    var visibleSlotCount: Int {
        let occupiedCount = slots.filter { $0 != nil }.count
        return min(occupiedCount + 1, SpearoManager.maxSlots)
    }

    private let storageKey = "spearo.slots"

    private init() {
      guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
      let decoder = JSONDecoder()
      guard let stored = try? decoder.decode([SpearoSlot?].self, from: data) else { return }
      slots = stored
      // Ensure we always have exactly maxSlots slots
      while slots.count < SpearoManager.maxSlots { slots.append(nil) }
      if slots.count > SpearoManager.maxSlots { slots = Array(slots.prefix(SpearoManager.maxSlots)) }
    }

    // MARK: - App Switching

    func switchToSlot(_ index: Int) {
        guard index >= 0, index < slots.count else { return }
        guard let slot = slots[index] else { return }

        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: slot.bundleIdentifier)
        if let app = apps.first {
            app.unhide()
            app.activate(options: [.activateIgnoringOtherApps])
        } else {
            // App not running — launch it
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: slot.bundleIdentifier) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else {
                print("Cannot find app: \(slot.name)")
            }
        }
    }

    // MARK: - Slot Management

    func addCurrentApp() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleId = frontApp.bundleIdentifier else {
            print("Cannot determine current app")
            return
        }

        let name = frontApp.localizedName ?? bundleId
        let newSlot = SpearoSlot(bundleIdentifier: bundleId, name: name)

        // If already in a slot, don't duplicate
        if slots.contains(where: { $0?.bundleIdentifier == bundleId }) {
            print("\(name) is already in a slot")
            return
        }

        // Find first empty slot
        if let emptyIndex = slots.firstIndex(where: { $0 == nil }) {
            slots[emptyIndex] = newSlot
            save()
            print("Added \(name) to F\(emptyIndex + 1)")
        } else {
            print("All slots are full. Open the dialog to manage slots.")
        }
    }

    func removeSlot(_ index: Int) {
        guard index >= 0, index < slots.count else { return }
        slots[index] = nil
        save()
    }

    func moveSlot(from: Int, to: Int) {
        guard from >= 0, from < slots.count, to >= 0, to < slots.count else { return }
        let item = slots[from]
        slots[from] = slots[to]
        slots[to] = item
        save()
    }

    func setSlots(_ newSlots: [SpearoSlot?]) {
        slots = newSlots
        save()
    }

    // MARK: - Persistence

    private func save() {
        let encoder = JSONEncoder()
        // Encode entire array as a single JSON blob to avoid NSNull issues
        guard let data = try? encoder.encode(slots) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
