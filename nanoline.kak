# A Kakoune modeline inspired by Nano Emacs.
# Author: François Tonneau
# License: MIT

# ------------------------------------------------------------
# Public options
# ------------------------------------------------------------

declare-option -docstring 'face for read/write mode (dark)' \
str nanoline_rw_face_dark black,bright-black

declare-option -docstring 'face for read/write mode (light)' \
str nanoline_rw_face_light black,bright-black

declare-option -docstring 'string to signal macro recording' \
str nanoline_macro_on ' ● REC'

declare-option -docstring 'string once macro recording ends' \
str nanoline_macro_off '      '

# ------------------------------------------------------------
# Public commands
# ------------------------------------------------------------

define-command -docstring 'nanoline <light|dark>: choose head version' \
-params 1 nanoline %{
    try %{
        nanoline-is-dark %arg(1)
        set-option global nanoline_rw_face %opt(nanoline_rw_face_dark)
    } \
    catch %{
        set-option global nanoline_rw_face %opt(nanoline_rw_face_light)
    }
    try nanoline-refresh
}
complete-command -menu nanoline shell-script-candidates %{ printf 'dark\nlight\n' }

define-command -docstring "nanoline-format: use nanoline's modeline format" \
nanoline-format %{
    set-option global modelinefmt \
    '{{mode_info}}  %val(buf_line_count) | %val(cursor_line):%val(cursor_char_column)'
    set-face global StatusCursor        default,default+bu
    set-face global StatusLineInfo      default,+b
    set-face global StatusLineMode      default,+b
    set-face global StatusLineValue     default,+b
}

# ------------------------------------------------------------
# Nanoline implementation
# ------------------------------------------------------------
# Nanoline works by echoing a custom head over the left of Kakoune's default
# modeline. The head must often be refreshed, however, because normal-mode key
# presses and mode changes tend to clear the echo area. The head must also be
# updated on changes of selection count, changes of buffer content caused by
# external copy/paste, and changes of file properties.

declare-option -hidden int nanoline_count -1
declare-option -hidden int nanoline_stamp -1
declare-option -hidden str nanoline_rw_face default

declare-option -hidden str nanoline_macro_cue %opt(nanoline_macro_off)
declare-option -hidden str nanoline_head ''

hook -group nanoline global WinDisplay .* nanoline-refresh

# Refresh head on regular and special normal keys, except on the macro key (Q)
# and on keys that require a visible prompt. On Q, refresh head after updating
# the macro-recording cue to be displayed.
hook -group nanoline global NormalKey [^Q/?|!sS\$]      nanoline-refresh
hook -group nanoline global NormalKey <.*[^/?|!kK]>     nanoline-refresh
hook -group nanoline global NormalKey Q %{
    try %{
        nanoline-window-equals %opt(nanoline_macro_cue) %opt(nanoline_macro_off)
        set-option window nanoline_macro_cue %opt(nanoline_macro_on)
    } \
    catch %{
        set-option window nanoline_macro_cue %opt(nanoline_macro_off)
    }
    nanoline-refresh
}

hook -group nanoline global ModeChange .*next-key.*     nanoline-refresh
hook -group nanoline global ModeChange pop:prompt.*     nanoline-refresh

hook -group nanoline global NormalIdle .* %{
    try %{
        nanoline-window-equals %val(selection_count) %opt(nanoline_count)
    } \
    catch %{
        set-option window nanoline_count %val(selection_count)
        nanoline-refresh
    }
    try %{
        nanoline-window-equals %val(timestamp) %opt(nanoline_stamp)
    } \
    catch %{
        set-option window nanoline_stamp %val(timestamp)
        nanoline-refresh
    }
}

hook -group nanoline global WinSetOption filetype=.* %{
    hook -group nanoline -once window NormalIdle .* nanoline-refresh
}

hook -group nanoline global BufSetOption readonly=.* %{
    hook -group nanoline -once buffer NormalIdle .* nanoline-refresh
}

# ------------------------------------------------------------
# Nanoline head refresh
# ------------------------------------------------------------

define-command -hidden nanoline-refresh %{
    try %{
        nanoline-window-equals %opt(readonly) true
        set-option window nanoline_head "{%opt(nanoline_rw_face)} RO "
    } \
    catch %{
        set-option window nanoline_head "{%opt(nanoline_rw_face)} RW "
    }
    try %{ nanoline-window-equals %val(selection_count) 1 } \
    catch %{ set-option -add window nanoline_head "%val(selection_count) " }
    set-option -add window nanoline_head '{default}'

    set-option -add window nanoline_head "{default,+b}   %val(bufname) {default}"
    try %{ nanoline-window-equals %opt(filetype) '' } \
    catch %{ set-option -add window nanoline_head "(%opt(filetype))" }

    set-option -add window nanoline_head %opt(nanoline_macro_cue)

    echo -markup %opt(nanoline_head)
}

# ------------------------------------------------------------
# Comparison: argument == dark?
# ------------------------------------------------------------

define-command -hidden nanoline-is-dark-dark nop

define-command -hidden -params 1 nanoline-is-dark %{
    "nanoline-is-dark-%arg(1)"
}

# ------------------------------------------------------------
# String comparison
# From https://gitlab.com/kstr0k/sel-editor.kak/-/snippets/2178452
# ------------------------------------------------------------

define-command -hidden -params 0 nanoline-check-strings nop
declare-option -hidden str-list nanoline_str_list

define-command -hidden -params 2 nanoline-window-equals %{
  set-option         window nanoline_str_list %arg{1}
  set-option -remove window nanoline_str_list %arg{2}
  nanoline-check-strings %opt(nanoline_str_list)
}

