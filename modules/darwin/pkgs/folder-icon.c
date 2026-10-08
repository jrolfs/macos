/* folder-icon: set, clear and report the macOS 26 folder icon customisation.
 *
 * This is the mechanism behind Finder's "Customize Folder…" popover, which is
 * *not* the classic Icon\r resource fork that icon-setter.c writes.  Two
 * things have to be true for the system to composite a glyph onto its own
 * folder artwork:
 *
 *   1. an extended attribute `com.apple.icon.folder#S` holding JSON —
 *      {"sym":"<SF Symbol name>"} or {"emoji":"<characters>"}
 *   2. kHasCustomIcon (0x0400) set in the folder's com.apple.FinderInfo
 *
 * Neither alone is enough: the xattr without the flag renders a plain folder,
 * and the flag without either an xattr or an Icon\r renders a generic one.
 * The `#S` suffix is Apple's xattr naming convention for "syncable" and is a
 * literal part of the name, and getxattr/setxattr want it spelled out.
 *
 * The format was recovered by interposing getxattr(2) around
 * -[ISFolderIconConfiguration initWithURL:], which reads the private NSURL
 * resource keys _NSURLIconSymbolNameKey, _NSURLIconEmojiKey and
 * _NSURLTagColorIndexKey.  Writing the xattr directly gets the same result
 * without linking the private IconServices framework.  The tint half of the
 * popover is deliberately not implemented here: it is stored as an ordinary
 * Finder tag, so it belongs to whatever manages tags, not to this tool.
 *
 * The flag is read-modify-written rather than assigned, because FinderInfo is
 * a shared 32-byte struct. Resilio Sync leaves the invisible bit on its own
 * Icon\r, and clobbering the whole blob would drop fields this tool has no
 * business touching.
 */

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/xattr.h>
#include <unistd.h>

#define XATTR_NAME "com.apple.icon.folder#S"
#define HAS_CUSTOM_ICON 0x04 /* high byte of kHasCustomIcon (0x0400) */
#define FINDER_INFO_SIZE 32

/* Read-modify-write the kHasCustomIcon bit.  A folder with no FinderInfo at
 * all is the common case, so a missing xattr starts from zeroes rather than
 * being an error. */
static int set_custom_icon_flag(const char *path, int on) {
    unsigned char info[FINDER_INFO_SIZE] = { 0 };
    ssize_t size = getxattr(path, "com.apple.FinderInfo", info, sizeof info, 0, 0);

    if (size > 0 && size != FINDER_INFO_SIZE) {
        fprintf(stderr, "unexpected FinderInfo size (%zd) on %s\n", size, path);
        return -1;
    }

    if (on)
        info[8] |= HAS_CUSTOM_ICON;
    else
        info[8] &= (unsigned char)~HAS_CUSTOM_ICON;

    /* An all-zero FinderInfo is indistinguishable from none, and leaving a
     * zeroed blob behind makes `xattr -l` noisier than the folder deserves. */
    int empty = 1;
    for (int i = 0; i < FINDER_INFO_SIZE; i++)
        if (info[i]) { empty = 0; break; }

    if (empty) {
        if (removexattr(path, "com.apple.FinderInfo", 0) != 0 && errno != ENOATTR) {
            fprintf(stderr, "cannot clear FinderInfo on %s: %s\n", path, strerror(errno));
            return -1;
        }
        return 0;
    }

    if (setxattr(path, "com.apple.FinderInfo", info, sizeof info, 0, 0) != 0) {
        fprintf(stderr, "cannot set FinderInfo on %s: %s\n", path, strerror(errno));
        return -1;
    }
    return 0;
}

/* Resilio Sync drops a 1.2 MB Icon\r into every share it creates.  The xattr
 * takes precedence over it, but it is dead weight and the user asked for it
 * gone, so taking over a folder removes it.  Note this file lives *inside* the
 * share, so on a synced folder the deletion propagates to every peer. */
static void remove_legacy_icon(const char *path) {
    char *icon = malloc(strlen(path) + sizeof "/Icon\r");
    if (!icon) return;
    sprintf(icon, "%s/Icon\r", path);
    if (unlink(icon) != 0 && errno != ENOENT)
        fprintf(stderr, "cannot remove Icon\\r in %s: %s\n", path, strerror(errno));
    free(icon);
}

static void report(const char *path) {
    char value[1024];
    ssize_t size = getxattr(path, XATTR_NAME, value, sizeof value - 1, 0, 0);

    unsigned char info[FINDER_INFO_SIZE] = { 0 };
    int flagged = getxattr(path, "com.apple.FinderInfo", info, sizeof info, 0, 0) == FINDER_INFO_SIZE
                  && (info[8] & HAS_CUSTOM_ICON);

    char *legacy = malloc(strlen(path) + sizeof "/Icon\r");
    struct stat status;
    int has_legacy = 0;
    if (legacy) {
        sprintf(legacy, "%s/Icon\r", path);
        has_legacy = stat(legacy, &status) == 0;
        free(legacy);
    }

    if (size > 0) {
        value[size] = '\0';
        printf("%s flag=%d legacy=%d\n", value, flagged, has_legacy);
    } else {
        printf("none flag=%d legacy=%d\n", flagged, has_legacy);
    }
}

/* SF Symbol names are [a-z0-9.] and emoji are plain UTF-8, so neither needs
 * JSON escaping.  Rather than carry an escaper for input that should never
 * contain these, refuse the two characters that would break the document. */
static int json_safe(const char *value) {
    return !strchr(value, '"') && !strchr(value, '\\');
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr,
                "usage: folder-icon show PATH\n"
                "       folder-icon clear PATH\n"
                "       folder-icon set PATH symbol NAME\n"
                "       folder-icon set PATH emoji CHARACTERS\n");
        return 2;
    }

    const char *command = argv[1];
    const char *path = argv[2];

    struct stat status;
    if (stat(path, &status) != 0 || !S_ISDIR(status.st_mode)) {
        fprintf(stderr, "not a directory: %s\n", path);
        return 1;
    }

    if (strcmp(command, "show") == 0) {
        report(path);
        return 0;
    }

    if (strcmp(command, "clear") == 0) {
        if (removexattr(path, XATTR_NAME, 0) != 0 && errno != ENOATTR) {
            fprintf(stderr, "cannot remove %s on %s: %s\n", XATTR_NAME, path, strerror(errno));
            return 1;
        }
        remove_legacy_icon(path);
        if (set_custom_icon_flag(path, 0) != 0) return 1;
        utimes(path, NULL);
        return 0;
    }

    if (strcmp(command, "set") == 0) {
        if (argc < 5) {
            fprintf(stderr, "set needs a kind (symbol|emoji) and a value\n");
            return 2;
        }
        const char *kind = argv[3];
        const char *value = argv[4];

        const char *key;
        if (strcmp(kind, "symbol") == 0)
            key = "sym";
        else if (strcmp(kind, "emoji") == 0)
            key = "emoji";
        else {
            fprintf(stderr, "unknown kind: %s (want symbol or emoji)\n", kind);
            return 2;
        }

        if (!json_safe(value)) {
            fprintf(stderr, "value may not contain a quote or backslash: %s\n", value);
            return 2;
        }

        char json[1024];
        int length = snprintf(json, sizeof json, "{\"%s\":\"%s\"}", key, value);
        if (length < 0 || (size_t)length >= sizeof json) {
            fprintf(stderr, "value too long: %s\n", value);
            return 2;
        }

        /* The xattr goes on before the flag.  A folder advertising a custom
         * icon it cannot load renders as a generic folder, so the window where
         * that is true should not exist. */
        if (setxattr(path, XATTR_NAME, json, (size_t)length, 0, 0) != 0) {
            fprintf(stderr, "cannot set %s on %s: %s\n", XATTR_NAME, path, strerror(errno));
            return 1;
        }
        remove_legacy_icon(path);
        if (set_custom_icon_flag(path, 1) != 0) return 1;
        utimes(path, NULL);
        return 0;
    }

    fprintf(stderr, "unknown command: %s\n", command);
    return 2;
}
