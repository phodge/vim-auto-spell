" Automatically correct bad spelling as you type (works for misspellings for
" which the correct word is obvious)

" this only works with vim 7 or later
if version < 700
	finish
endif

" we don't need to do anything until the user starts editting - don't waste time
" if they're just looking at a file
augroup AutoSpell
autocmd!
autocmd FocusLost,CursorHold,CursorHoldI,InsertLeave * call AutoSpell#oninsert(0)
autocmd InsertEnter * call AutoSpell#oninsert(1)
augroup end


finish

" -- BUGS --
"	TODO: oops, saving a spell file wipes it out (because it calls the ScanFile
"	function ...

" -- FEQTURE REQUESTS --
" TODO: Set up autocommands so that abbreviations are cleared and reloaded any
" one of the files is changed inside the same session
" TODO: Set up the SpellCorrect command so that it ...
" 			- captures the word under the cursor
" 			- captures ALL misspelled words on the cursor line
" 			- opens ALL known spell files
" 			- appends the misspelled words to the first spell file found
" 				OR
" 			- puts the misspelled words into a separate buffer so they can be copy-pasted into the
" 				appropriate file
" 			- fixes up the original mistake when done (probably requires
" 			confirmation)
" TODO: provide syntax and ftplugin for the SpellFile.
" 			- include a really long tabstop
" 			- automatically replace the space before <i with a tab
" 			- automatically adjust the tabstop so that all words fit inside it
" TODO: allow the SpellFile to be automatically sorted on write
" 			- pipe through the unix sort command
"				- this is a setting inside the file
" TODO: allow SpellFile to contain filetype-specific abbreviations
" 		- apply abbreviations as buffer-local 
" 		- automatically reload buffer-local abbreviations in the appropriate
" 			buffers of that filetype
" TODO: allow SpellCorrect plugin to only apply to certain filetypes (as a global setting in vimrc)
" TODO: allow spelling words to be also applied to the command-line (:cabbrev) (on a per-word basis)
" TODO: allow a local SpellFile to undo an abbreviation made in the global spell file
" TODO: build script to generate a spell file from this wikipedia page:
"				http://en.wikipedia.org/wiki/Wikipedia:Lists_of_common_misspellings/For_machines
"	TODO: benchmark the SpellCorrect plugin and make sure it does not increase the startup
"				time too much (as in under 2ms increase is a should be a good target!)
"	TODO: Potential Optimization Techniques:
"				- compile each spellfile into pure vimscript so that it doesn't need to be parsed
"					- use md5(data) as the file name to ensure always up-to-date
"					- break compiled scripts into smaller chunks (200 lines of vimscript)?
"				- read spell files in multiple passes (e.g., with 5 spell files you need to enter
"					insert mode 5 times)
"				- read each spell file only a few lines at a time
"					NOTE: I don't really like this idea because it penalizes short editting sessions.
