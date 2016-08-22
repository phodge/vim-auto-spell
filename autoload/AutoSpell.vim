function! AutoSpell#oninsert(stoponappend) " {{{
	let l:pos = getpos('.')[2]
	let l:max = strlen(getline('.'))
	if (l:pos > l:max) && a:stoponappend
		return
	endif

	tab split

	" look for our spelling files!
	for l:file in split(globpath(&runtimepath, 'AutoSpell/*.spell'))
		" scan each file
		call <SID>ScanFile(l:file, 0)
	endfor

	tabclose

  " blast away the spelling files
	autocmd! AutoSpell
endfunction " }}}

if ! exists('s:files')
	let s:files = {}
endif

let s:upto = {}

function! <SID>ScanFile(file, restart) " {{{
	" NOTE: there are some options which can cause the screen to jump around a
	" bit, we turn them off here
	let l:old_scrolloff = &l:scrolloff
	let l:old_sidescrolloff = &l:sidescrolloff
	setglobal scrolloff=0
	setglobal sidescrolloff=0

	" we need to split to that file ... we do it vertically because it has a
	" better chance of there being room
	vsplit
	execute 'view' a:file

	" set hide mode to 'wipe' so that the file is wiped out when we're done ...
	setlocal bufhidden=wipe

	" we need to set up autocommands to reload the spelling list every time we
	" edit one of our spelling files
	augroup AutoSpell
	execute printf("autocmd! BufWritePost %s call <SID>ScanFile('%s', 1)", a:file, a:file)
	augroup end

	" does this file appear in the edit list?
	let l:allowEdit = 1

	" are we restarting the file (or is it not started yet?)
"	if empty(get(s:upto, a:file)) || a:restart
"		" start from the beginning
"		let l:i = 0
"		let s:upto[a:file] = 0
"
"		" we'll be scanning how many lines?
"		let l:stop = exists('g:AutoSpellAmount') ? g:AutoSpellAmount : 200
"	else
"		" start from wherever we are up to in the file ...
"		let l:i = s:upto[a:file]
"
"		" we'll stop after how many lines?
"		let l:stop = l:i + (exists('g:AutoSpellAmount') ? g:AutoSpellAmount : 200)
"	endif

	" we stop at the end if it's earlier ...
"	if line('$') <= l:stop
"		let l:stop = line('$')
"		unlet s:upto[a:file]
"	else
"		let s:upto[a:file] = l:stop
"	endif
	let l:stop = line('$')

	" now we go through each line and find the autocommands ...
	let l:i = 0
	while l:i < l:stop
		let l:i += 1

		let l:line = getline(l:i)

		if l:line =~ '^\s*$'
			continue
		endif

		" is it a command (e.g., 'noedit')
		if l:line =~ '^\s*noedit\s*\%(#.*\)\=$'
			let l:allowEdit = 0
		endif

		" if the line says 'stophere', we can't scan any further
		if l:line =~ '^\s*stophere\s*\%(#.*\)\=$'
			break
		endif

		" is it a comment?
		if l:line =~ '^\s*#'
			continue
		endif

		" is it a list of words?
		if l:line !~ '^\s*\w\+\s\+<'
			continue
		endif

		let l:parts = split(l:line)

		" we get the word first ...
		let l:correct = l:parts[0]

		" should be followed by '<'
		if l:parts[1] != '<'
			echoerr printf("line %s in %s does not have '<' in \$1?", l:i, a:file)
			break
		endif

		" followed by badly spelled words
		let l:badWords = []
		let l:suffixes = []
		for l:trailing in l:parts[2:]
			if l:trailing == '+'
				call insert(l:suffixes, '')
			elseif l:trailing =~ '^+\w\+$'
				call add(l:suffixes, strpart(l:trailing, 1))
			else
				call add(l:badWords, l:trailing)
			endif
		endfor

		if empty(l:suffixes)
			let l:suffixes = [ '' ]
		endif

		" now we have a bunch of words and suffixes ...
		for l:suffix in l:suffixes
			for l:badWord in l:badWords
				" first the lowercase version
				let l:bad = tolower(l:badWord . l:suffix)
				let l:good = tolower(l:correct . l:suffix)
				execute printf('iabbrev %s %s', l:bad, l:good)

				" next the uppercase version
				execute printf('iabbrev %s %s', toupper(l:bad), toupper(l:good))

				" now the tricky one, the mixed-case version
				let l:bad1 = toupper(strpart(l:bad, 0, 1))
				let l:bad2 = strpart(l:bad, 1)
				let l:good1 = toupper(strpart(l:good, 0, 1))
				let l:good2 = strpart(l:good, 1)
				execute printf('iabbrev %s%s %s%s', l:bad1, l:bad2, l:good1, l:good2)
			endfor
		endfor
	endwhile

	" remember the name of the file ...
	let s:files[a:file] = l:allowEdit

	" we want to close the buffer now we're done reading it
	quit

	" we need to restore the values for scrolloff and friends ...
	let &g:scrolloff = l:old_scrolloff
	let &g:sidescrolloff = l:old_sidescrolloff
endfunction " }}}

command! -nargs=0 SpellCorrect call <SID>SpellCorrect()
function! <SID>SpellCorrect() " {{{
	if empty(s:files)
		echoerr 'No spell files loaded ...'
		return
	endif

	let l:files = []
	for l:file in keys(s:files)
		" are we allowed to edit it?
		if s:files[l:file]
			call add(l:files, l:file)
		endif
	endfor

	" if there is no file to edit, show a message
	if empty(l:files)
		echoerr "All spell files have 'noedit' flag!"
		return
	endif

	" if there is only one spell file, we choose it!
	if len(l:files) == 1
		let l:choice = 0
	else
		let l:choice = inputlist(l:files)
	endif

	if l:choice < 0
		return
	endif

	" is there a misspelled word under the cursor?
	let l:word = expand('<cword>')
	if l:word =~# '^[A-Z]\+$'
		let l:case = 'upper'
	elseif l:word =~# '^[a-z]\+$'
		let l:case = 'lower'
	elseif l:word =~# '[A-Z][a-z]\+'
		let l:case = 'first'
	else
		let l:case = ''
	endif

	if strlen(l:case)
		" get a spelling suggestion for the word ...
		let l:lower = (l:case == 'lower') ? l:word : tolower(l:word)
		let l:suggest = []
		let l:i = 1
		let g:lower = l:lower
		let l:old_spell = &l:spell
		setlocal spell
		for l:suggestion in spellsuggest(l:lower)
			call add(l:suggest, l:i . ' ' . l:suggestion)
			let l:i += 1
		endfor
		let &l:spell = l:old_spell
		unlet! l:suggestion l:i
		if len(l:suggest)
			call insert(l:suggest, 'Choose the correct spelling for ' . l:lower . ':')
			let l:select = inputlist(l:suggest)
			if l:select > 0
				let l:goodword = get(l:suggest, l:select, '')
				if strlen(l:goodword)
					let l:goodword = substitute(l:goodword, '^\d\+\s\+', '', '')
				endif
				if ! strlen(l:goodword)
					unlet l:goodword
				endif
			endif
			unlet l:select
		endif
	endif

	if exists('l:goodword')
		" do we fix the word in our current line?
		if l:case == 'lower'
			let l:replace = l:goodword
		elseif l:case == 'upper'
			let l:replace = toupper(l:goodword)
		else
			let l:replace = toupper(strpart(l:goodword, 0, 1)) . strpart(l:goodword, 1)
		endif

		" where are we at?
		let l:pos = getpos('.')
		execute printf('s,\V\<%s\>,%s,gc', l:word, l:replace)
		" move the cursor back to that col
		call setpos('.', l:pos)
	endif

	" split to that file, jump to end of file ...
	execute 'tab split' l:files[l:choice]

	" make it so the buffer is wiped out ...
	setlocal bufhidden=wipe

	" of course, we don't want any spell checking in this file!
	setlocal nospell

	" append the good spelling to the file?
	normal! G
	if exists('l:goodword')
		call append(line('$'), l:goodword . "\t< " . l:lower)
		normal! GV
	endif
endfunction " }}}
