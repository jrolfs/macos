// A stable-path Mach-O shim that runs privileged operations behind a single
// Full Disk Access grant.
//
// It exists purely so that access can be granted once. TCC evaluates a grant
// against the Mach-O binary being executed, not the path of a script, so
// granting FDA to a shell script grants it to /bin/bash instead and does
// nothing. The operations themselves live on nix store paths that change on
// every rebuild, which a grant cannot follow either, so the grant goes on this
// binary at a fixed /usr/local/bin path and everything else is reached through
// it.
//
// It spawns the dispatcher as a *child* and waits, rather than exec'ing it.
// That is the whole point: on exec the process image would be replaced by the
// dispatcher's interpreter and TCC would evaluate /bin/bash again, throwing
// away the grant this binary exists to hold. Staying alive as the parent keeps
// the granted binary as the responsible process for everything below it.
//
// Nothing that varies belongs in here. The grant is keyed on this binary's
// cdhash, because it is ad-hoc signed and TCC has no stable signing identity to
// use instead, so any change to these bytes revokes the grant silently and
// costs a manual re-approval. Adding an operation must not mean recompiling
// this: the list of them lives in the dispatcher.
//
// Built by `pkgs.rustTool` in overlays/default.nix.

use std::process::{Command, ExitCode};

const DISPATCH: &str = "/run/current-system/sw/bin/fda-dispatch";

fn main() -> ExitCode {
    let arguments = std::env::args_os().skip(1);

    match Command::new(DISPATCH).args(arguments).status() {
        // Deliberately not the raw wait status, which is the exit code shifted
        // left by eight: a failing run reports 256 and truncates back to a
        // successful 0 in launchd's log.
        Ok(status) => match status.code() {
            Some(code) => ExitCode::from(code as u8),
            None => ExitCode::FAILURE, // killed by a signal
        },
        Err(error) => {
            eprintln!("cannot run {DISPATCH}: {error}");
            ExitCode::FAILURE
        }
    }
}
