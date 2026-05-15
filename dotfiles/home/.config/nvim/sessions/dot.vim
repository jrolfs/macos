let SessionLoad = 1
let s:so_save = &g:so | let s:siso_save = &g:siso | setg so=0 siso=0 | setl so=-1 siso=-1
let v:this_session=expand("<sfile>:p")
let EasyMotion_off_screen_search =  1
let DevIconsEnableFoldersOpenClose =  0
let EasyMotion_move_highlight =  1
let VM_mouse_mappings =  0
let EditorConfig_preserve_formatoptions =  0
let JavaComplete_UsePython3 =  1
let EasyMotion_smartcase =  0
let Lf_PopupColorscheme = "gruvbox_material"
let VM_default_mappings =  1
let EasyMotion_enter_jump_first =  0
let VM_Extend_hl = "Visual"
let EditorConfig_exec_path = ""
let EasyMotion_do_mapping =  1
let WebDevIconsUnicodeByteOrderMarkerDefaultSymbol = ""
let WebDevIconsNerdTreeGitPluginForceVAlign =  1
let DevIconsEnableDistro =  1
let EditorConfig_max_line_indicator = "line"
let WebDevIconsUnicodeDecorateFolderNodesDefaultSymbol = ""
let Taboo_tabs = ""
let EasyMotion_use_upper =  0
let WebDevIconsNerdTreeAfterGlyphPadding = " "
let BufKillFunctionSelectingValidBuffersToDisplay = "buflisted"
let WebDevIconsUnicodeDecorateFileNodes =  1
let EasyMotion_force_csapprox =  0
let EasyMotion_space_jump_first =  0
let EasyMotion_prompt = "Search for {n} character(s): "
let BufKillCommandPrefix = "B"
let VM_persistent_registers =  0
let VM_Insert_hl = "Cursor"
let WebDevIconsTabAirLineAfterGlyphPadding = ""
let VM_Mono_hl = "Cursor"
let DevIconsArtifactFixChar = " "
let EasyMotion_show_prompt =  1
let VM_highlight_matches = "underline"
let EasyMotion_add_search_history =  1
let EasyMotion_do_shade =  1
let EasyMotion_grouping =  1
let WebDevIconsUnicodeDecorateFileNodesDefaultSymbol = ""
let EasyMotion_inc_highlight =  1
let WebDevIconsUnicodeDecorateFolderNodes =  1
let NERDTreeGitStatusUpdateOnCursorHold =  1
let EasyMotion_skipfoldedline =  1
let WebDevIconsUnicodeDecorateFolderNodesExactMatches =  1
let JavaComplete_BaseDir = "~/.cache"
let EasyMotion_use_migemo =  0
let DevIconsAppendArtifactFix =  0
let Lf_StlColorscheme = "gruvbox_material"
let WebDevIconsNerdTreeBeforeGlyphPadding = " "
let EasyMotion_verbose =  1
let EditorConfig_verbose =  0
let WebDevIconsUnicodeDecorateFolderNodesSymlinkSymbol = ""
let EasyMotion_disable_two_key_combo =  0
let BufKillActionWhenBufferDisplayedInAnotherWindow = "confirm"
let BufKillCreateMappings =  1
let WebDevIconsUnicodeGlyphDoubleWidth =  1
let EasyMotion_keys = "asdghklqwertyuiopzxcvbnmfj;"
let EasyMotion_cursor_highlight =  1
let BufKillVerbose =  1
let EasyMotion_startofline =  1
let BufKillOverrideCtrlCaret =  0
let NERDTreeUpdateOnCursorHold =  1
let DevIconsDefaultFolderOpenSymbol = ""
let VM_check_mappings =  1
let DevIconsEnableFolderExtensionPatternMatching =  0
let EasyMotion_loaded =  1
let VM_Cursor_hl = "Cursor"
let EasyMotion_use_regexp =  1
let WebDevIconsTabAirLineBeforeGlyphPadding = " "
let DevIconsEnableFolderPatternMatching =  1
let EasyMotion_landing_highlight =  0
silent only

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
cd ~/.homesick/repos/dot
if expand('%') == '' && !&modified && line('$') <= 1 && getline(1) == ''
  let s:wipebuf = bufnr('%')
endif
set shortmess=aoO
argglobal
%argdel
set stal=2
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
set nosplitbelow
set nosplitright
wincmd t
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
wincmd w
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
wincmd w
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
tabnew
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
set nosplitbelow
set nosplitright
wincmd t
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lcd ~/.homesick/repos/macos
wincmd w
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
lcd ~/.homesick/repos/macos
wincmd w
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
tabnew
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
set nosplitbelow
set nosplitright
wincmd t
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lcd ~/.homesick/repos/neovim
wincmd w
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
lcd ~/.homesick/repos/neovim
wincmd w
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
tabnew
set splitbelow splitright
wincmd _ | wincmd |
vsplit
1wincmd h
wincmd w
set nosplitbelow
set nosplitright
wincmd t
set winminheight=0
set winheight=1
set winminwidth=0
set winwidth=1
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
lcd ~/.homesick/repos/private
wincmd w
argglobal
enew
setlocal fdm=manual
setlocal fde=0
setlocal fmr={{{,}}}
setlocal fdi=#
setlocal fdl=0
setlocal fml=1
setlocal fdn=20
setlocal fen
lcd ~/.homesick/repos/private
wincmd w
exe 'vert 1resize ' . ((&columns * 82 + 82) / 164)
exe 'vert 2resize ' . ((&columns * 81 + 82) / 164)
tabnext 1
set stal=1
if exists('s:wipebuf') && getbufvar(s:wipebuf, '&buftype') isnot# 'terminal'
  silent exe 'bwipe ' . s:wipebuf
endif
unlet! s:wipebuf
set winheight=1 winwidth=20 winminheight=0 winminwidth=0 shortmess=filnxtToOF
let s:sx = expand("<sfile>:p:r")."x.vim"
if filereadable(s:sx)
  exe "source " . fnameescape(s:sx)
endif
let &g:so = s:so_save | let &g:siso = s:siso_save
doautoall SessionLoadPost
unlet SessionLoad

" vim: set ft=vim :
