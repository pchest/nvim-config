"{ UI-related settings
"{{ General settings about colors
" Enable true colors support. Do not set this option if your terminal does not
" support true colors! For a comprehensive list of terminals supporting true
" colors, see https://github.com/termstandard/colors and
" https://gist.github.com/XVilka/8346728.
if match($TERM, '^xterm.*') != -1 || exists('g:started_by_firenvim')
  set termguicolors
endif
" Use dark background
set background=dark
"}}

"{{ Colorscheme settings
let s:candidate_theme = ['gruvbox8', 'srcery', 'badwolf', 'deus', 'happy_hacking', 'solarized8',
      \ 'monokai', 'gotham', 'vim_one', 'material', 'onedark']
let s:idx = utils#RandInt(0, len(s:candidate_theme)-1)
let s:theme = s:candidate_theme[s:idx]

let s:my_theme_dict = {}

function! s:my_theme_dict.srcery() dict abort
  colorscheme srcery
endfunction

function! s:my_theme_dict.gruvbox8() dict abort
  " We should check if theme exists before using it, otherwise you will get
  " error message when starting Nvim
  if utils#HasColorscheme('gruvbox8')
    " Italic options should be put before colorscheme setting,
    " see https://github.com/morhetz/gruvbox/wiki/Terminal-specific#1-italics-is-disabled
    let g:gruvbox_italics=1
    let g:gruvbox_italicize_strings=1
    let g:gruvbox_filetype_hi_groups = 0
    let g:gruvbox_plugin_hi_groups = 0
    colorscheme gruvbox8_hard
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.srcery() dict abort
  if utils#HasColorscheme('srcery')
    colorscheme srcery
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.badwolf() dict abort
  if utils#HasColorscheme('badwolf')
    let g:badwolf_darkgutter = 0
    " Make the tab line lighter than the background.
    let g:badwolf_tabline = 2
    colorscheme badwolf
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.deus() dict abort
  if utils#HasColorscheme('deus')
    colorscheme deus
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.happy_hacking() dict abort
  if utils#HasColorscheme('happy_hacking')
    colorscheme happy_hacking
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.solarized8() dict abort
  if utils#HasColorscheme('solarized8')
    let g:solarized_term_italics=1
    let g:solarized_visibility='high'
    colorscheme solarized8_flat
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.monokai() dict abort
  if utils#HasColorscheme('monokai')
    colorscheme monokai
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.gotham() dict abort
  if utils#HasColorscheme('gotham')
    colorscheme gotham
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.vim_one() dict abort
  if utils#HasColorscheme('one')
    let g:one_allow_italics = 1
    colorscheme one
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.material() dict abort
  if utils#HasColorscheme('material')
    let g:material_terminal_italics = 1
    " theme_style can be 'default', 'dark' or 'palenight'
    let g:material_theme_style = 'default'
    colorscheme material
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.onedark() dict abort
  if utils#HasColorscheme('onedark')
    let g:onedark_terminal_italics = 1
    colorscheme onedark
  else
    colorscheme desert
  endif
endfunction

function! s:my_theme_dict.neodark() dict abort
  if utils#HasColorscheme('neodark')
    colorscheme neodark
  else
    colorscheme desert
  endif
endfunction

execute printf('call s:my_theme_dict.%s()', s:theme)
"}}
"}
