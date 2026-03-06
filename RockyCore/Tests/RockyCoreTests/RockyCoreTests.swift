import Testing
import Foundation
@testable import RockyCore

@Suite("Database and Migrations")
struct DatabaseTests {
    @Test("Opens in-memory database and runs migrations")
    func openAndMigrate() async throws {
        let db = try await Database.open(at: ":memory:")
        let rows = try await db.query("SELECT version FROM migrations")
        #expect(rows.count == 1)
        #expect(rows[0].column("version")?.integer == 1)
        try await db.close()
    }

    @Test("Tables exist after migration")
    func tablesExist() async throws {
        let db = try await Database.open(at: ":memory:")
        let tables = try await db.query(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        )
        let names = tables.compactMap { $0.column("name")?.string }
        #expect(names.contains("projects"))
        #expect(names.contains("sessions"))
        #expect(names.contains("migrations"))
        try await db.close()
    }
}

@Suite("ProjectService")
struct ProjectServiceTests {
    private func setup() async throws -> (Database, ProjectService) {
        let db = try await Database.open(at: ":memory:")
        return (db, ProjectService(db: db))
    }

    @Test("findOrCreate creates a new project")
    func createProject() async throws {
        let (db, service) = try await setup()
        let project = try await service.findOrCreate(name: "acme-corp")
        #expect(project.name == "acme-corp")
        #expect(project.id > 0)
        #expect(project.parentId == nil)
        try await db.close()
    }

    @Test("findOrCreate returns existing project")
    func findExisting() async throws {
        let (db, service) = try await setup()
        let first = try await service.findOrCreate(name: "acme-corp")
        let second = try await service.findOrCreate(name: "acme-corp")
        #expect(first.id == second.id)
        try await db.close()
    }

    @Test("getByName is case-insensitive")
    func caseInsensitive() async throws {
        let (db, service) = try await setup()
        _ = try await service.findOrCreate(name: "Acme-Corp")
        let found = try await service.getByName("acme-corp")
        #expect(found != nil)
        #expect(found?.name == "Acme-Corp")
        try await db.close()
    }

    @Test("getByName returns nil for unknown project")
    func unknownProject() async throws {
        let (db, service) = try await setup()
        let found = try await service.getByName("nonexistent")
        #expect(found == nil)
        try await db.close()
    }

    @Test("list returns all projects")
    func listProjects() async throws {
        let (db, service) = try await setup()
        _ = try await service.findOrCreate(name: "alpha")
        _ = try await service.findOrCreate(name: "beta")
        _ = try await service.findOrCreate(name: "gamma")
        let projects = try await service.list()
        #expect(projects.count == 3)
        try await db.close()
    }

    @Test("getById returns correct project")
    func getById() async throws {
        let (db, service) = try await setup()
        let created = try await service.findOrCreate(name: "test-project")
        let found = try await service.getById(created.id)
        #expect(found != nil)
        #expect(found?.name == "test-project")
        try await db.close()
    }
}

@Suite("SessionService")
struct SessionServiceTests {
    private func setup() async throws -> (Database, ProjectService, SessionService) {
        let db = try await Database.open(at: ":memory:")
        return (db, ProjectService(db: db), SessionService(db: db))
    }

    @Test("start creates a running session")
    func startSession() async throws {
        let (db, projects, sessions) = try await setup()
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == project.id)
        #expect(running[0].isRunning)
        try await db.close()
    }

    @Test("hasRunningSession detects active timer")
    func hasRunning() async throws {
        let (db, projects, sessions) = try await setup()
        let project = try await projects.findOrCreate(name: "acme-corp")
        #expect(try await sessions.hasRunningSession(projectId: project.id) == false)
        try await sessions.start(projectId: project.id)
        #expect(try await sessions.hasRunningSession(projectId: project.id) == true)
        try await db.close()
    }

    @Test("stop sets end_time on session")
    func stopSession() async throws {
        let (db, projects, sessions) = try await setup()
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let stopped = try await sessions.stop(projectId: project.id)
        #expect(stopped.endTime != nil)
        #expect(!stopped.isRunning)
        let running = try await sessions.getRunning()
        #expect(running.isEmpty)
        try await db.close()
    }

    @Test("stopAll stops all running sessions")
    func stopAll() async throws {
        let (db, projects, sessions) = try await setup()
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        let stopped = try await sessions.stopAll()
        #expect(stopped.count == 2)
        #expect(stopped.allSatisfy { !$0.isRunning })
        let running = try await sessions.getRunning()
        #expect(running.isEmpty)
        try await db.close()
    }

    @Test("concurrent timers on different projects")
    func concurrentTimers() async throws {
        let (db, projects, sessions) = try await setup()
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 2)
        try await db.close()
    }

    @Test("stop one timer leaves other running")
    func stopOneOfTwo() async throws {
        let (db, projects, sessions) = try await setup()
        let p1 = try await projects.findOrCreate(name: "project-1")
        let p2 = try await projects.findOrCreate(name: "project-2")
        try await sessions.start(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        _ = try await sessions.stop(projectId: p1.id)
        let running = try await sessions.getRunning()
        #expect(running.count == 1)
        #expect(running[0].projectId == p2.id)
        try await db.close()
    }

    @Test("getRunningWithProjects returns session and project data")
    func runningWithProjects() async throws {
        let (db, projects, sessions) = try await setup()
        let project = try await projects.findOrCreate(name: "acme-corp")
        try await sessions.start(projectId: project.id)
        let running = try await sessions.getRunningWithProjects()
        #expect(running.count == 1)
        #expect(running[0].0.projectId == project.id)
        #expect(running[0].1.name == "acme-corp")
        try await db.close()
    }

    @Test("stop throws when no running session")
    func stopNoRunning() async throws {
        let (db, projects, sessions) = try await setup()
        let project = try await projects.findOrCreate(name: "acme-corp")
        await #expect(throws: RockyCoreError.self) {
            try await sessions.stop(projectId: project.id)
        }
        try await db.close()
    }
}

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

@Suite("ReportService")
struct ReportServiceTests {
    private func setup() async throws -> (Database, ProjectService, SessionService, ReportService) {
        let db = try await Database.open(at: ":memory:")
        return (db, ProjectService(db: db), SessionService(db: db), ReportService(db: db))
    }

    @Test("allProjectsWithStatus shows running projects first")
    func statusOrder() async throws {
        let (db, projects, sessions, reports) = try await setup()
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
        try await db.close()
    }

    @Test("totals calculates project durations in range")
    func totals() async throws {
        let (db, projects, sessions, reports) = try await setup()
        let project = try await projects.findOrCreate(name: "test")
        try await sessions.start(projectId: project.id)
        _ = try await sessions.stop(projectId: project.id)

        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let result = try await reports.totals(from: start, to: end)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "test")
        try await db.close()
    }

    @Test("totals filters by project")
    func totalsFiltered() async throws {
        let (db, projects, sessions, reports) = try await setup()
        let p1 = try await projects.findOrCreate(name: "included")
        let p2 = try await projects.findOrCreate(name: "excluded")
        try await sessions.start(projectId: p1.id)
        _ = try await sessions.stop(projectId: p1.id)
        try await sessions.start(projectId: p2.id)
        _ = try await sessions.stop(projectId: p2.id)

        let now = Date()
        let start = Calendar.current.startOfDay(for: now)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!

        let result = try await reports.totals(from: start, to: end, projectId: p1.id)
        #expect(result.entries.count == 1)
        #expect(result.entries[0].projectName == "included")
        try await db.close()
    }
}
