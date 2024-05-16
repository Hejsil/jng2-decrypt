const c = @cImport({
    @cInclude("aes.h");
    @cInclude("zip.h");
});

const std = @import("std");

const ascii = std.ascii;
const base64 = std.base64;
const fmt = std.fmt;
const fs = std.fs;
const heap = std.heap;
const io = std.io;
const log = std.log;
const math = std.math;
const mem = std.mem;
const process = std.process;
const unicode = std.unicode;

const content_folder = "content";

pub fn main() !void {
    var global_arena_state = heap.ArenaAllocator.init(heap.page_allocator);
    defer global_arena_state.deinit();

    const global_arena = global_arena_state.allocator();
    const args = try process.argsAlloc(global_arena);

    var jng_dir = if (args.len >= 2)
        try fs.cwd().openDir(args[1], .{})
    else
        fs.cwd();
    defer jng_dir.close();

    if (jng_dir.access(content_folder, .{})) {
        log.warn(
            \\The 'content' folder already exists.
            \\Type 'yes' and press enter if you want me to override it.
        , .{});

        var buf: [32]u8 = undefined;
        const answer_len = try io.getStdIn().read(&buf);
        const answer = mem.trim(u8, buf[0..answer_len], " \t\r\n");
        if (!ascii.eqlIgnoreCase(answer, "yes")) {
            log.info("I take '{s}' as a no. Exiting...", .{answer});
            return;
        }

        try jng_dir.deleteTree(content_folder);
    } else |err| switch (err) {
        error.FileNotFound => {},
        else => |e| return e,
    }

    try jng_dir.makeDir(content_folder);

    var content_buf: [fs.MAX_PATH_BYTES:0]u8 = undefined;
    const content_path = try jng_dir.realpath(content_folder, &content_buf);
    content_buf[content_path.len] = 0;

    var content_zip_buf: [fs.MAX_PATH_BYTES]u8 = undefined;
    const content_zip_path = try fmt.bufPrintZ(&content_zip_buf, "{s}.zip", .{content_path});

    log.info("Extracting 'content.zip'...", .{});
    const res = c.zip_extract(content_zip_path.ptr, content_path.ptr, null, null);
    if (res < 0) {
        log.err("Failed to extract '{s}'", .{content_zip_path});
        log.info("Make sure you are running me in the Jets'n'Guns 2 folder or passing that " ++
            "folder to me as input.", .{});
        return;
    }

    log.info("Decrypting files...", .{});
    try walkContentFolder(std.heap.page_allocator, jng_dir, content_folder);

    try jng_dir.writeFile(.{ .sub_path = "content.txt", .data = 
    \\dir = content
    \\// zip = content.zip
    \\
    });
}

fn walkContentFolder(allocator: mem.Allocator, parent: fs.Dir, folder: []const u8) anyerror!void {
    var dir = try parent.openDir(folder, .{ .iterate = true });
    var it = dir.iterate();

    while (try it.next()) |entry| switch (entry.kind) {
        .directory => try walkContentFolder(allocator, dir, entry.name),
        .file => {
            const file = try dir.openFile(entry.name, .{ .mode = .read_write });
            defer file.close();

            // Only files starting with the header are encrypted
            const header = "JnGeNc\r\n";
            var header_buf: [header.len]u8 = undefined;
            const len = try file.readAll(&header_buf);
            if (!mem.eql(u8, mem.sliceAsBytes(header), header_buf[0..len]))
                continue;

            var arena_state = heap.ArenaAllocator.init(allocator);
            defer arena_state.deinit();

            const arena = arena_state.allocator();
            const content = try file.readToEndAlloc(arena, math.maxInt(usize));
            const decrypted = try decryptLines(arena, content);

            try file.seekTo(0);
            try file.writeAll(decrypted);
            try file.setEndPos(decrypted.len);
        },
        else => {},
    };
}

fn decryptLines(allocator: mem.Allocator, in: []const u8) ![]u8 {
    var out = try std.ArrayListUnmanaged(u8).initCapacity(allocator, in.len);
    errdefer out.deinit(allocator);

    var decode_buf = std.ArrayListAligned(u8, 2).init(allocator);
    defer decode_buf.deinit();

    var it = mem.tokenize(u8, in, "\r\n");
    while (it.next()) |line| {
        const len = try base64.standard.Decoder.calcSizeForSlice(line);
        try decode_buf.resize(len);

        try base64.standard.Decoder.decode(decode_buf.items, line);
        const decrypted = decryptInPlace(decode_buf.items);

        const l = try unicode.utf16leToUtf8(
            decrypted,
            mem.bytesAsSlice(u16, decode_buf.items[0..decrypted.len]),
        );

        out.appendSliceAssumeCapacity(decrypted[0..l]);
        out.appendAssumeCapacity('\n');
    }

    return out.toOwnedSlice(allocator);
}

const key = [_]u8{
    0x7A, 0xE8, 0x79, 0xD4,
    0x62, 0x33, 0x7D, 0xDE,
    0xB9, 0x6E, 0xF4, 0x4A,
    0x31, 0x38, 0x52, 0xBD,
    0xF7, 0x85, 0xDB, 0x71,
    0x9A, 0xD5, 0x48, 0x90,
    0xE8, 0xDD, 0x93, 0x7C,
    0xD5, 0x22, 0xDA, 0xB9,
};

const iv = [_]u8{
    0x01, 0x14, 0x4C, 0xB9,
    0xEC, 0x91, 0xE1, 0xDF,
    0x48, 0xD1, 0xD1, 0xDF,
    0x9B, 0xFE, 0x18, 0xD3,
};

fn decryptInPlace(bytes: []u8) []u8 {
    if (bytes.len == 0)
        return bytes;

    var aes: c.AES_ctx = undefined;
    c.AES_init_ctx_iv(&aes, &key, &iv);
    c.AES_CBC_decrypt_buffer(&aes, bytes.ptr, bytes.len);

    // Remove PKCS7 padding
    var i: usize = 1;
    const count = bytes[bytes.len - 1];
    while (i != count) : (i += 1) {
        if (i == bytes.len)
            return bytes;
        if (bytes[bytes.len - (i + 1)] != count)
            return bytes;
    }

    return bytes[0 .. bytes.len - i];
}
