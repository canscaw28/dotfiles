" My Vim Config Settings
" Maintainer: Craig Weiss
" Last Change: 2017 Jan 25

" Turn off vi compatibility
set nocompatible

" Recognize filetype plugins and indentation
set autoindent
filetype plugin indent on

" Enable Backspacing
set backspace=indent,eol,start

" ----------------------------------------------------
" ::::::::: Swaps, Backupfiles and Undofiles :::::::::
" ----------------------------------------------------

" Disable Backupfiles
set nobackup
set nowritebackup

" Turn swaps on and save them to ~/.vim/swap
if isdirectory($HOME . '/.vim/swap') == 0
  call mkdir($HOME.'/.vim/swap', 'p')
endif
set directory=~/.vim/swap//
set swapfile

" Turn backups on and save them to ~/.vim/backup
" if isdirectory($HOME . '/.vim/backup') == 0
"  call mkdir($HOME.'/.vim/backup', 'p')
" endif
" set backupdir=~/.vim/backup//
" set backup

" Turn undofiles on and save them to ~/.vim/undo
" if isdirectory($HOME . '/.vim/undo') == 0
"   call mkdir($HOME.'/.vim/undo', 'p')
" endif
" set directory=~/.vim/undo//
" set undofile



" Colorscheme
set background=dark


" Syntax Highlighting
if !exists("g:syntax_on") 
  syntax enable
endif

set tabstop=2
set softtabstop=2
set expandtab
set showcmd
set cursorline
set shiftwidth=2
set wildmenu
set number
set showmatch
set incsearch
set hlsearch
nnoremap <leader><space> :nohlsearch<CR>
set mouse=a

if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif
