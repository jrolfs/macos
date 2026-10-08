// Shared plumbing for the two custom-icon tools: extended attributes, the
// FinderInfo flag, and the Icon\r file.
//
// icon-setter.rs and folder-icon.rs set custom icons by two different
// mechanisms (a resource fork versus a JSON xattr), but both have to agree
// about the parts macOS actually keys off: the kHasCustomIcon bit in
// FinderInfo, and the Icon\r file beside it. Those got the same subtle rule
// wrong independently once already, so they live here now.
//
// The rule is: a directory must never be left with kHasCustomIcon set and no
// readable icon. Finder is then told a custom icon exists, fails to load one,
// and falls back to a *generic folder*, which is worse than the stock icon and
// looks like corruption. Every failure path has to clear the flag.
//
// This is also the only file in the pair with `unsafe` in it. Everything the
// tools need beyond std is a handful of POSIX calls, declared here once and
// exposed as a safe API, so neither tool carries an extern block of its own.
//
// Built by `pkgs.rustLibrary` in overlays/default.nix.

use std::ffi::{c_char, c_int, c_uint, CString};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

unsafe extern "C" {
    fn getxattr(path: *const c_char, name: *const c_char, value: *mut u8, size: usize,
                position: u32, options: c_int) -> isize;
    fn setxattr(path: *const c_char, name: *const c_char, value: *const u8, size: usize,
                position: u32, options: c_int) -> c_int;
    fn removexattr(path: *const c_char, name: *const c_char, options: c_int) -> c_int;
    fn chflags(path: *const c_char, flags: c_uint) -> c_int;
    fn utimes(path: *const c_char, times: *const u8) -> c_int;
}

pub const FINDER_INFO: &str = "com.apple.FinderInfo";

/// High byte of kHasCustomIcon (0x0400), as it sits in FinderInfo byte 8.
pub const HAS_CUSTOM_ICON: u8 = 0x04;

const UF_HIDDEN: c_uint = 0x8000;
const ENOATTR: i32 = 93;

fn cpath(path: &Path) -> io::Result<CString> {
    CString::new(path.as_os_str().as_encoded_bytes())
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "path contains a NUL"))
}

fn cname(name: &str) -> io::Result<CString> {
    CString::new(name)
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidInput, "name contains a NUL"))
}

/// The `Icon\r` file macOS looks for inside a directory with a custom icon.
/// The trailing carriage return is part of the name, which is why this is a
/// function rather than something each caller spells out.
pub fn icon_file(directory: &Path) -> PathBuf {
    directory.join("Icon\r")
}

/// Returns `None` when the attribute is absent, rather than treating that as an
/// error: no FinderInfo at all is the ordinary case for an untouched folder.
pub fn get_xattr(path: &Path, name: &str, buffer: &mut [u8]) -> Option<usize> {
    let (path, name) = (cpath(path).ok()?, cname(name).ok()?);
    let size = unsafe {
        getxattr(path.as_ptr(), name.as_ptr(), buffer.as_mut_ptr(), buffer.len(), 0, 0)
    };
    if size < 0 { None } else { Some(size as usize) }
}

pub fn set_xattr(path: &Path, name: &str, value: &[u8]) -> io::Result<()> {
    let (path, name) = (cpath(path)?, cname(name)?);
    let result =
        unsafe { setxattr(path.as_ptr(), name.as_ptr(), value.as_ptr(), value.len(), 0, 0) };
    if result != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// Removing an attribute that was never there is success, so callers can clear
/// unconditionally without first checking.
pub fn remove_xattr(path: &Path, name: &str) -> io::Result<()> {
    let (path, name) = (cpath(path)?, cname(name)?);
    if unsafe { removexattr(path.as_ptr(), name.as_ptr(), 0) } != 0 {
        let error = io::Error::last_os_error();
        if error.raw_os_error() != Some(ENOATTR) {
            return Err(error);
        }
    }
    Ok(())
}

/// Reads the 32-byte FinderInfo blob, or zeroes if there is none.
///
/// A blob of an unexpected length is an error rather than something to pave
/// over: FinderInfo is a shared struct and writing a fresh one back would drop
/// whatever else was in it.
pub fn read_finder_info(path: &Path) -> io::Result<[u8; 32]> {
    let mut info = [0u8; 32];
    match get_xattr(path, FINDER_INFO, &mut info) {
        None => Ok(info),
        Some(32) => Ok(info),
        Some(size) => Err(io::Error::new(
            io::ErrorKind::InvalidData,
            format!("unexpected FinderInfo size ({size})"),
        )),
    }
}

pub fn has_custom_icon_flag(path: &Path) -> bool {
    read_finder_info(path).is_ok_and(|info| info[8] & HAS_CUSTOM_ICON != 0)
}

/// Read-modify-write the kHasCustomIcon bit.
///
/// Read-modify-write rather than assignment, because FinderInfo is a shared
/// 32-byte struct: Resilio Sync leaves the invisible bit on its own Icon\r, and
/// clobbering the whole blob would drop fields these tools have no business
/// touching.
pub fn set_custom_icon_flag(path: &Path, on: bool) -> io::Result<()> {
    let mut info = read_finder_info(path)?;

    if on {
        info[8] |= HAS_CUSTOM_ICON;
    } else {
        info[8] &= !HAS_CUSTOM_ICON;
    }

    // An all-zero FinderInfo is indistinguishable from none, and leaving a
    // zeroed blob behind makes `xattr -l` noisier than the path deserves.
    if info.iter().all(|byte| *byte == 0) {
        return remove_xattr(path, FINDER_INFO);
    }

    set_xattr(path, FINDER_INFO, &info)
}

/// Removing an Icon\r that isn't there is success, so a failure path can call
/// this without knowing how far the write got.
pub fn remove_icon_file(directory: &Path) -> io::Result<()> {
    match fs::remove_file(icon_file(directory)) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error),
    }
}

/// Clear the flag and drop the icon file, so a path is never left advertising a
/// custom icon it cannot load. Best effort by design: it runs on failure paths,
/// where there is nothing useful left to do about a second failure.
pub fn abandon_custom_icon(directory: &Path) {
    let _ = remove_icon_file(directory);
    let _ = set_custom_icon_flag(directory, false);
}

pub fn hide(path: &Path) -> io::Result<()> {
    let flags = fs::metadata(path).map(|metadata| {
        use std::os::macos::fs::MetadataExt;
        metadata.st_flags()
    })?;
    if unsafe { chflags(cpath(path)?.as_ptr(), flags | UF_HIDDEN) } != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

/// Bump the mtime so Finder notices the icon changed.
pub fn touch(path: &Path) -> io::Result<()> {
    if unsafe { utimes(cpath(path)?.as_ptr(), std::ptr::null()) } != 0 {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}
