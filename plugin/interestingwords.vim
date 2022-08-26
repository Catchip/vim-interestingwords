" --------------------------------------------------------------------
" This plugin was inspired and based on Steve Losh's interesting words
" .vimrc config https://www.youtube.com/watch?v=xZuy4gBghho
" --------------------------------------------------------------------

let s:interestingWordsGUIColors = ['#aeee00', '#ff0000', '#0000ff', '#b88823', '#ffa724', '#ff2c4b']
let s:interestingWordsTermColors = ['154', '121', '211', '137', '214', '222']
let s:interestingWordsSave = 1

let g:interestingWordsGUIColors = exists('g:interestingWordsGUIColors') ? g:interestingWordsGUIColors : s:interestingWordsGUIColors
let g:interestingWordsTermColors = exists('g:interestingWordsTermColors') ? g:interestingWordsTermColors : s:interestingWordsTermColors
let g:interestingWordsSave = exists('g:interestingWordsSave') ? g:interestingWordsSave : s:interestingWordsSave
let s:hasBuiltColors = 0


let s:path = $HOME.."/.config/nvim/tmp/interestingWords/"..substitute(expand('%:p'), '/','%','g')


let s:interestingWords = []
let s:interestingModes = []
let s:interestingColors = []
let s:mids = {}
let s:recentlyUsed = []

if !isdirectory($HOME .. "/.config/nvim/tmp/interestingWords")
  call mkdir($HOME ..  "/.config/nvim/tmp/interestingWords")
endif

function! ColorWord(word, mode)
  if !(s:hasBuiltColors)
    call s:buildColors()
  endif

  " gets the lowest unused index
  let n = index(s:interestingWords, 0)
  if (n == -1)
    "if !(exists('g:interestingWordsCycleColors') && g:interestingWordsCycleColors)
      "echom "InterestingWords: max number of highlight groups reached " . len(s:interestingWords)
      "return
    "else
      "let n = s:recentlyUsed[0]
      "call UncolorWord(s:interestingWords[n])
    "endif
    call add(s:interestingWords, 0)
    call add(s:interestingModes, 'n')
    let ui = s:uiMode()
    let Color = GenerateColor(ui)
    call add(s:interestingColors, Color)
    let n = index(s:interestingWords, 0)
    execute 'hi! def InterestingWord' . (n+1) . ' ' . ui . 'bg=' . Color . ' ' . ui . 'fg=Black'
  endif
  let mid = 595129 + n
  let s:interestingWords[n] = a:word
  let s:interestingModes[n] = a:mode
  let s:mids[a:word] = mid

  call s:apply_color_to_word(n, a:word, a:mode, mid)

  call s:markRecentlyUsed(n)

endfunction

function! s:apply_color_to_word(n, word, mode, mid)
  let case = s:checkIgnoreCase(a:word) ? '\c' : '\C'
  if a:mode == 'v'
    let pat = case . '\V\zs' . escape(a:word, '\') . '\ze'
  else
    let pat = case . '\V\<' . escape(a:word, '\') . '\>'
  endif

  try
    call matchadd("InterestingWord" . (a:n + 1), pat, 1, a:mid)
  catch /E801/      " match id already taken.
  endtry
endfunction

function! s:nearest_group_at_cursor() abort
  let l:matches = {}
  for l:match_item in getmatches()
    let l:mids = filter(items(s:mids), 'v:val[1] == l:match_item.id')
    if len(l:mids) == 0
      continue
    endif
    let l:word = l:mids[0][0]
    let l:position = match(getline('.'), l:match_item.pattern)
    if l:position > -1
      if col('.') > l:position && col('.') <= l:position + len(l:word)
        return l:word
      endif
    endif
  endfor
  return ''
endfunction

function! UncolorWord(word)
  let index = index(s:interestingWords, a:word)

  if (index > -1)
    let mid = s:mids[a:word]

    silent! call matchdelete(mid)
    let s:interestingWords[index] = 0
    unlet s:mids[a:word]
  endif
endfunction

function! s:getmatch(mid) abort
  return filter(getmatches(), 'v:val.id==a:mid')[0]
endfunction

function! WordNavigation(direction)
  let currentWord = s:nearest_group_at_cursor()

  if (s:checkIgnoreCase(currentWord))
    let currentWord = tolower(currentWord)
  endif

  if (index(s:interestingWords, currentWord) > -1)
    let l:index = index(s:interestingWords, currentWord)
    let l:mode = s:interestingModes[index]
    let case = s:checkIgnoreCase(currentWord) ? '\c' : '\C'
    if l:mode == 'v'
      let pat = case . '\V\zs' . escape(currentWord, '\') . '\ze'
    else
      let pat = case . '\V\<' . escape(currentWord, '\') . '\>'
    endif
    let searchFlag = ''
    if !(a:direction)
      let searchFlag = 'b'
    endif
    call search(pat, searchFlag)
  else
    try
      if (a:direction)
        normal! n
      else
        normal! N
      endif
    catch /E486/
      echohl WarningMsg | echomsg "E486: Pattern not found: " . @/
    endtry
  endif
endfunction

function! InterestingWords(mode, recolor) range
  if a:mode == 'v'
    let currentWord = s:get_visual_selection()
  else
    let currentWord = expand('<cword>') . ''
  endif
  if !(len(currentWord))
    return
  endif
  if (s:checkIgnoreCase(currentWord))
    let currentWord = tolower(currentWord)
  endif
  if (index(s:interestingWords, currentWord) == -1)
    call ColorWord(currentWord, a:mode)
  else
    if a:recolor == 1
      call ChangecolorWord(currentWord)
    else
      call UncolorWord(currentWord)
    endif
  endif
endfunction

function! ChangecolorWord(word)
  let n = index(s:interestingWords, a:word)
  let ui = s:uiMode()
  if (n == -1)
    return
  endif
  let Color = GenerateColor(ui)
  "let Color = (ui == 'gui') ? g:interestingWordsGUIColors[4] : g:interestingWordsTermColors[4]
  let s:interestingColors[n] = Color

  let n = n + 1
  execute 'hi! InterestingWord' . n . ' ' . ui . 'bg=' . Color . ' ' . ui . 'fg=Black'
endfunction

function! GenerateColor(ui)
  if a:ui == "gui"
    return printf("#%x",rand() % 16777216)
  else
    return string(rand() % 256)
  endif
endfunction

function! s:get_visual_selection()
  " Why is this not a built-in Vim script function?!
  let [lnum1, col1] = getpos("'<")[1:2]
  let [lnum2, col2] = getpos("'>")[1:2]
  let lines = getline(lnum1, lnum2)
  let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
  let lines[0] = lines[0][col1 - 1:]
  return join(lines, "\n")
endfunction

function! UncolorAllWords()
  for word in s:interestingWords
    " check that word is actually a String since '0' is falsy
    if (type(word) == 1)
      call UncolorWord(word)
    endif
  endfor
endfunction

function! RecolorAllWords()
  let i = 0
  for word in s:interestingWords
    if (type(word) == 1)
      let mode = s:interestingModes[i]
      let mid = s:mids[word]
      call s:apply_color_to_word(i, word, mode, mid)
    endif
    let i += 1
  endfor
endfunction

" returns true if the ignorecase flag needs to be used
function! s:checkIgnoreCase(word)
  " return false if case sensitive is used
  if (exists('g:interestingWordsCaseSensitive'))
    return !g:interestingWordsCaseSensitive
  endif
  " checks ignorecase
  " and then if smartcase is on, check if the word contains an uppercase char
  return &ignorecase && (!&smartcase || (match(a:word, '\u') == -1))
endfunction

" moves the index to the back of the s:recentlyUsed list
function! s:markRecentlyUsed(n)
  let index = index(s:recentlyUsed, a:n)
  call remove(s:recentlyUsed, index)
  call add(s:recentlyUsed, a:n)
endfunction

function! s:uiMode()
  " Stolen from airline's airline#init#gui_mode()
  return ((has('nvim') && exists('$NVIM_TUI_ENABLE_TRUE_COLOR') && !exists("+termguicolors"))
     \ || has('gui_running') || (has("termtruecolor") && &guicolors == 1) || (has("termguicolors") && &termguicolors == 1)) ?
      \ 'gui' : 'cterm'
endfunction

" if InterestingWordSave == 1, all colored words recover according to file
" else
" initialise highlight colors from list of GUIColors
" initialise length of s:interestingWord list
" initialise s:recentlyUsed list
function! s:buildColors()
  if (s:hasBuiltColors)
    return
  endif

  let ui = s:uiMode()

  " If Save mode is up, colors initialise from file
  if s:interestingWordsSave && file_readable(s:path.."colors")
    for line in readfile(s:path.."colors")
      call add(s:interestingColors, line)
    endfor
  endif
    
  if len(s:interestingColors) == 0
    let s:interestingColors = (ui == 'gui') ? g:interestingWordsGUIColors : g:interestingWordsTermColors
    if (exists('g:interestingWordsRandomiseColors') && g:interestingWordsRandomiseColors)
      " fisher-yates shuffle
      let i = len(s:interestingColors)-1
      while i > 0
        let j = s:Random(i)
        let temp = s:interestingColors[i]
        let s:interestingColors[i] = s:interestingColors[j]
        let s:interestingColors[j] = temp
        let i -= 1
      endwhile
    endif
  endif

  " select ui type
  " highlight group indexed from 1
  let currentIndex = 1
  for wordColor in s:interestingColors
    execute 'hi! def InterestingWord' . currentIndex . ' ' . ui . 'bg=' . wordColor . ' ' . ui . 'fg=Black'
    call add(s:interestingWords, 0)
    call add(s:interestingModes, 'n')
    call add(s:recentlyUsed, currentIndex-1)
    let currentIndex += 1
  endfor

  if s:interestingWordsSave
    "recover from file
    call s:Read()
    call RecolorAllWords()
    autocmd BufWinLeave * call s:Save()
  endif

  let s:hasBuiltColors = 1
endfunction

" helper function to get random number between 0 and n-1 inclusive
function! s:Random(n)
  let timestamp = reltimestr(reltime())[-2:]
  return float2nr(floor(a:n * timestamp/100))
endfunction


function! s:Save()
  call writefile(s:interestingWords, s:path.."words")
  call writefile(s:interestingModes, s:path.."modes")
  call writefile(s:interestingColors, s:path.."colors")
endfunction

function! s:Read()
  let i = 0
  if file_readable(s:path.."words") && file_readable(s:path.."modes")
    for line in readfile(s:path.."words")
      if line == '0'
        let line = 0
      endif
      let s:interestingWords[i] = line
      let mid = 595129 + i
      let s:mids[line] = mid
      let i = i + 1
    endfor
    let i = 0
    for line in readfile(s:path.."modes")
      let s:interestingModes[i] = line
      let i = i + 1
    endfor
  endif
endfunction


if g:interestingWordsSave
  autocmd BufWinEnter * call s:buildColors()
endif

if !exists('g:interestingWordsDefaultMappings') || g:interestingWordsDefaultMappings != 0
    let g:interestingWordsDefaultMappings = 1
endif

if g:interestingWordsDefaultMappings && !hasmapto('<Plug>InterestingWords')
    nnoremap <silent> <leader>k :call InterestingWords('n', 0)<cr>
    vnoremap <silent> <leader>k :call InterestingWords('v', 0)<cr>
    nnoremap <silent> <leader>j :call InterestingWords('n', 1)<cr>
    vnoremap <silent> <leader>j :call InterestingWords('v', 1)<cr>
    nnoremap <silent> <leader>K :call UncolorAllWords()<cr>

    nnoremap <silent> n :call WordNavigation(1)<cr>
    nnoremap <silent> N :call WordNavigation(0)<cr>
endif

if g:interestingWordsDefaultMappings
   try
      nnoremap <silent> <unique> <script> <Plug>InterestingWords
               \ :call InterestingWords('n', 0)<cr>
      vnoremap <silent> <unique> <script> <Plug>InterestingWords
               \ :call InterestingWords('v', 0)<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsClear
               \ :call UncolorAllWords()<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsForeward
               \ :call WordNavigation(1)<cr>
      nnoremap <silent> <unique> <script> <Plug>InterestingWordsBackward
               \ :call WordNavigation(0)<cr>
   catch /E227/
   endtry
endif
