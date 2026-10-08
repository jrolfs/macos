// A stable-path Mach-O shim that runs the real icon-customizer script.
//
// It exists purely so Full Disk Access can be granted once. TCC evaluates a
// grant against the Mach-O binary being executed, not the path of a script, so
// granting FDA to a shell script grants it to /bin/bash instead and does
// nothing. The script lives on a nix store path that changes on every rebuild,
// which a grant cannot follow either, so the grant goes on this binary at a
// fixed /usr/local/bin path and the script is reached through it.
//
// It spawns the script as a *child* and waits, rather than exec'ing it. That is
// the whole point: on exec the process image would be replaced by the script's
// interpreter and TCC would evaluate /bin/bash again, throwing away the grant
// this binary exists to hold. Staying alive as the parent keeps the granted
// binary as the responsible process for the child's file access.
//
// Built by `pkgs.rustTool` in overlays/default.nix.

use std::process::{Command, ExitCode};

const SCRIPT: &str = "/run/current-system/sw/bin/icon-customizer";

fn main() -> ExitCode {
    match Command::new(SCRIPT).status() {
        // Unlike the C version this returned, which handed back the raw wait
        // status from system(3) — that is the exit code shifted left by eight,
        // so a failing run reported 256 and truncated to a successful 0 in
        // launchd's log.
        Ok(status) => match status.code() {
            Some(code) => ExitCode::from(code as u8),
            None => ExitCode::FAILURE, // killed by a signal
        },
        Err(error) => {
            eprintln!("cannot run {SCRIPT}: {error}");
            ExitCode::FAILURE
        }
    }
}
