// Holding the PS/Home button on any gamepad runs a command: on Irulan, the
// switch between the emulator station and the desktop.
//
// Reads /dev/input/event* directly rather than through SDL or a desktop's
// input stack, so it works on whichever virtual terminal is showing,
// including a text console, and needs nothing but root. Devices are only
// read, never grabbed, so the button still reaches whatever else is
// listening (RetroArch opens its menu on a short press). Built by
// `pkgs.rustTool` in overlays/default.nix.
//
// usage: arcade-hotkey <command> [arguments...]

use std::collections::HashSet;
use std::env;
use std::fs::{self, File};
use std::io::Read;
use std::process::{self, Command};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

const EV_KEY: u16 = 0x01;
const BTN_MODE: u16 = 0x13c;

// Every gamepad reports this button, and no keyboard, mouse or the
// DualSense's separate touchpad and motion-sensor devices do, which makes it
// the test for "is this a controller".
const BTN_SOUTH: usize = 0x130;

// Long enough that a tap meant for RetroArch's menu doesn't switch sessions.
const HOLD: Duration = Duration::from_millis(900);

// A held button can only switch once, and two controllers can't bounce the
// screen back and forth between them.
const COOLDOWN: Duration = Duration::from_secs(2);

// struct input_event on 64-bit Linux: a 16-byte timeval, then u16 type,
// u16 code and i32 value.
const EVENT_SIZE: usize = 24;

fn is_gamepad(event: &str) -> bool {
    let path = format!("/sys/class/input/{event}/device/capabilities/key");
    let Ok(bits) = fs::read_to_string(path) else {
        return false;
    };

    // Space-separated hex words, most significant first, each as wide as a
    // C long. Trailing zero words are omitted, so count from the end.
    let words: Vec<&str> = bits.split_whitespace().collect();
    let index = BTN_SOUTH / 64;

    let Some(position) = words.len().checked_sub(index + 1) else {
        return false;
    };

    u64::from_str_radix(words[position], 16)
        .map(|word| word & (1 << (BTN_SOUTH % 64)) != 0)
        .unwrap_or(false)
}

fn fire(command: &[String], last: &Mutex<Option<Instant>>) {
    let mut last = last.lock().unwrap();

    if last.is_some_and(|time| time.elapsed() < COOLDOWN) {
        return;
    }

    *last = Some(Instant::now());

    if let Err(error) = Command::new(&command[0]).args(&command[1..]).status() {
        eprintln!("arcade-hotkey: could not run {}: {error}", command[0]);
    }
}

fn watch(
    name: String,
    command: Arc<Vec<String>>,
    watched: Arc<Mutex<HashSet<String>>>,
    last: Arc<Mutex<Option<Instant>>>,
) {
    if let Ok(mut device) = File::open(format!("/dev/input/{name}")) {
        eprintln!("arcade-hotkey: watching {name}");

        // Which press the button is in, or 0 when it's up. A timer only fires
        // if the press that started it is still the current one.
        let held = Arc::new(AtomicU64::new(0));
        let mut presses = 0u64;
        let mut buffer = [0u8; EVENT_SIZE];

        // A read error is the controller going away (disconnected, out of
        // battery), which ends this thread; the scan picks it up again when
        // it reconnects.
        while device.read_exact(&mut buffer).is_ok() {
            let kind = u16::from_ne_bytes([buffer[16], buffer[17]]);
            let code = u16::from_ne_bytes([buffer[18], buffer[19]]);
            let value = i32::from_ne_bytes([buffer[20], buffer[21], buffer[22], buffer[23]]);

            if kind != EV_KEY || code != BTN_MODE {
                continue;
            }

            match value {
                1 => {
                    presses += 1;
                    held.store(presses, Ordering::SeqCst);

                    let press = presses;
                    let held = Arc::clone(&held);
                    let command = Arc::clone(&command);
                    let last = Arc::clone(&last);

                    thread::spawn(move || {
                        thread::sleep(HOLD);

                        if held.load(Ordering::SeqCst) == press {
                            fire(&command, &last);
                        }
                    });
                }
                0 => held.store(0, Ordering::SeqCst),
                // 2 is key repeat, which a held button sends continuously.
                _ => {}
            }
        }
    }

    watched.lock().unwrap().remove(&name);
}

fn main() {
    let command: Vec<String> = env::args().skip(1).collect();

    if command.is_empty() {
        eprintln!("usage: arcade-hotkey <command> [arguments...]");
        process::exit(64);
    }

    let command = Arc::new(command);
    let watched = Arc::new(Mutex::new(HashSet::new()));
    let last = Arc::new(Mutex::new(None));

    // Polled rather than notified: Bluetooth controllers come and go, and a
    // two-second delay before a newly paired one counts is invisible in
    // practice, where inotify on /dev/input would be the only std-only
    // alternative and isn't in std.
    loop {
        if let Ok(entries) = fs::read_dir("/dev/input") {
            for entry in entries.flatten() {
                let name = entry.file_name().to_string_lossy().into_owned();

                if !name.starts_with("event") || !is_gamepad(&name) {
                    continue;
                }

                if !watched.lock().unwrap().insert(name.clone()) {
                    continue;
                }

                let command = Arc::clone(&command);
                let watched = Arc::clone(&watched);
                let last = Arc::clone(&last);

                thread::spawn(move || watch(name, command, watched, last));
            }
        }

        thread::sleep(Duration::from_secs(2));
    }
}
