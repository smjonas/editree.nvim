let s:ESCAPE_PATTERN = '^$~.*[]\'

syntax match FernLeaf   /^.*$/ transparent contains=FernLeafSymbol, EditreeId
" [^\/] is the leaf symbol / icon
syntax match FernLeafSymbol /\%([/]\d\+ \)\@<=\s*[^\/]\|\s*[^\/]/ contained nextgroup=FernLeafText

" Branch ends with \w/
syntax match FernBranch /^.*\w\/$/ transparent contains=FernBranchSymbol, EditreeId

" Branch symbol is the first non-whitespace character
syntax match FernBranchSymbol /. / contained nextgroup=FernBranchText

syntax match FernBranchText /\w+\/$/ contained nextgroup=FernBadgeSep

syntax match FernRoot   /\%1l.*/       transparent contains=FernRootSymbol
execute printf(
      \ 'syntax match FernRootSymbol /%s/ contained nextgroup=FernRootText',
      \ escape(g:fern#renderer#default#root_symbol, s:ESCAPE_PATTERN),
      \)
syntax match FernRootText   /.*\ze.*$/ contained nextgroup=FernBadgeSep

syntax match editreeId /^\/\d* / contained conceal

syntax match FernLeafText   /.*\ze.*$/ contained nextgroup=FernBadgeSep
syntax match FernBranchText /.*\ze.*$/ contained nextgroup=FernBadgeSep
syntax match FernBadgeSep   //         contained conceal nextgroup=FernBadge
syntax match FernBadge      /.*/         contained
