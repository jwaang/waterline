import Foundation
import Network
import SwiftData

// MARK: - SyncStatus

enum SyncStatus: Equatable {
    case idle
    case syncing
    case offline
    case error(String)

    var isOnline: Bool {
        self != .offline
    }
}

// MARK: - SyncService

/// Offline-first background sync service that monitors connectivity and pushes
/// pending SwiftData changes to Convex when the network is available.
/// Uses last-write-wins conflict resolution (most recent write overwrites remote).
@Observable
@MainActor
final class SyncService {
    private(set) var status: SyncStatus = .idle
    private(set) var pendingCount: Int = 0

    private let convexService: ConvexService?
    private let modelContainer: ModelContainer
    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.waterline.networkMonitor")
    private var isSyncing = false
    private var needsResync = false

    init(convexService: ConvexService?, modelContainer: ModelContainer) {
        self.convexService = convexService
        self.modelContainer = modelContainer
    }

    // MARK: - Lifecycle

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let connected = path.status == .satisfied

                if connected {
                    if self.status == .offline {
                        self.status = .idle
                    }
                    self.triggerSync()
                } else {
                    self.status = .offline
                }
            }
        }
        monitor.start(queue: monitorQueue)

        // Initial sync after a short delay to let monitor establish
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            self?.triggerSync()
        }
    }

    func stop() {
        monitor.cancel()
    }

    // MARK: - Public

    /// Deletes the user's data from Convex. Best-effort; local deletion proceeds regardless.
    func deleteRemoteAccount(appleUserId: String) async {
        guard let convexService else { return }
        do {
            try await convexService.deleteUser(appleUserId: appleUserId)
        } catch {
            // Remote deletion failure is non-fatal — local data is already wiped
        }
    }

    /// Call after any local data change to trigger a sync attempt.
    /// Uses a coalescing pattern: if a sync is already running, it will re-sync
    /// after the current one finishes instead of cancelling mid-flight.
    func triggerSync() {
        guard convexService != nil else { return }

        if isSyncing {
            // A sync is running — flag it to re-run when done
            needsResync = true
            print("[Sync] Sync in progress — will re-sync when done")
            return
        }

        Task { @MainActor [weak self] in
            await self?.performSync()
        }
    }

    // MARK: - Sync Engine

    @MainActor
    private func performSync() async {
        guard let convexService else { return }
        guard !isSyncing else { return }

        isSyncing = true
        needsResync = false
        status = .syncing
        print("[Sync] Starting sync...")

        let context = ModelContext(modelContainer)

        // Count pending items
        let pendingSessions = fetchPendingSessions(context: context)
        let pendingEntries = fetchPendingLogEntries(context: context)
        let pendingPresets = fetchPendingPresets(context: context)

        let total = pendingSessions.count + pendingEntries.count + pendingPresets.count
        pendingCount = total
        print("[Sync] Pending: \(pendingSessions.count) sessions, \(pendingEntries.count) entries, \(pendingPresets.count) presets")

        if total == 0 {
            isSyncing = false
            status = .idle
            print("[Sync] Nothing to sync")
            return
        }

        // Find the user's apple ID for Convex calls
        let userDescriptor = FetchDescriptor<User>()
        let users = (try? context.fetch(userDescriptor)) ?? []
        guard let appleUserId = users.first?.appleUserId else {
            print("[Sync] ERROR: No user with appleUserId found in local DB")
            isSyncing = false
            status = .idle
            return
        }
        print("[Sync] Syncing for appleUserId: \(appleUserId)")

        // Ensure user exists in Convex
        do {
            let userId = try await convexService.createUser(appleUserId: appleUserId)
            print("[Sync] Convex user ensured: \(userId)")
        } catch {
            print("[Sync] ERROR creating Convex user: \(error)")
            // If we can't even create the user, network is likely down
            isSyncing = false
            status = .error("Network error")
            scheduleRetry()
            return
        }

        // Sync sessions first (log entries depend on sessions existing)
        for session in pendingSessions {
            do {
                let sessionId = try await convexService.upsertSession(
                    appleUserId: appleUserId,
                    localId: session.id.uuidString,
                    startTime: session.startTime.timeIntervalSince1970 * 1000,
                    endTime: session.endTime.map { $0.timeIntervalSince1970 * 1000 },
                    isActive: session.isActive,
                    computedSummary: session.computedSummary.map {
                        ConvexSessionSummary(
                            totalDrinks: $0.totalDrinks,
                            totalWater: $0.totalWater,
                            totalStandardDrinks: $0.totalStandardDrinks,
                            durationSeconds: $0.durationSeconds,
                            pacingAdherence: $0.pacingAdherence,
                            finalWaterlineValue: $0.finalWaterlineValue
                        )
                    }
                )
                session.needsSync = false
                print("[Sync] Session synced: \(session.id) → \(sessionId)")
            } catch {
                print("[Sync] ERROR syncing session \(session.id): \(error)")
            }
        }

        // Sync log entries
        for entry in pendingEntries {
            guard let session = entry.session else {
                print("[Sync] SKIP entry \(entry.id) — no session relationship")
                continue
            }
            do {
                let entryId = try await convexService.addLogEntry(
                    appleUserId: appleUserId,
                    sessionStartTime: session.startTime.timeIntervalSince1970 * 1000,
                    timestamp: entry.timestamp.timeIntervalSince1970 * 1000,
                    type: entry.type.rawValue,
                    alcoholMeta: entry.alcoholMeta.map {
                        ConvexAlcoholMeta(
                            drinkType: $0.drinkType.rawValue,
                            sizeOz: $0.sizeOz,
                            abv: $0.abv,
                            standardDrinkEstimate: $0.standardDrinkEstimate,
                            presetId: $0.presetId?.uuidString
                        )
                    },
                    waterMeta: entry.waterMeta.map {
                        ConvexWaterMeta(amountOz: $0.amountOz)
                    },
                    source: entry.source.rawValue
                )
                entry.needsSync = false
                print("[Sync] Entry synced: \(entry.type.rawValue) → \(entryId)")
            } catch {
                print("[Sync] ERROR syncing entry \(entry.id): \(error)")
            }
        }

        // Sync presets
        for preset in pendingPresets {
            do {
                let presetId = try await convexService.upsertDrinkPreset(
                    appleUserId: appleUserId,
                    name: preset.name,
                    drinkType: preset.drinkType.rawValue,
                    sizeOz: preset.sizeOz,
                    abv: preset.abv,
                    standardDrinkEstimate: preset.standardDrinkEstimate,
                    localId: preset.id.uuidString
                )
                preset.needsSync = false
                print("[Sync] Preset synced: \(preset.name) → \(presetId)")
            } catch {
                print("[Sync] ERROR syncing preset \(preset.name): \(error)")
            }
        }

        // Save sync state changes
        do {
            try context.save()
            print("[Sync] Context saved successfully")
        } catch {
            print("[Sync] ERROR saving context: \(error)")
        }

        // Recount remaining
        let remainingSessions = fetchPendingSessions(context: context).count
        let remainingEntries = fetchPendingLogEntries(context: context).count
        let remainingPresets = fetchPendingPresets(context: context).count
        pendingCount = remainingSessions + remainingEntries + remainingPresets

        isSyncing = false
        status = pendingCount > 0 ? .error("Some items failed to sync") : .idle
        print("[Sync] Complete. Remaining: \(pendingCount)")

        // If new changes came in while we were syncing, sync again
        if needsResync {
            print("[Sync] Re-syncing due to changes during sync...")
            needsResync = false
            triggerSync()
        }
    }

    // MARK: - Retry

    private func scheduleRetry() {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard let self, !self.isSyncing else { return }
            print("[Sync] Retrying after delay...")
            self.triggerSync()
        }
    }

    // MARK: - Fetch Helpers

    private func fetchPendingSessions(context: ModelContext) -> [Session] {
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.needsSync },
            sortBy: [SortDescriptor(\Session.startTime)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPendingLogEntries(context: ModelContext) -> [LogEntry] {
        let descriptor = FetchDescriptor<LogEntry>(
            predicate: #Predicate<LogEntry> { $0.needsSync },
            sortBy: [SortDescriptor(\LogEntry.timestamp)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchPendingPresets(context: ModelContext) -> [DrinkPreset] {
        let descriptor = FetchDescriptor<DrinkPreset>(
            predicate: #Predicate<DrinkPreset> { $0.needsSync }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
