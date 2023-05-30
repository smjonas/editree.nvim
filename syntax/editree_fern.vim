let s:ESCAPE_PATTERN = '^$~.*[]\'

syntax match FernLeaf   /^.*$/ transparent contains=FernLeafSymbol, EditreeId
syntax match FernLeafSymbol /\%([/]\d\+ \)\@<=|  \||  / contained nextgroup=FernLeafText
execute printf(
      \ 'syntax match FernLeafSymbol /\%([/]\d\+ \)\@<=%s\|%s/ contained nextgroup=FernLeafText',
      \ escape(g:fern#renderer#default#leaf_symbol, s:ESCAPE_PATTERN),
      \ escape(g:fern#renderer#default#leaf_symbol, s:ESCAPE_PATTERN),
      \)

" Branch: ends with \w/ or contains |+ or |-
execute printf(
      \ 'syntax match FernBranch /^.*\w\/$\|^.*\(%s.*\|%s.*\)$/ transparent contains=FernBranchSymbol, EditreeId',
      \ escape(g:fern#renderer#default#collapsed_symbol, s:ESCAPE_PATTERN),
      \ escape(g:fern#renderer#default#expanded_symbol, s:ESCAPE_PATTERN),
      \)
execute printf(
      \ 'syntax match FernBranchSymbol /\%(%s\|%s\)/ contained nextgroup=FernBranchText',
      \ escape(g:fern#renderer#default#collapsed_symbol, s:ESCAPE_PATTERN),
      \ escape(g:fern#renderer#default#expanded_symbol, s:ESCAPE_PATTERN),
      \)
syntax match FernBranchText /\w+\/$/ contained nextgroup=FernBadgeSep

syntax match FernRoot   /\%1l.*/       transparent contains=FernRootSymbol
execute printf(
      \ 'syntax match FernRootSymbol /%s/ contained nextgroup=FernRootText',
      \ escape(g:fern#renderer#default#root_symbol, s:ESCAPE_PATTERN),
      \)
syntax match FernRootText   /.*\ze.*$/ contained nextgroup=FernBadgeSep

syntax match editreeId /^\/\d* / contained conceal

" Matches /123 (|) file.txt or (|) file.txt
" execute printf(
"       \ 'syntax match FernLeafSymbol /\%([/]\d\+\)\@<=%s\|%s/ contained nextgroup=FernLeafText',
"       \ escape(g:fern#renderer#default#leaf_symbol, s:ESCAPE_PATTERN),
"       \ escape(g:fern#renderer#default#leaf_symbol, s:ESCAPE_PATTERN),
"       \)
" execute printf(
"       \ 'syntax match FernLeaderSymbol /^\%%(%s\)*/ contained nextgroup=FernBranchSymbol,FernLeafSymbol',
"       \ escape(g:fern#renderer#default#leading, s:ESCAPE_PATTERN),
"       \)
syntax match FernLeafText   /.*\ze.*$/ contained nextgroup=FernBadgeSep
syntax match FernBranchText /.*\ze.*$/ contained nextgroup=FernBadgeSep
syntax match FernBadgeSep   //         contained conceal nextgroup=FernBadge
syntax match FernBadge      /.*/         contained

