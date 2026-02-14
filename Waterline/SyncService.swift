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
    private var isConnected = false
    private var syncTask: Task<Void, Never>?

    init(convexService: ConvexService?, modelContainer: ModelContainer) {
        self.convexService = convexService
        self.modelContainer = modelContainer
    }

    // MARK: - Lifecycle

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                if self.isConnected {
                    if self.status == .offline {
                        self.status = .idle
                    }
                    // Trigger sync when connectivity is restored
                    if !wasConnected {
                        self.triggerSync()
                    }
                } else {
                    self.status = .offline
                }
            }
        }
        monitor.start(queue: monitorQueue)

        // Initial sync attempt
        triggerSync()
    }

    func stop() {
        monitor.cancel()
        syncTask?.cancel()
        syncTask = nil
    }

    // MARK: - Public

    /// Deletes the user's data from Convex. Best-effort; local deletion proceeds regardless.
    func deleteRemoteAccount(appleUserId: String) async {
        guard let convexService, isConnected else { return }
        do {
            try await convexService.deleteUser(appleUserId: appleUserId)
        } catch {
            // Remote deletion failure is non-fatal — local data is already wiped
        }
    }

    /// Call after any local data change to trigger a sync attempt.
    func triggerSync() {
        guard convexService != nil else { return }
        syncTask?.cancel()
        syncTask = Task { [weak self] in
            await self?.performSync()
        }
    }

    // MARK: - Sync Engine

    @MainActor
    private func performSync() async {
        guard let convexService, isConnected else {
            if !isConnected { status = .offline }
            return
        }

        let context = ModelContext(modelContainer)

        // Count pending items
        let pendingSessions = fetchPendingSessions(context: context)
        let pendingEntries = fetchPendingLogEntries(context: context)
        let pendingPresets = fetchPendingPresets(context: context)

        let total = pendingSessions.count + pendingEntries.count + pendingPresets.count
        pendingCount = total

        if total == 0 {
            status = .idle
            return
        }

        status = .syncing

        // Find the user's apple ID for Convex calls
        let userDescriptor = FetchDescriptor<User>()
        let users = (try? context.fetch(userDescriptor)) ?? []
        guard let userId = users.first?.appleUserId else {
            status = .idle
            return
        }

        // Sync sessions first (log entries depend on session IDs)
        for session in pendingSessions {
            guard !Task.isCancelled else { return }
            do {
                _ = try await convexService.upsertSession(
                    userId: userId,
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
                    },
                    existingId: session.id.uuidString
                )
                session.needsSync = false
            } catch {
                // Continue with other items — will retry next cycle
            }
        }

        // Sync log entries
        for entry in pendingEntries {
            guard !Task.isCancelled else { return }
            guard let sessionId = entry.session?.id else { continue }
            do {
                _ = try await convexService.addLogEntry(
                    sessionId: sessionId.uuidString,
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
            } catch {
                // Continue — will retry
            }
        }

        // Sync presets
        for preset in pendingPresets {
            guard !Task.isCancelled else { return }
            do {
                _ = try await convexService.upsertDrinkPreset(
                    userId: userId,
                    name: preset.name,
                    drinkType: preset.drinkType.rawValue,
                    sizeOz: preset.sizeOz,
                    abv: preset.abv,
                    standardDrinkEstimate: preset.standardDrinkEstimate,
                    existingId: preset.id.uuidString
                )
                preset.needsSync = false
            } catch {
                // Continue — will retry
            }
        }

        // Save sync state changes
        try? context.save()

        // Recount remaining
        let remainingSessions = fetchPendingSessions(context: context).count
        let remainingEntries = fetchPendingLogEntries(context: context).count
        let remainingPresets = fetchPendingPresets(context: context).count
        pendingCount = remainingSessions + remainingEntries + remainingPresets

        status = pendingCount > 0 ? .error("Some items failed to sync") : .idle
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
