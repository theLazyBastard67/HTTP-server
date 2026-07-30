pub const Color = struct {
    // Reset
    pub const reset: []const u8 = "\x1b[0m";

    // Text attributes
    pub const bold: []const u8 = "\x1b[1m";
    pub const dim: []const u8 = "\x1b[2m";
    pub const italic: []const u8 = "\x1b[3m";
    pub const underline: []const u8 = "\x1b[4m";
    pub const blink: []const u8 = "\x1b[5m";
    pub const reverse: []const u8 = "\x1b[7m";
    pub const hidden: []const u8 = "\x1b[8m";
    pub const strikethrough: []const u8 = "\x1b[9m";

    // Normal foreground colors
    pub const black: []const u8 = "\x1b[30m";
    pub const red: []const u8 = "\x1b[31m";
    pub const green: []const u8 = "\x1b[32m";
    pub const yellow: []const u8 = "\x1b[33m";
    pub const blue: []const u8 = "\x1b[34m";
    pub const magenta: []const u8 = "\x1b[35m";
    pub const cyan: []const u8 = "\x1b[36m";
    pub const white: []const u8 = "\x1b[37m";

    // Bright foreground colors
    pub const bright_black: []const u8 = "\x1b[90m";
    pub const bright_red: []const u8 = "\x1b[91m";
    pub const bright_green: []const u8 = "\x1b[92m";
    pub const bright_yellow: []const u8 = "\x1b[93m";
    pub const bright_blue: []const u8 = "\x1b[94m";
    pub const bright_magenta: []const u8 = "\x1b[95m";
    pub const bright_cyan: []const u8 = "\x1b[96m";
    pub const bright_white: []const u8 = "\x1b[97m";

    // Background colors
    pub const bg_black: []const u8 = "\x1b[40m";
    pub const bg_red: []const u8 = "\x1b[41m";
    pub const bg_green: []const u8 = "\x1b[42m";
    pub const bg_yellow: []const u8 = "\x1b[43m";
    pub const bg_blue: []const u8 = "\x1b[44m";
    pub const bg_magenta: []const u8 = "\x1b[45m";
    pub const bg_cyan: []const u8 = "\x1b[46m";
    pub const bg_white: []const u8 = "\x1b[47m";

    // Bright background colors
    pub const bg_bright_black: []const u8 = "\x1b[100m";
    pub const bg_bright_red: []const u8 = "\x1b[101m";
    pub const bg_bright_green: []const u8 = "\x1b[102m";
    pub const bg_bright_yellow: []const u8 = "\x1b[103m";
    pub const bg_bright_blue: []const u8 = "\x1b[104m";
    pub const bg_bright_magenta: []const u8 = "\x1b[105m";
    pub const bg_bright_cyan: []const u8 = "\x1b[106m";
    pub const bg_bright_white: []const u8 = "\x1b[107m";

    // Bold colored text
    pub const bold_black: []const u8 = "\x1b[1;30m";
    pub const bold_red: []const u8 = "\x1b[1;31m";
    pub const bold_green: []const u8 = "\x1b[1;32m";
    pub const bold_yellow: []const u8 = "\x1b[1;33m";
    pub const bold_blue: []const u8 = "\x1b[1;34m";
    pub const bold_magenta: []const u8 = "\x1b[1;35m";
    pub const bold_cyan: []const u8 = "\x1b[1;36m";
    pub const bold_white: []const u8 = "\x1b[1;37m";

    // Bold bright colors
    pub const bold_bright_black: []const u8 = "\x1b[1;90m";
    pub const bold_bright_red: []const u8 = "\x1b[1;91m";
    pub const bold_bright_green: []const u8 = "\x1b[1;92m";
    pub const bold_bright_yellow: []const u8 = "\x1b[1;93m";
    pub const bold_bright_blue: []const u8 = "\x1b[1;94m";
    pub const bold_bright_magenta: []const u8 = "\x1b[1;95m";
    pub const bold_bright_cyan: []const u8 = "\x1b[1;96m";
    pub const bold_bright_white: []const u8 = "\x1b[1;97m";
};
