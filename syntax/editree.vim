if exists("b:current_syntax")
  finish
endif

syn match editreeId /^\/\d* / conceal

let b:current_syntax = "editree"
