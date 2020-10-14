// Copyright (c) 2019 Spotify AB.
//
// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import Foundation
import Commandant
import XCLogParser
#if !swift(>=5.0)
import Result
#endif

struct ParseCommand: CommandProtocol {
    typealias Options = ParseOptions
    let verb = "parse"
    let function = "Parses the content of an xcactivitylog file"

    func run(_ options: ParseOptions) -> Result<(), CommandantError<Swift.Error>> {
        Log.start("Full Command")
        if !options.hasValidLogOptions() {
            return .failure(.usageError(description:
                """
                    Please, provide a way to locate the .xcactivity log of your project.
                    You can use --file or --project or --workspace or --xcodeproj. \n
                    Type `xclogparser help parse` to get more information.`
                    """))
        }
        if options.reporter.isEmpty {
            return .failure(.usageError(description:
                """
                You need to specify a reporter. Type `xclogparser help parse` to see the available ones.
                """))
        }
        guard let reporter = Reporter(rawValue: options.reporter) else {
            return .failure(.usageError(description:
                """
                \(options.reporter) is not a valid reporter. Please provide a valid reporter to use.
                Type `xclogparser help parse` to see the available ones.
                """))
        }
        let commandHandler = CommandHandler()
        let logOptions = LogOptions(projectName: options.projectName,
                                    xcworkspacePath: options.workspace,
                                    xcodeprojPath: options.xcodeproj,
                                    derivedDataPath: options.derivedData,
                                    xcactivitylogPath: options.logFile,
                                    strictProjectName: options.strictProjectName)
        let actionOptions = ActionOptions(reporter: reporter,
                                          outputPath: options.output,
                                          redacted: options.redacted,
                                          withoutBuildSpecificInformation: options.withoutBuildSpecificInformation,
                                          machineName: options.machineName.isEmpty ? nil : options.machineName,
                                          rootOutput: options.rootOutput)
        let action = Action.parse(options: actionOptions)
        let command = Command(logOptions: logOptions, action: action)
        do {
            try commandHandler.handle(command: command)
        } catch {
            return.failure(.commandError(error))
        }
        Log.end("Full Command")
        return .success(())
    }

}

struct ParseOptions: OptionsProtocol {
    let logFile: String
    let derivedData: String
    let projectName: String
    let workspace: String
    let xcodeproj: String
    let reporter: String
    let machineName: String
    let redacted: Bool
    let withoutBuildSpecificInformation: Bool
    let strictProjectName: Bool
    let output: String
    let rootOutput: String

    static func create(_ logFile: String)
        -> (_ derivedData: String)
        -> (_ projectName: String)
        -> (_ workspace: String)
        -> (_ xcodeproj: String)
        -> (_ reporter: String)
        -> (_ machineName: String)
        -> (_ redacted: Bool)
        -> (_ withoutBuildSpecificInformation: Bool)
        -> (_ strictProjectName: Bool)
        -> (_ output: String)
        -> (_ rootOutput: String) -> ParseOptions {
            return { derivedData in { projectName in { workspace in { xcodeproj in { reporter in { machineName
                in { redacted in { withoutBuildSpecificInformation in { strictProjectName in { output in { rootOutput in
            self.init(logFile: logFile,
                      derivedData: derivedData,
                      projectName: projectName,
                      workspace: workspace,
                      xcodeproj: xcodeproj,
                      reporter: reporter,
                      machineName: machineName,
                      redacted: redacted,
                      withoutBuildSpecificInformation: withoutBuildSpecificInformation,
                      strictProjectName: strictProjectName,
                      output: output,
                      rootOutput: rootOutput)
                    }}}}}}}}}}}
    }

    static func evaluate(_ mode: CommandMode) -> Result<ParseOptions, CommandantError<CommandantError<Swift.Error>>> {
        return create
            <*> mode <| fileOption
            <*> mode <| derivedDataOption
			<*> mode <| projectOption
            <*> mode <| workspaceOption
            <*> mode <| xcodeprojOption
            <*> mode <| Option(
                key: "reporter",
                defaultValue: "",
                usage: "The reporter to use. It could be `json`, `flatJson`, " +
		"`summaryJson`, `chromeTracer`, `html` or `btr`")
            <*> mode <| Option(
                key: "machine_name",
                defaultValue: "",
                usage: "Optional. The name of the machine." +
                "If not specified, the host name will be used.")
            <*> mode <| redactedSwitch
            <*> mode <| withoutBuildSpecificInformationSwitch
            <*> mode <| strictProjectNameSwitch
            <*> mode <| outputOption
            <*> mode <| rootOutputOption

    }

    func hasValidLogOptions() -> Bool {
        return !logFile.isEmpty || !projectName.isEmpty || !workspace.isEmpty || !xcodeproj.isEmpty
    }

}
