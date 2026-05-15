let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let EasyMotion_use_upper =  0
let EasyMotion_off_screen_search =  1
let EasyMotion_use_regexp =  1
let EasyMotion_move_highlight =  1
let EditorConfig_preserve_formatoptions =  0
let JavaComplete_UsePython3 =  1
let EasyMotion_smartcase =  0
let Lf_PopupColorscheme = "gruvbox_material"
let EasyMotion_enter_jump_first =  0
let VM_Extend_hl = "Visual"
let EditorConfig_exec_path = ""
let EasyMotion_do_mapping =  1
let EasyMotion_keys = "asdghklqwertyuiopzxcvbnmfj;"
let EditorConfig_max_line_indicator = "line"
let EditorConfig_enable_for_new_buf =  0
let BufKillFunctionSelectingValidBuffersToDisplay = "buflisted"
let EasyMotion_disable_two_key_combo =  0
let EasyMotion_space_jump_first =  0
let EasyMotion_prompt = "Search for {n} character(s): "
let EasyMotion_loaded =  1
let BufKillCommandPrefix = "B"
let EditorConfig_softtabstop_tab =  1
let VM_Insert_hl = "VMCursor"
let VM_Mono_hl = "VMCursor"
let EasyMotion_show_prompt =  1
let EasyMotion_add_search_history =  1
let EasyMotion_do_shade =  1
let EasyMotion_grouping =  1
let EasyMotion_inc_highlight =  1
let EasyMotion_skipfoldedline =  1
let JavaComplete_BaseDir = "~/.cache"
let EasyMotion_use_migemo =  0
let Lf_StlColorscheme = "gruvbox_material"
let BufKillActionWhenBufferDisplayedInAnotherWindow = "confirm"
let EasyMotion_verbose =  1
let EditorConfig_verbose =  0
let BufKillOverrideCtrlCaret =  0
let BufKillCreateMappings =  1
let EasyMotion_cursor_highlight =  1
let BufKillVerbose =  1
let EasyMotion_startofline =  1
let EasyMotion_force_csapprox =  0
let EditorConfig_softtabstop_space =  1
let VM_Cursor_hl = "VMCursor"
let EasyMotion_landing_highlight =  0

silent only
silent tabonly

cd ~/.homesick/repos/macos

if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif

let s:shortmess_save = &shortmess

if &shortmess =~ 'A'
  set shortmess=aoOA
else
  set shortmess=aoO
endif

argglobal
%argdel
argglobal
enew

setlocal foldmethod=manual
setlocal foldexpr=0
setlocal foldmarker={{{,}}}
setlocal foldignore=#
setlocal foldlevel=0
setlocal foldminlines=1
setlocal foldnestmax=20
setlocal foldenable

lcd ~/.homesick/repos/macos

tabnext 1

if exists('s:wipebuf') && len(win_findbuf(s:wipebuf)) == 0 && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf

set winheight=1 winwidth=20

let &shortmess = s:shortmess_save
let s:sx = expand("<sfile>:p:r")."x.vim"

if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif

let &g:so = s:so_save | let &g:siso = s:siso_save

set hlsearch

nohlsearch
doautoall SessionLoadPost
unlet SessionLoad

Telescope git_files

" vim: set ft=vim :
