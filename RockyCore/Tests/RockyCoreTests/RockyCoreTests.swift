import Testing
import Foundation
@testable import RockyCore

// MARK: - Shared test database

actor TestDatabase {
    static let shared = TestDatabase()
    private var db: Database?

    func get() async throws -> Database {
        if let db { return db }
        let db = try await Database.open(at: ":memory:")
        self.db = db
        return db
    }

    func reset() async throws {
        let db = try await get()
        try await db.execute("DELETE FROM sessions")
        try await db.execute("DELETE FROM projects")
    }
}

// MARK: - Session Model (no database needed)

@Suite("Session Model")
struct SessionModelTests {
    @Test("duration calculates from start to end")
    func duration() {
        let start = Date()
        let end = start.addingTimeInterval(3600)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: end)
        #expect(session.duration() == 3600)
        #expect(!session.isRunning)
    }

    @Test("running session uses current time for duration")
    func runningDuration() {
        let start = Date().addingTimeInterval(-120)
        let session = Session(id: 1, projectId: 1, startTime: start, endTime: nil)
        #expect(session.isRunning)
        #expect(session.duration() >= 120)
    }
}

// MARK: - Database tests (single shared connection, serialized)

@Suite("Database Tests", .serialized)
struct DatabaseTests {

    // MARK: - Migrations

    @Test("Tables exist after migration")
    func tablesExist() async throws {
        let db = try await TestDatabase.shared.get()
        let tables = try await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        let names = tables.compactMap { $0.column("name")?.string }
        #expect(names.contains("projects"))
        #expect(names.contains("sessions"))
        #expect(names.contains("migrations"))
    }

    @Test("Migration version is 1")
    func migrationVersion() async throws {
        let db = try await TestDatabase.shared.get()
        let rows = try await db.query("SELECT version FROM migrations")
        #expect(rows.count == 1)
        #expect(rows[0].column("version")?.integer == 1)
    }

    // MARK: - ProjectService

    @Test("findOrCreate creates a new project")
    func createProject() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        let project = try await service.findOrCreate(name: "acme-corp")
        #expect(project.name == "acme-corp")
        #expect(project.id > 0)
        #expect(project.parentId == nil)
    }

    @Test("findOrCreate returns existing project")
    func findExisting() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        let first = try await service.findOrCreate(name: "acme-corp")
        let second = try await service.findOrCreate(name: "acme-corp")
        #expect(first.id == second.id)
    }

    @Test("getByName is case-insensitive")
    func caseInsensitive() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        _ = try await service.findOrCreate(name: "Acme-Corp")
        let found = try await service.getByName("acme-corp")
        #expect(found != nil)
        #expect(found?.name == "Acme-Corp")
    }

    @Test("getByName returns nil for unknown project")
    func unknownProject() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        let found = try await service.getByName("nonexistent")
        #expect(found == nil)
    }

    @Test("list returns all projects")
    func listProjects() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        _ = try await service.findOrCreate(name: "alpha")
        _ = try await service.findOrCreate(name: "beta")
        _ = try await service.findOrCreate(name: "gamma")
        let projects = try await service.list()
        #expect(projects.count == 3)
    }

    @Test("getById returns correct project")
    func getById() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let service = ProjectService(db: db)
        let created = try await service.findOrCreate(name: "test-project")
        let found = try await service.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "test-project")
    }

    // MARK: - SessionService

    @Test("start creates a running session")
    func startSession() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == project.id)
        #expect(running[0].isRunning)
    }

    @Test("hasRunningSession detects active timer")
    func hasRunning() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let project = try await projects.findOrCreate(name: "acme-corp")
        #expect(try await sessions.hasRunningSession(projectId: project.id) == false)
        try await sessions.start(projectId: project.id)
        #expect(try await sessions.hasRunningSession(projectId: project.id) == true)
    }

    @Test("stop sets end_time on session")
    func stopSession() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let stopped = try await sessions.stop(projectId: project.id)
        #expect(stopped.endTime != nil)
        #expect(!stopped.isRunning)
        let running = try await sessions.getRunning()
        #expect(running.isEmpty)
    }

    @Test("stopAll stops all running sessions")
    func stopAll() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        let stopped = try await sessions.stopAll()
        #expect(stopped.count == 2)
        #expect(stopped.allSatisfy { !$0.isRunning })
        let running = try await sessions.getRunning()
        #expect(running.isEmpty)
    }

    @Test("concurrent timers on different projects")
    func concurrentTimers() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 2)
    }

    @Test("stop one timer leaves other running")
    func stopOneOfTwo() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        _ = try await sessions.stop(projectId: p1.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == p2.id)
    }

    @Test("getRunningWithProjects returns session and project data")
    func runningWithProjects() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let running = try await sessions.getRunningWithProjects()
        #expect(running.count == 1)
        #expect(running[0].0.projectId == project.id)
        #expect(running[0].1.name == "acme-corp")
    }

    @Test("stop throws when no running session")
    func stopNoRunning() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let project = try await projects.findOrCreate(name: "acme-corp")
        await #expect(throws: RockyCoreError.self) {
            try await sessions.stop(projectId: project.id)
        }
    }

    @Test("stopAll with nothing running returns empty array")
    func stopAllEmpty() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let sessions = SessionService(db: db)
        let stopped = try await sessions.stopAll()
        #expect(stopped.isEmpty)
    }

    @Test("getSessions returns sessions overlapping date range")
    func getSessionsDateRange() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 11))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 11))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        let results = try await sessions.getSessions(from: from, to: to)

        #expect(results.count == 2)
    }

    // MARK: - ReportService

    @Test("allProjectsWithStatus shows running projects first")
    func statusOrder() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let p1 = try await projects.findOrCreate(name: "inactive")
        let p2 = try await projects.findOrCreate(name: "active")
        try await sessions.start(projectId: p1.id)
        _ = try await sessions.stop(projectId: p1.id)
        try await sessions.start(projectId: p2.id)

        let statuses = try await reports.allProjectsWithStatus()
        #expect(statuses.count == 2)
        #expect(statuses[0].project.name == "active")
        #expect(statuses[0].isRunning)
        #expect(statuses[1].project.name == "inactive")
        #expect(!statuses[1].isRunning)
    }

    @Test("totals calculates project durations in range")
    func totals() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let project = try await projects.findOrCreate(name: "test")
        try await sessions.start(projectId: project.id)
        _ = try await sessions.stop(projectId: project.id)

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let result = try await reports.totals(from: start, to: end)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "test")
    }

    @Test("totals filters by project")
    func totalsFiltered() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let p1 = try await projects.findOrCreate(name: "included")
        let p2 = try await projects.findOrCreate(name: "excluded")
        try await sessions.start(projectId: p1.id)
        _ = try await sessions.stop(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        _ = try await sessions.stop(projectId: p2.id)

        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end = cal.date(byAdding: .day, value: 1, to: start)!

        let result = try await reports.totals(from: start, to: end, projectId: p1.id)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "included")
    }

    @Test("totals sums multiple sessions for same project")
    func totalsSumMultiple() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 15))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reports.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(abs(result.entries[0].duration - 7200) < 1)
    }

    @Test("groupedByDay distributes session across correct days")
    func groupedByDay() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 12))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 8))!

        let report = try await reports.groupedByDay(from: from, to: to)
        #expect(report.columns.count == 6)
        #expect(report.rows.count == 1)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 7200) < 1)
        #expect(abs((report.rows[0].columnDurations[2] ?? 0) - 3600) < 1)
        #expect((report.rows[0].columnDurations[1] ?? 0) < 1)
    }

    @Test("session spanning midnight splits across days")
    func sessionSpanningMidnight() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "late-night")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 23))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 1))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 4))!

        let report = try await reports.groupedByDay(from: from, to: to)
        #expect(report.columns.count == 2)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 3600) < 1)
        #expect(abs((report.rows[0].columnDurations[1] ?? 0) - 3600) < 1)
    }

    @Test("groupedByWeek creates correct week columns")
    func groupedByWeek() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 11))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 11))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 15))!

        let report = try await reports.groupedByWeek(from: from, to: to)
        #expect(report.rows.count == 1)
        #expect(report.columns.count >= 2)
        #expect(abs(report.grandTotal - 7200) < 1)
    }

    @Test("groupedByMonth creates correct month columns")
    func groupedByMonth() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let to = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!

        let report = try await reports.groupedByMonth(from: from, to: to)
        #expect(report.columns.count == 3)
        #expect(report.rows.count == 1)
        #expect(abs((report.rows[0].columnDurations[0] ?? 0) - 7200) < 1)
        #expect((report.rows[0].columnDurations[1] ?? 0) < 1)
        #expect(abs((report.rows[0].columnDurations[2] ?? 0) - 3600) < 1)
    }

    @Test("verboseSessions returns individual session rows")
    func verboseSessions() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 8))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 9))!)
        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 14))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 15))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let rows = try await reports.verboseSessions(from: from, to: to)
        #expect(rows.count == 2)
        #expect(rows[0].projectName == "test")
        #expect(rows[1].projectName == "test")
        #expect(rows[0].session.endTime != nil)
    }

    @Test("session partially overlapping range is clamped")
    func partialOverlap() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let project = try await projects.findOrCreate(name: "test")

        try await sessions.insert(projectId: project.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 5, hour: 22))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 6, hour: 2))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 6))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!

        let result = try await reports.totals(from: from, to: to)
        #expect(result.entries.count == 1)
        #expect(abs(result.entries[0].duration - 7200) < 1)
    }

    @Test("multiple projects in grouped report sorted by duration")
    func multipleProjectsGrouped() async throws {
        try await TestDatabase.shared.reset()
        let db = try await TestDatabase.shared.get()
        let projects = ProjectService(db: db)
        let sessions = SessionService(db: db)
        let reports = ReportService(db: db)
        let cal = Calendar.current
        let p1 = try await projects.findOrCreate(name: "alpha")
        let p2 = try await projects.findOrCreate(name: "beta")

        try await sessions.insert(projectId: p1.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 13))!)
        try await sessions.insert(projectId: p2.id,
            startTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 9))!,
            endTime: cal.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 10))!)

        let from = cal.date(from: DateComponents(year: 2026, month: 3, day: 2))!
        let to = cal.date(from: DateComponents(year: 2026, month: 3, day: 3))!

        let report = try await reports.groupedByDay(from: from, to: to)
        #expect(report.rows.count == 2)
        #expect(report.rows[0].projectName == "alpha")
        #expect(report.rows[1].projectName == "beta")
    }
}
