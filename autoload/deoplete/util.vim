"=============================================================================
" FILE: util.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu at gmail.com>
" License: MIT license
"=============================================================================

function! deoplete#util#set_default(var, val, ...)  abort "{{{
  if !exists(a:var) || type({a:var}) != type(a:val)
    let alternate_var = get(a:000, 0, '')

    let {a:var} = exists(alternate_var) ?
          \ {alternate_var} : a:val
  endif
endfunction"}}}
function! deoplete#util#set_pattern(variable, keys, pattern) abort "{{{
  for key in split(a:keys, '\s*,\s*')
    if !has_key(a:variable, key)
      let a:variable[key] = a:pattern
    endif
  endfor
endfunction"}}}
function! deoplete#util#get_buffer_config(
      \ filetype, buffer_var, user_var, default_var, ...) abort "{{{
  let default_val = get(a:000, 0, '')

  if exists(a:buffer_var)
    return {a:buffer_var}
  endif

  let filetype = !has_key({a:user_var}, a:filetype)
        \ && !has_key(eval(a:default_var), a:filetype) ? '_' : a:filetype

  return get({a:user_var}, filetype,
        \   get(eval(a:default_var), filetype, default_val))
endfunction"}}}
function! deoplete#util#get_simple_buffer_config(buffer_var, user_var) abort "{{{
  return exists(a:buffer_var) ? {a:buffer_var} : {a:user_var}
endfunction"}}}
function! deoplete#util#print_error(string) abort "{{{
  echohl Error | echomsg '[deoplete] ' . a:string | echohl None
endfunction"}}}
function! deoplete#util#print_warning(string) abort "{{{
  echohl WarningMsg | echomsg '[deoplete] ' . a:string | echohl None
endfunction"}}}

function! deoplete#util#convert2list(expr) abort "{{{
  return type(a:expr) ==# type([]) ? a:expr : [a:expr]
endfunction"}}}

function! deoplete#util#get_input(event) abort "{{{
  let mode = mode()
  if a:event ==# 'InsertEnter'
    let mode = 'i'
  endif
  let input = (mode ==# 'i' ? (col('.')-1) : col('.')) >= len(getline('.')) ?
        \      getline('.') :
        \      matchstr(getline('.'),
        \         '^.*\%' . (mode ==# 'i' ? col('.') : col('.') - 1)
        \         . 'c' . (mode ==# 'i' ? '' : '.'))

  if input =~ '^.\{-}\ze\S\+$'
    let complete_str = matchstr(input, '\S\+$')
    let input = matchstr(input, '^.\{-}\ze\S\+$')
  else
    let complete_str = ''
  endif

  if a:event ==# 'InsertCharPre'
    let complete_str .= v:char
  endif

  return input . complete_str
endfunction"}}}
function! deoplete#util#get_next_input(event) abort "{{{
  return getline('.')[len(deoplete#util#get_input(a:event)) :]
endfunction"}}}
function! deoplete#util#get_prev_event() abort "{{{
  return get(g:deoplete#_context, 'event', '')
endfunction"}}}

function! deoplete#util#vimoption2python(option) abort "{{{
  return '[a-zA-Z' . s:vimoption2python(a:option) . ']'
endfunction"}}}
function! deoplete#util#vimoption2python_not(option) abort "{{{
  return '[^a-zA-Z' . s:vimoption2python(a:option) . ']'
endfunction"}}}
function! s:vimoption2python(option) abort "{{{
  let has_dash = 0
  let patterns = []
  for pattern in split(a:option, ',')
    if pattern == ''
      " ,
      call add(patterns, ',')
    elseif pattern == '-'
      let has_dash = 1
    elseif pattern =~ '\d\+'
      call add(patterns, substitute(pattern, '\d\+',
            \ '\=nr2char(submatch(0))', 'g'))
    else
      call add(patterns, pattern)
    endif
  endfor

  " Dash must be last.
  if has_dash
    call add(patterns, '-')
  endif

  return join(deoplete#util#uniq(patterns), '')
endfunction"}}}

function! deoplete#util#uniq(list) abort "{{{
  let list = map(copy(a:list), '[v:val, v:val]')
  let i = 0
  let seen = {}
  while i < len(list)
    let key = string(list[i][1])
    if has_key(seen, key)
      call remove(list, i)
    else
      let seen[key] = 1
      let i += 1
    endif
  endwhile
  return map(list, 'v:val[0]')
endfunction"}}}

function! deoplete#util#redir(cmd) abort "{{{
  if exists('*execute')
    return execute(a:cmd)
  else
    let [save_verbose, save_verbosefile] = [&verbose, &verbosefile]
    set verbose=0 verbosefile=
    redir => res
    silent! execute a:cmd
    redir END
    let [&verbose, &verbosefile] = [save_verbose, save_verbosefile]
    return res
  endif
endfunction"}}}

function! deoplete#util#get_syn_names() abort "{{{
  if col('$') >= 200
    return []
  endif

  let names = []
  try
    " Note: synstack() seems broken in concealed text.
    for id in synstack(line('.'), (mode() ==# 'i' ? col('.')-1 : col('.')))
      let name = synIDattr(id, 'name')
      call add(names, name)
      if synIDattr(synIDtrans(id), 'name') !=# name
        call add(names, synIDattr(synIDtrans(id), 'name'))
      endif
    endfor
  catch
    " Ignore error
  endtry
  return names
endfunction"}}}

function! deoplete#util#neovim_version() abort "{{{
  redir => v
  silent version
  redir END
  return split(v, '\n')[0]
endfunction"}}}

" Compare versions.  Return values is the distance between versions.  Each
" version integer (from right to left) is an ascending power of 100.
"
" Example:
" '0.1.10' is (1 * 100) + 10, or 110.
" '1.2.3' is (1 * 10000) + (2 * 100) + 3, or 10203.
"
" Returns:
" <0 if a < b
" >0 if a > b
" 0 if versions are equal.
function! deoplete#util#versioncmp(a, b) abort "{{{
  let a = map(split(a:a, '\.'), 'str2nr(v:val)')
  let b = map(split(a:b, '\.'), 'str2nr(v:val)')
  let l = min([len(a), len(b)])
  let d = 0

  " Only compare the parts that are common to both versions.
  for i in range(l)
    let d += (a[i] - b[i]) * pow(100, l - i - 1)
  endfor

  return d
endfunction"}}}

" vim: foldmethod=marker
