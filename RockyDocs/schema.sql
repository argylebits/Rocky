-- Rocky database schema
-- Migration v1

CREATE TABLE IF NOT EXISTS migrations (
    version     INTEGER  PRIMARY KEY,
    applied_at  DATETIME NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS projects (
    id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    parent_id   INTEGER  REFERENCES projects(id),
    name        TEXT     NOT NULL UNIQUE,
    created_at  DATETIME NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS sessions (
    id          INTEGER  PRIMARY KEY AUTOINCREMENT,
    project_id  INTEGER  NOT NULL REFERENCES projects(id),
    start_time  DATETIME NOT NULL DEFAULT (datetime('now')),
    end_time    DATETIME
);

-- Useful indexes
CREATE INDEX IF NOT EXISTS idx_sessions_project_id ON sessions(project_id);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time);
CREATE INDEX IF NOT EXISTS idx_sessions_end_time   ON sessions(end_time);
