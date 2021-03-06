"=============================================================================
" FILE: exe.vim
" AUTHOR: Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 07 Jul 2010
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:command = {
      \ 'name' : 'exe',
      \ 'kind' : 'internal',
      \ 'description' : 'exe [{option}...] {command}',
      \}
function! s:command.execute(command, args, fd, other_info)"{{{
  let [l:args, l:options] = vimshell#parser#getopt(a:args, 
        \{ 'arg=' : ['--encoding']
        \})
  if !has_key(l:options, '--encoding')
    let l:options['--encoding'] = &termencoding
  endif

  " Encoding conversion.
  if l:options['--encoding'] != '' && l:options['--encoding'] != &encoding
    call map(l:args, 'iconv(v:val, &encoding, l:options["--encoding"])')
  endif
  
  " Execute command.
  if s:init_process(a:fd, l:args, l:options)
    return
  endif

  echo 'Running command.'
  call append(line('$'), '')

  " Move line.
  normal! j
  while b:interactive.process.is_valid
    call vimshell#interactive#execute_pipe_out()

    " Get input key.
    let l:char = getchar(0)
    if l:char != 0
      let l:char = nr2char(l:char)
      if l:char == "\<C-z>"
        call vimshell#error_line(a:fd, 'exe: Background executed.')

        " Background execution.
        call vimshell#commands#bg#init(l:args, a:fd, a:other_info, 'vimshell-bg', a:other_info.is_interactive)

        unlet b:interactive
      elseif l:char == "\<C-d>"
        " Interrupt.
        call vimshell#interactive#force_exit()
        call vimshell#error_line(a:fd, 'exe: Interrupted.')
        return
      endif
    endif
  endwhile

  redraw
  echo ''

  let b:vimshell.system_variables['status'] = b:interactive.status
endfunction"}}}

function! vimshell#commands#exe#define()
  return s:command
endfunction

function! s:init_process(fd, args, options)"{{{
  if exists('b:interactive') && b:interactive.process.is_valid
    " Delete zombee process.
    call vimshell#interactive#force_exit()
  endif
  
  let l:commands = []
  let l:command = {
        \ 'args' : a:args,
        \ 'fd' : {}
        \}
  call add(l:commands, l:command)

  " Set environment variables.
  let $TERMCAP = 'COLUMNS=' . winwidth(0)
  let $VIMSHELL = 1
  let $COLUMNS = winwidth(0)-5
  let $LINES = winheight(0)
  let $VIMSHELL_TERM = 'execute'

  let l:sub = vimproc#plineopen3(l:commands)

  " Set variables.
  let b:interactive = {
        \ 'process' : l:sub, 
        \ 'fd' : a:fd, 
        \ 'encoding' : a:options['--encoding'], 
        \ 'is_pty' : !vimshell#iswin(), 
        \ 'is_background': 0, 
        \ 'echoback_linenr' : -1,
        \ 'stdout_cache' : '',
        \ 'stderr_cache' : '',
        \}

  " Input from stdin.
  if b:interactive.fd.stdin != ''
    call b:interactive.process.stdin.write(vimshell#read(a:fd))
  endif
  call b:interactive.process.stdin.close()

  return
endfunction"}}}
