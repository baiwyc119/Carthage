//
//  Checkout.swift
//  Carthage
//
//  Created by Alan Rogers on 11/10/2014.
//  Copyright (c) 2014 Carthage. All rights reserved.
//

import CarthageKit
import Commandant
import Foundation
import LlamaKit
import ReactiveCocoa

public struct CheckoutCommand: CommandType {
	public let verb = "checkout"
	public let function = "Check out the project's dependencies"

	public func run(mode: CommandMode) -> Result<()> {
		return ColdSignal.fromResult(CheckoutOptions.evaluate(mode))
			.map { self.checkoutWithOptions($0) }
			.merge(identity)
			.wait()
	}

	/// Checks out dependencies with the given options.
	public func checkoutWithOptions(options: CheckoutOptions) -> ColdSignal<()> {
		return options.loadProject()
			.map { $0.checkoutResolvedDependencies() }
			.merge(identity)
	}
}

public struct CheckoutOptions: OptionsType {
	public let directoryPath: String
	public let useSSH: Bool
	public let useSubmodules: Bool
	public let useBinaries: Bool
	public let colorOptions: ColorOptions

	public static func create(useSSH: Bool)(useSubmodules: Bool)(useBinaries: Bool)(colorOptions: ColorOptions)(directoryPath: String) -> CheckoutOptions {
		return self(directoryPath: directoryPath, useSSH: useSSH, useSubmodules: useSubmodules, useBinaries: useBinaries, colorOptions: colorOptions)
	}

	public static func evaluate(m: CommandMode) -> Result<CheckoutOptions> {
		return evaluate(m, useBinariesAddendum: "")
	}

	public static func evaluate(m: CommandMode, useBinariesAddendum: String) -> Result<CheckoutOptions> {
		return create
			<*> m <| Option(key: "use-ssh", defaultValue: false, usage: "use SSH for downloading GitHub repositories")
			<*> m <| Option(key: "use-submodules", defaultValue: false, usage: "add dependencies as Git submodules")
			<*> m <| Option(key: "use-binaries", defaultValue: true, usage: "check out dependency repositories even when prebuilt frameworks exist" + useBinariesAddendum)
			<*> ColorOptions.evaluate(m)
			<*> m <| Option(defaultValue: NSFileManager.defaultManager().currentDirectoryPath, usage: "the directory containing the Carthage project")
	}

	/// Attempts to load the project referenced by the options, and configure it
	/// accordingly.
	public func loadProject() -> ColdSignal<Project> {
		if let directoryURL = NSURL.fileURLWithPath(self.directoryPath, isDirectory: true) {
			let project = Project(directoryURL: directoryURL)
			project.preferHTTPS = !self.useSSH
			project.useSubmodules = self.useSubmodules
			project.useBinaries = self.useBinaries
			project.projectEvents.observe(ProjectEventSink(colorOptions: colorOptions))

			return project
				.migrateIfNecessary(colorOptions)
				.on(next: carthage.println)
				.then(.single(project))
		} else {
			return .error(CarthageError.InvalidArgument(description: "Invalid project path: \(directoryPath)").error)
		}
	}
}
