//  RockyCLI.swift
//  RockyCLI
//
//  Created by Argyle Bits LLC

import ArgumentParser

@main
struct RockyCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "A Swift command-line tool."
    )

    func run() throws {
        print("Hello from RockyCLI!")
    }
}