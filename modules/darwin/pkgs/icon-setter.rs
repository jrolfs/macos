// icon-setter: write a custom icon into an app bundle's Icon\r resource fork.
//
// Writes the resource fork and the FinderInfo xattr by hand through plain POSIX
// file I/O, completely bypassing NSWorkspace and osascript. That is what lets
// it run from a LaunchDaemon, where TCC and com.apple.macl block the
// NSWorkspace API.
//
// Accepts both .icns and .png input; PNGs are wrapped in an icns container on
// the fly (a single ic10 entry, which macOS downscales as needed).
//
// The xattr and Icon\r plumbing it shares with folder-icon.rs lives in
// custom-icon.rs. Built by `pkgs.rustTool` in overlays/default.nix.

use custom_icon as icon;
use std::fs;
use std::io::Write;
use std::path::Path;
use std::process::ExitCode;

/// 'icns' resource ID -16455, as the unsigned value stored in the map.
const RESOURCE_ID: u16 = 0xBFB9;

/// `.icns` is used as-is; a PNG is wrapped in a minimal single-entry (`ic10`)
/// icns container so macOS can render it at any size.
fn to_icns(raw: Vec<u8>, icon: &Path) -> Result<Vec<u8>, String> {
    if raw.starts_with(b"icns") {
        return Ok(raw);
    }
    if !raw.starts_with(&[0x89, b'P', b'N', b'G']) {
        return Err(format!("unsupported format: {}", icon.display()));
    }

    let entry_length = 8 + raw.len() as u32;
    let total = 8 + entry_length;

    let mut icns = Vec::with_capacity(total as usize);
    icns.extend_from_slice(b"icns");
    icns.extend_from_slice(&total.to_be_bytes());
    icns.extend_from_slice(b"ic10");
    icns.extend_from_slice(&entry_length.to_be_bytes());
    icns.extend_from_slice(&raw);
    Ok(icns)
}

/// Build the resource fork for a single 'icns' resource (ID -16455).
///
/// Layout:  256-byte header  |  data section  |  50-byte resource map
///
/// Data section : 4-byte big-endian length + raw icns bytes
/// Resource map :
///   0-15   copy of header
///  16-19   reserved handle
///  20-21   file reference number
///  22-23   attributes
///  24-25   type list offset from map start  (28)
///  26-27   name list offset from map start  (50)
///  28-29   type count - 1                   (0)
///  30-33   type  'icns'
///  34-35   resource count - 1               (0)
///  36-37   ref list offset from type list   (10)
///  38-39   resource ID                      (-16455 / 0xBFB9)
///  40-41   name offset                      (0xFFFF = none)
///  42      attributes                       (0)
///  43-45   data offset from data section    (0)
///  46-49   reserved                         (0)
fn resource_fork(icns: &[u8]) -> Vec<u8> {
    let data_offset: u32 = 256;
    let data_length = icns.len() as u32 + 4;
    let map_offset = data_offset + data_length;
    let map_length: u32 = 50;

    let mut buffer = vec![0u8; (map_offset + map_length) as usize];

    buffer[0..4].copy_from_slice(&data_offset.to_be_bytes());
    buffer[4..8].copy_from_slice(&map_offset.to_be_bytes());
    buffer[8..12].copy_from_slice(&data_length.to_be_bytes());
    buffer[12..16].copy_from_slice(&map_length.to_be_bytes());

    let data = data_offset as usize;
    buffer[data..data + 4].copy_from_slice(&(icns.len() as u32).to_be_bytes());
    buffer[data + 4..data + 4 + icns.len()].copy_from_slice(icns);

    let header: [u8; 16] = buffer[0..16].try_into().unwrap();
    let map = map_offset as usize;
    buffer[map..map + 16].copy_from_slice(&header);
    buffer[map + 24..map + 26].copy_from_slice(&28u16.to_be_bytes());
    buffer[map + 26..map + 28].copy_from_slice(&(map_length as u16).to_be_bytes());
    buffer[map + 28..map + 30].copy_from_slice(&0u16.to_be_bytes());
    buffer[map + 30..map + 34].copy_from_slice(b"icns");
    buffer[map + 34..map + 36].copy_from_slice(&0u16.to_be_bytes());
    buffer[map + 36..map + 38].copy_from_slice(&10u16.to_be_bytes());
    buffer[map + 38..map + 40].copy_from_slice(&RESOURCE_ID.to_be_bytes());
    buffer[map + 40..map + 42].copy_from_slice(&0xFFFFu16.to_be_bytes());

    buffer
}

/// Create or truncate Icon\r, deliberately *not* unlinking first.
///
/// Deleting the existing icon and only then discovering we cannot rewrite it is
/// exactly what leaves a bundle with kHasCustomIcon set but no Icon\r, which is
/// the generic folder icon. That happens on com.apple.macl'd bundles when the
/// process lacks Full Disk Access: the unlink succeeds but the recreate fails
/// with EPERM. Truncating is non-destructive on failure. The one case it cannot
/// handle is an Icon\r left root-owned by the old root LaunchDaemon, which
/// fails with EACCES; there, removing and recreating is safe because the bundle
/// directory itself is user-writable.
fn create_icon_file(path: &Path) -> std::io::Result<()> {
    match fs::File::create(path) {
        Ok(_) => Ok(()),
        Err(error) if error.kind() == std::io::ErrorKind::PermissionDenied => {
            fs::remove_file(path)?;
            fs::File::create(path).map(|_| ())
        }
        Err(error) => Err(error),
    }
}

fn run(app: &Path, source: &Path) -> Result<(), String> {
    if !app.is_dir() {
        return Err(format!("not a directory: {}", app.display()));
    }

    let raw = fs::read(source).map_err(|e| format!("cannot open: {} ({e})", source.display()))?;
    if raw.len() < 8 {
        return Err(format!("icon too small: {}", source.display()));
    }
    let icns = to_icns(raw, source)?;

    let icon_file = icon::icon_file(app);
    create_icon_file(&icon_file)
        .map_err(|e| format!("cannot create Icon\\r in {}: {e}", app.display()))?;

    // Past this point the bundle has an empty Icon\r, so every failure has to
    // undo it and clear the flag rather than leave a generic folder behind.
    let abandon = |message: String| -> String {
        icon::abandon_custom_icon(app);
        message
    };

    let buffer = resource_fork(&icns);
    let fork = icon_file.join("..namedfork/rsrc");
    let mut file = fs::File::create(&fork)
        .map_err(|e| abandon(format!("cannot write resource fork for {}: {e}", app.display())))?;
    file.write_all(&buffer)
        .map_err(|e| abandon(format!("short write for {}: {e}", app.display())))?;
    drop(file);

    let _ = icon::hide(&icon_file);

    icon::set_custom_icon_flag(app, true)
        .map_err(|e| format!("cannot set FinderInfo for {}: {e}", app.display()))?;

    let _ = icon::touch(app);
    Ok(())
}

fn main() -> ExitCode {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 3 {
        eprintln!("usage: icon-setter APP_PATH ICON_PATH");
        return ExitCode::FAILURE;
    }

    let (app, source) = (Path::new(&args[1]), Path::new(&args[2]));
    println!("icon_path: {}", source.display());
    println!("app_path: {}", app.display());

    match run(app, source) {
        Ok(()) => ExitCode::SUCCESS,
        Err(message) => {
            eprintln!("{message}");
            ExitCode::FAILURE
        }
    }
}
