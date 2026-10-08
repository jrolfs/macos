// folder-icon: set, clear and report the macOS 26 folder icon customisation.
//
// This is the mechanism behind Finder's "Customize Folder…" popover, which is
// *not* the classic Icon\r resource fork that icon-setter.rs writes. Two
// things have to be true for the system to composite a glyph onto its own
// folder artwork:
//
//   1. an extended attribute `com.apple.icon.folder#S` holding JSON —
//      {"sym":"<SF Symbol name>"} or {"emoji":"<characters>"}
//   2. kHasCustomIcon (0x0400) set in the folder's com.apple.FinderInfo
//
// Neither alone is enough: the xattr without the flag renders a plain folder,
// and the flag without either an xattr or an Icon\r renders a generic one.
// The `#S` suffix is Apple's xattr naming convention for "syncable" and is a
// literal part of the name, and getxattr/setxattr want it spelled out.
//
// The format was recovered by interposing getxattr(2) around
// -[ISFolderIconConfiguration initWithURL:], which reads the private NSURL
// resource keys _NSURLIconSymbolNameKey, _NSURLIconEmojiKey and
// _NSURLTagColorIndexKey. Writing the xattr directly gets the same result
// without linking the private IconServices framework. The tint half of the
// popover is deliberately not implemented here: it is stored as an ordinary
// Finder tag, so it belongs to whatever manages tags, not to this tool.
//
// The xattr and Icon\r plumbing it shares with icon-setter.rs lives in
// custom-icon.rs. Built by `pkgs.rustTool` in overlays/default.nix.

use custom_icon as icon;
use std::path::Path;
use std::process::ExitCode;

const XATTR_NAME: &str = "com.apple.icon.folder#S";

/// Resilio Sync drops a 1.2 MB Icon\r into every share it creates. The xattr
/// takes precedence over it, but it is dead weight and it is what makes these
/// folders the only ones in $HOME that don't look like folders, so taking one
/// over removes it. Note that file lives *inside* the share, so on a synced
/// folder the deletion propagates to every peer.
fn remove_legacy_icon(path: &Path) {
    if let Err(error) = icon::remove_icon_file(path) {
        eprintln!("cannot remove Icon\\r in {}: {error}", path.display());
    }
}

fn report(path: &Path) {
    let mut value = [0u8; 1024];
    let stored = icon::get_xattr(path, XATTR_NAME, &mut value)
        .map(|size| String::from_utf8_lossy(&value[..size]).into_owned());

    println!(
        "{} flag={} legacy={}",
        stored.as_deref().unwrap_or("none"),
        icon::has_custom_icon_flag(path) as u8,
        icon::icon_file(path).exists() as u8
    );
}

/// SF Symbol names are [a-z0-9.] and emoji are plain UTF-8, so neither needs
/// JSON escaping. Rather than carry an escaper for input that should never
/// contain these, refuse the two characters that would break the document.
fn json_safe(value: &str) -> bool {
    !value.contains('"') && !value.contains('\\')
}

fn usage() -> ExitCode {
    eprintln!("usage: folder-icon show PATH");
    eprintln!("       folder-icon clear PATH");
    eprintln!("       folder-icon set PATH symbol NAME");
    eprintln!("       folder-icon set PATH emoji CHARACTERS");
    ExitCode::from(2)
}

fn set(path: &Path, kind: &str, value: &str) -> ExitCode {
    let key = match kind {
        "symbol" => "sym",
        "emoji" => "emoji",
        _ => {
            eprintln!("unknown kind: {kind} (want symbol or emoji)");
            return ExitCode::from(2);
        }
    };

    if !json_safe(value) {
        eprintln!("value may not contain a quote or backslash: {value}");
        return ExitCode::from(2);
    }

    let json = format!("{{\"{key}\":\"{value}\"}}");

    // The xattr goes on before the flag. A folder advertising a custom icon it
    // cannot load renders as a generic folder, so the window where that is true
    // should not exist.
    if let Err(error) = icon::set_xattr(path, XATTR_NAME, json.as_bytes()) {
        eprintln!("cannot set {XATTR_NAME} on {}: {error}", path.display());
        return ExitCode::FAILURE;
    }

    remove_legacy_icon(path);

    if let Err(error) = icon::set_custom_icon_flag(path, true) {
        eprintln!("cannot set FinderInfo on {}: {error}", path.display());
        return ExitCode::FAILURE;
    }

    let _ = icon::touch(path);
    ExitCode::SUCCESS
}

fn clear(path: &Path) -> ExitCode {
    if let Err(error) = icon::remove_xattr(path, XATTR_NAME) {
        eprintln!("cannot remove {XATTR_NAME} on {}: {error}", path.display());
        return ExitCode::FAILURE;
    }

    remove_legacy_icon(path);

    if let Err(error) = icon::set_custom_icon_flag(path, false) {
        eprintln!("cannot clear FinderInfo on {}: {error}", path.display());
        return ExitCode::FAILURE;
    }

    let _ = icon::touch(path);
    ExitCode::SUCCESS
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 3 {
        return usage();
    }

    let (command, path) = (args[1].as_str(), Path::new(&args[2]));
    if !path.is_dir() {
        eprintln!("not a directory: {}", path.display());
        return ExitCode::FAILURE;
    }

    match command {
        "show" => {
            report(path);
            ExitCode::SUCCESS
        }
        "clear" => clear(path),
        "set" => {
            if args.len() < 5 {
                eprintln!("set needs a kind (symbol|emoji) and a value");
                return ExitCode::from(2);
            }
            set(path, &args[3], &args[4])
        }
        _ => {
            eprintln!("unknown command: {command}");
            ExitCode::from(2)
        }
    }
}
