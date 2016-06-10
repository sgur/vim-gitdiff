scriptencoding utf-8



" Internal {{{1

function! s:diffexpr(algorithm)
  if get(g:, 'gitdiff_skip_check', 0)
        \ && getfsize(v:fname_in) <= 6 && getfsize(v:fname_new) <= 6
    call writefile(['1c1'], v:fname_out)
    return
  endif
  let icase = &diffopt =~# 'icase'
  if icase
    echomsg 'git_diff: No effect on diffopt+=icase'
  endif
  let iwhite = &diffopt =~# 'iwhite'
  try
    let udiff = s:git_diff(a:algorithm, v:fname_in, v:fname_new, icase, iwhite)
    call writefile(s:unified_to_ed(udiff), v:fname_out)
  catch /^git_diff/
    echoerr v:exception
  endtry
endfunction

function! s:git_diff(algorithm, fname1, fname2, icase, iwhite)
  let cmd = [get(g:, 'git_diff_progname', 'git'), 'diff']
  let iwhite = a:iwhite ? ['--ignore-space-change'] : []
  let argorigm = ['--diff-algorithm=' . a:algorithm]
  let common = ['--unified=0', '--no-index', '--no-color', '--no-ext-diff', '--']
  let fnames = map(copy([a:fname1, a:fname2]), '"\"" . tr(v:val, "\\", "/") . "\""')
  let ret = s:systemlist(join(cmd + iwhite + argorigm + common + fnames))
  return ret[2:]
endfunction

function! s:systemlist(cmd)
  try
    return get(g:, 'loaded_vimproc', 0) && (has('win32') || has('win64'))
          \ ? split(vimproc#system(a:cmd), "\n")
          \ : exists('*systemlist') ? systemlist(a:cmd) : split(system(a:cmd), "\n")
  catch /.*/
    throw 'git_diff: ' . v:exception
  endtry
endfunction

function! s:unified_to_ed(lines)
  let _ = []
  for line in a:lines
    if line =~# '^\%(+++\|---\)'
      continue
    elseif line =~# '^@@ -\%(\d\+\)\%(,\d\+\)\? +\%(\d\+\)\%(,\d\+\)\? @@'
      let _ += [s:parse_header(line)]
    elseif line[0] is# '-'
      let _ += ['< ' . line[1:]]
    elseif line[0] is# '+'
      if _[-1][0:1] is# '< '
        let _ += ['---']
      endif
      let _ += ['> ' . line[1:]]
    endif
  endfor
  return _
endfunction

function! s:parse_header(line)
  let matches = matchlist(a:line, '^@@ -\([[:digit:],]\+\)\? +\([[:digit:],]\+\)\? @@')
  if empty(matches)
    throw printf('git_diff: invalid format: %s', string(a:line))
  endif
  let [deletion, addition] = map(matches[1 : 2], 's:fix(eval("[" . v:val . "]"))')
  let tag = len(deletion) == 1 ? 'a' : len(addition) == 1 ? 'b' : 'c'
  let del_postfix = deletion[1] != 1 ? printf(',%d', deletion[0] + deletion[1] - 1) : ''
  let add_postfix = addition[1] != 1 ? printf(',%d', addition[0] + addition[1] - 1) : ''
  return join([deletion[0], del_postfix, tag, addition[0], add_postfix], '')
endfunction

function! s:fix(tuple)
  return len(a:tuple) == 1 ? a:tuple + [1] : a:tuple
endfunction


" Interface {{{1

function! gitdiff#diffexpr() abort
  call s:diffexpr('myers')
endfunction

function! gitdiff#histogramdiffexpr() abort
  call s:diffexpr('histogram')
endfunction

function! gitdiff#patiencediffexpr() abort
  call s:diffexpr('patience')
endfunction


" Initialization {{{1



" 1}}}

