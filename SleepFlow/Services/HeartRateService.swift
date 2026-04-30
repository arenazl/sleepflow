import Foundation
import HealthKit
import Combine

@MainActor
final class HeartRateService: ObservableObject {
    @Published private(set) var latestHR: Double?
    @Published private(set) var samples: [HRSample] = []
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationDenied: Bool = false
    @Published private(set) var lastUpdate: Date?
    @Published private(set) var isHealthKitAvailable: Bool

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    private let hrType = HKQuantityType(.heartRate)
    private var sessionStartDate: Date?
    private let bpmUnit = HKUnit.count().unitDivided(by: .minute())

    init() {
        self.isHealthKitAvailable = HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isHealthKitAvailable else {
            authorizationDenied = true
            return
        }
        do {
            try await healthStore.requestAuthorization(toShare: [], read: [hrType])
            let status = healthStore.authorizationStatus(for: hrType)
            isAuthorized = (status != .notDetermined)
            authorizationDenied = (status == .sharingDenied)
        } catch {
            authorizationDenied = true
        }
    }

    func startMonitoring(from start: Date) {
        sessionStartDate = start
        samples = []
        latestHR = nil
        lastUpdate = nil
        startObserver(from: start)
        Task { await fetchLatest(from: start) }
    }

    func stopMonitoring() {
        if let q = observerQuery {
            healthStore.stop(q)
            observerQuery = nil
        }
        healthStore.disableBackgroundDelivery(for: hrType) { _, _ in }
        sessionStartDate = nil
    }

    private func startObserver(from start: Date) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let query = HKObserverQuery(sampleType: hrType, predicate: predicate) { [weak self] _, completion, error in
            defer { completion() }
            guard error == nil else { return }
            Task { @MainActor in
                guard let self, let start = self.sessionStartDate else { return }
                await self.fetchLatest(from: start)
            }
        }
        healthStore.execute(query)
        observerQuery = query
        healthStore.enableBackgroundDelivery(for: hrType, frequency: .immediate) { _, _ in }
    }

    private func fetchLatest(from start: Date) async {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let query = HKSampleQuery(sampleType: hrType,
                                      predicate: predicate,
                                      limit: 100,
                                      sortDescriptors: [sort]) { [weak self] _, results, _ in
                Task { @MainActor in
                    guard let self else { continuation.resume(); return }
                    let unit = self.bpmUnit
                    let new: [HRSample] = (results ?? []).compactMap { s in
                        guard let q = s as? HKQuantitySample else { return nil }
                        return HRSample(timestamp: q.endDate, value: q.quantity.doubleValue(for: unit))
                    }
                    if !new.isEmpty {
                        var seen = Set(self.samples.map { $0.timestamp })
                        for s in new where !seen.contains(s.timestamp) {
                            self.samples.append(s)
                            seen.insert(s.timestamp)
                        }
                        self.samples.sort { $0.timestamp < $1.timestamp }
                        self.latestHR = self.samples.last?.value
                        self.lastUpdate = .now
                    }
                    continuation.resume()
                }
            }
            self.healthStore.execute(query)
        }
    }
}
